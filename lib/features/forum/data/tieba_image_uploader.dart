import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/account_model.dart';
import '../../../core/constants/tieba_constants.dart';

const _chunkSize = 512000;
const _maxImageSize = 5 * 1024 * 1024;
const _maxImageEdge = 1080;
const _cuid = 'baidutiebaapp4134907038753229';

class UploadedThreadImage {
  final String picId;
  final int width;
  final int height;

  const UploadedThreadImage({
    required this.picId,
    required this.width,
    required this.height,
  });

  String get contentTag => '#(pic,$picId,$width,$height)';
}

class TiebaImageUploadException implements Exception {
  final String message;

  const TiebaImageUploadException(this.message);

  @override
  String toString() => message;
}

/// Uploads images through Tieba's multipart endpoint before a thread is sent.
/// Each image is resized/compressed and then uploaded serially in 512000-byte
/// chunks, matching the current Tieba client upload flow.
class TiebaImageUploader {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<UploadedThreadImage> upload({
    required XFile file,
    required String forumName,
    required AccountModel account,
  }) async {
    final cleanForumName = forumName.replaceFirst(RegExp(r'吧$'), '').trim();
    try {
      final compressed = await _compress(file);
      final digest = md5.convert(compressed.bytes).toString();
      final resourceId = '$digest$_chunkSize';
      final chunkCount = (compressed.bytes.length / _chunkSize).ceil();
      Map<String, dynamic>? lastResponse;

      for (var chunkIndex = 0; chunkIndex < chunkCount; chunkIndex++) {
        final start = chunkIndex * _chunkSize;
        final end = (start + _chunkSize)
            .clamp(0, compressed.bytes.length)
            .toInt();
        final chunk = Uint8List.sublistView(compressed.bytes, start, end);
        final isLastChunk = chunkIndex == chunkCount - 1;
        lastResponse = await _uploadChunk(
          chunk: chunk,
          chunkNo: chunkIndex + 1,
          isLastChunk: isLastChunk,
          resourceId: resourceId,
          forumName: cleanForumName,
          width: compressed.width,
          height: compressed.height,
          totalSize: compressed.bytes.length,
          account: account,
        );
      }

      final picId = lastResponse?['picId']?.toString() ?? '';
      final picInfo = lastResponse?['picInfo'];
      final originPic = picInfo is Map ? picInfo['originPic'] : null;
      if (picId.isEmpty || originPic is! Map) {
        throw const TiebaImageUploadException('贴吧图片上传结果缺少图片信息');
      }

      final width = _positiveInt(originPic['width']) ?? compressed.width;
      final height = _positiveInt(originPic['height']) ?? compressed.height;
      return UploadedThreadImage(picId: picId, width: width, height: height);
    } on TiebaImageUploadException {
      rethrow;
    } on DioException {
      throw const TiebaImageUploadException('网络异常，贴吧图片上传失败');
    } catch (_) {
      throw const TiebaImageUploadException('图片处理失败，请重新选择图片');
    }
  }

  Future<Map<String, dynamic>> _uploadChunk({
    required Uint8List chunk,
    required int chunkNo,
    required bool isLastChunk,
    required String resourceId,
    required String forumName,
    required int width,
    required int height,
    required int totalSize,
    required AccountModel account,
  }) async {
    final form = FormData();
    final fields = <String, String>{
      'alt': 'json',
      'chunkNo': '$chunkNo',
      if (forumName.isNotEmpty) 'forum_name': forumName,
      'groupId': '1',
      'height': '$height',
      'isFinish': isLastChunk ? '1' : '0',
      'is_bjh': '0',
      'pic_water_type': '2',
      'resourceId': resourceId,
      'saveOrigin': '0',
      'size': '$totalSize',
      if (forumName.isNotEmpty) 'small_flow_fname': forumName,
      'width': '$width',
      'BDUSS': account.bduss,
      'stoken': account.stoken,
      'cuid': _cuid,
      'cuid_galaxy2': _cuid,
    };
    for (final entry in fields.entries) {
      form.fields.add(MapEntry(entry.key, entry.value));
    }
    form.files.add(
      MapEntry(
        'chunk',
        MultipartFile.fromBytes(
          chunk,
          filename: 'file',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      ),
    );

    final response = await _dio.post<dynamic>(
      '${TiebaConstants.baseNativeUrl}${TiebaConstants.pathUploadPicture}',
      data: form,
      options: Options(
        headers: {
          'User-Agent': TiebaConstants.defaultUserAgent,
          'Accept': 'application/json',
          'Cookie': [
            'ka=open',
            'CUID=$_cuid',
            'BDUSS=${account.bduss}',
            if (account.stoken.isNotEmpty) 'STOKEN=${account.stoken}',
          ].join('; '),
        },
      ),
    );

    final dynamic raw = response.data;
    final Map<String, dynamic>? data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : null;
    if (data == null) {
      throw const TiebaImageUploadException('贴吧返回了无法识别的图片上传结果');
    }

    final code = data['error_code'];
    if (code != null && code != 0 && code != '0') {
      final message = data['error_msg']?.toString().trim();
      throw TiebaImageUploadException(
        message == null || message.isEmpty ? '贴吧拒绝了图片上传' : message,
      );
    }
    return data;
  }

  Future<_CompressedImage> _compress(XFile file) async {
    final sourceBytes = await file.readAsBytes();
    if (sourceBytes.isEmpty) {
      throw const TiebaImageUploadException('所选图片为空');
    }
    if (sourceBytes.length > _maxImageSize) {
      throw const TiebaImageUploadException('图片仍超过贴吧 5 MB 限制，请重新选择或裁剪图片');
    }

    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        sourceBytes,
        targetWidth: _maxImageEdge,
        targetHeight: _maxImageEdge,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      return _CompressedImage(
        bytes: sourceBytes,
        width: image.width,
        height: image.height,
      );
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  int? _positiveInt(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

class _CompressedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const _CompressedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

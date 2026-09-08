import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../constants/tieba_constants.dart";
import "../storage/storage_service.dart";
import "../utils/app_toast.dart";
import "../utils/haptic_feedback_util.dart";

class MediaSaveService {
  MediaSaveService._();

  static const _channel = MethodChannel("com.lurk/app");

  static String _safeFolderName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_');
    if (cleaned.isEmpty) return '未命名用户';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  static Future<String> _relativePath({
    required bool isVideo,
    String? folderName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final type =
        prefs.getInt(
          isVideo
              ? StorageService.keyVideoSavePathType
              : StorageService.keyImageSavePathType,
        ) ??
        0;
    final root = isVideo ? 'Movies/Lurk' : 'Pictures/Lurk';
    if (type == 0) {
      return root;
    }
    var targetFolder = folderName;
    if (type == 1) {
      targetFolder =
          prefs.getString(StorageService.keyActiveAccountName) ?? 'MyProfile';
    }
    if (targetFolder == null || targetFolder.trim().isEmpty) return root;
    return '$root/${_safeFolderName(targetFolder)}';
  }

  static Future<void> saveImage(
    BuildContext context,
    String imageUrl, {
    String? folderName,
  }) async {
    if (imageUrl.isEmpty) {
      AppToast.show(context, "图片链接为空，无法保存");
      return;
    }

    HapticFeedbackUtil.light();
    AppToast.show(context, "正在保存图片...");

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {"User-Agent": TiebaConstants.defaultUserAgent},
        ),
      );

      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.isEmpty) {
        if (context.mounted) AppToast.show(context, "图片下载失败");
        return;
      }

      final fileName = "lurk_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final relativePath = await _relativePath(
        isVideo: false,
        folderName: folderName,
      );
      final success = await _channel.invokeMethod<bool>("saveImageToGallery", {
        "bytes": bytes,
        "fileName": fileName,
        "relativePath": relativePath,
      });

      if (context.mounted) {
        if (success == true) {
          HapticFeedbackUtil.medium();
          AppToast.show(context, "图片已保存至系统相册");
        } else {
          AppToast.show(context, "保存失败，请检查存储权限");
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, "保存失败: $e");
      }
    }
  }

  static Future<void> saveVideo(
    BuildContext context,
    String videoUrl, {
    String? folderName,
  }) async {
    if (videoUrl.isEmpty) {
      AppToast.show(context, "视频链接为空，无法保存");
      return;
    }

    HapticFeedbackUtil.light();
    AppToast.show(context, "正在下载并保存视频，请稍候...");

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        videoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {"User-Agent": TiebaConstants.defaultUserAgent},
        ),
      );

      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.isEmpty) {
        if (context.mounted) AppToast.show(context, "视频下载失败");
        return;
      }

      final fileName =
          "lurk_video_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final relativePath = await _relativePath(
        isVideo: true,
        folderName: folderName,
      );
      final success = await _channel.invokeMethod<bool>("saveVideoToGallery", {
        "bytes": bytes,
        "fileName": fileName,
        "relativePath": relativePath,
      });

      if (context.mounted) {
        if (success == true) {
          HapticFeedbackUtil.medium();
          AppToast.show(context, "视频已保存至系统相册");
        } else {
          AppToast.show(context, "保存失败，请检查存储权限");
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, "保存失败: $e");
      }
    }
  }
}

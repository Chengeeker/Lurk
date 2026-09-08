import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import 'models/tieba_post_model.dart';
import 'protobuf/add_post_protobuf.dart';

class DetailRepository {
  final TiebaDioClient _client;
  final Ref? _ref;

  DetailRepository(this._client, [this._ref]);

  Future<Map<String, dynamic>> getThreadDetail({
    required String threadId,
    required int page,
    bool seeLzOnly = false,
    bool reverse = false,
  }) async {
    final res = await _client.post(
      TiebaConstants.pathThreadDetail,
      data: {
        'kz': threadId,
        'pn': page.toString(),
        'rn': '20',
        'with_floor': '1',
        'floor_rn': '3',
        'lz': seeLzOnly ? '1' : '0',
        'r': reverse ? '1' : '0',
        '_client_type': '2',
        '_client_version': '12.65.1.0',
        'from': 'baidu_appstore',
      },
    );

    final data = res.data;
    if (data is Map) {
      final Map<String, Map<String, dynamic>> userMap = {};
      final userListRaw = data['user_list'] as List? ?? [];
      for (var u in userListRaw) {
        if (u is Map<String, dynamic> && u['id'] != null) {
          userMap[u['id'].toString()] = u;
        }
      }

      final postListRaw = data['post_list'] as List? ?? [];
      final floors = postListRaw
          .map((e) => TiebaFloorModel.fromJson(e as Map<String, dynamic>, userMap: userMap))
          .toList();

      final threadMap = data['thread'] as Map<String, dynamic>? ?? {};
      final forumMap = data['forum'] as Map<String, dynamic>? ?? {};
      final antiMap = data['anti'] as Map<String, dynamic>? ?? {};
      return {
        'floors': floors,
        'thread': threadMap,
        'forum': forumMap,
        'anti': antiMap,
        'has_more': data['page']?['has_more'] == 1 || data['page']?['has_more'] == '1',
      };
    }
    return {'floors': <TiebaFloorModel>[], 'has_more': false};
  }

  Future<List<TiebaSubPostModel>> getFloorReplies({
    required String threadId,
    required String postId,
    required int page,
  }) async {
    final res = await _client.post(
      TiebaConstants.pathFloor,
      data: {
        'kz': threadId,
        'pid': postId,
        'pn': page.toString(),
      },
    );

    final data = res.data;
    if (data is Map && data['subpost_list'] is List) {
      final Map<String, Map<String, dynamic>> userMap = {};
      final userListRaw = data['user_list'] as List? ?? [];
      for (var u in userListRaw) {
        if (u is Map<String, dynamic> && u['id'] != null) {
          userMap[u['id'].toString()] = u;
        }
      }

      final list = data['subpost_list'] as List;
      return list.map((e) => TiebaSubPostModel.fromJson(e as Map<String, dynamic>, userMap: userMap)).toList();
    }
    return [];
  }

  Future<({bool success, String errorMsg, String? pid})> addReply({
    required String threadId,
    required String forumId,
    required String forumName,
    required String content,
    required String tbs,
    String? postId,
    String? subPostId,
    String? replyUserId,
    String? replyUserName,
    String? replyUserPortrait,
    String? nameShow,
  }) async {
    try {
      final isReplyFloor = postId != null && postId.isNotEmpty && postId != '0';
      final isReplySubPost = subPostId != null && subPostId.isNotEmpty && subPostId != '0';
      final cleanFname = forumName.replaceAll(RegExp(r'吧$'), '').trim();

      final account = _ref?.read(authStateProvider).activeAccount;
      final bduss = account?.bduss ?? '';
      final stoken = account?.stoken ?? '';
      final uid = account?.uid ?? '';
      const cuid = 'baidutiebaapp4134907038753229';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final common = CommonRequest()
        ..clientType = 2
        ..clientVersion = '12.35.1.0'
        ..clientId = 'wappc_${nowMs}_${DateTime.now().microsecond % 1000}'
        ..cuid = cuid
        ..cuidGalaxy2 = cuid
        ..timestamp = Int64(nowMs)
        ..model = 'Pixel 7'
        ..bduss = bduss
        ..tbs = tbs
        ..netType = 1
        ..from = '1020031h'
        ..pversion = '1.0.3'
        ..sdkVer = '2.34.0'
        ..frameworkVer = '3340042'
        ..legoLibVersion = '3.0.0'
        ..brand = 'Google'
        ..stoken = stoken
        ..cmode = 1
        ..startType = 1
        ..personalizedRecSwitch = 1;

      // 楼中楼回复时，前缀使用贴吧原生格式: 回复 #(reply, portrait, name) :
      final finalContent = (isReplySubPost &&
              replyUserPortrait != null &&
              replyUserPortrait.isNotEmpty &&
              replyUserName != null &&
              replyUserName.isNotEmpty)
          ? '回复 #(reply, $replyUserPortrait, $replyUserName) :$content'
          : content;

      final postData = AddPostRequestData()
        ..common = common
        ..anonymous = '1'
        ..canNoForum = '0'
        ..isFeedback = '0'
        ..takephotoNum = '0'
        ..entranceType = '0'
        ..newVcode = '1'
        ..vcodeTag = '12'
        ..content = finalContent
        ..fid = forumId
        ..kw = cleanFname
        ..tid = threadId
        ..isAd = '0'
        ..isAddition = '0'
        ..isBarrage = '0'
        ..isGiftpost = '0'
        ..isPictxt = '0'
        ..isTwzhiboThread = '0'
        ..nameShow = nameShow ?? (account != null && account.nameShow.isNotEmpty ? account.nameShow : (account?.name ?? ''))
        ..showCustomFigure = 0
        ..isShowBless = 0
        ..floorNum = '0'
        ..tbs = tbs;

      if (!isReplyFloor && !isReplySubPost) {
        postData.postFrom = '13';
        postData.barrageTime = '0';
        postData.vFid = '';
        postData.vFname = '';
      } else {
        if (!isReplySubPost) {
          postData.postFrom = '0';
        }
        if (postId != null && postId.isNotEmpty && postId != '0') {
          postData.quoteId = postId;
          postData.repostid = postId;
        }
        if (subPostId != null && subPostId.isNotEmpty && subPostId != '0') {
          postData.subPostId = subPostId;
        }
        if (replyUserId != null && replyUserId.isNotEmpty && replyUserId != '0') {
          postData.replyUid = replyUserId;
        }
      }

      final addPostReq = AddPostRequest()..data = postData;
      final pbBytes = addPostReq.writeToBuffer();

      final now = DateTime.now();
      final eventDay = '${now.year}${now.month}${now.day}';

      final fields = <String, String>{
        'BDUSS': bduss,
        '_client_id': common.clientId,
        '_client_type': '2',
        '_client_version': '12.35.1.0',
        '_timestamp': nowMs.toString(),
        'active_timestamp': '0',
        'android_id': '000',
        'brand': 'Google',
        'cmode': '1',
        'cuid': cuid,
        'cuid_galaxy2': cuid,
        'cuid_gid': '',
        'device_score': '0',
        'event_day': eventDay,
        'extra': '',
        'first_install_time': '0',
        'framework_ver': '3340042',
        'from': 'tieba',
        'is_teenager': '0',
        'last_update_time': '0',
        'model': 'Pixel 7',
        'net_type': '1',
        'oaid': '{}',
        'personalized_rec_switch': '1',
        'sample_id': '',
        'sdk_ver': '2.34.0',
        'start_scheme': '',
        'start_type': '1',
        'stoken': stoken,
        'tbs': tbs,
        'z_id': '',
      };
      fields['sign'] = calculateTiebaSign(fields);

      final formData = FormData();
      for (var entry in fields.entries) {
        formData.fields.add(MapEntry(entry.key, entry.value));
      }
      formData.files.add(MapEntry(
        'data',
        MultipartFile.fromBytes(pbBytes, filename: 'file'),
      ));

      final cookieParts = ['ka=open', 'CUID=$cuid'];
      if (bduss.isNotEmpty) cookieParts.add('BDUSS=$bduss');
      if (stoken.isNotEmpty) cookieParts.add('STOKEN=$stoken');

      final protoDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final res = await protoDio.post(
        'https://tiebac.baidu.com/c/c/post/add?cmd=309731&format=protobuf',
        data: formData,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': 'bdtb for Android 12.35.1.0',
            'x_bd_data_type': 'protobuf',
            if (uid.isNotEmpty) 'client_user_token': uid,
            'Cookie': cookieParts.join('; '),
          },
        ),
      );

      if (res.data is List<int>) {
        final bytes = res.data as List<int>;
        // 百度服务端在某些拦截场景下返回 UTF-8 编码的 JSON 报错 (以 '{' 0x7B 开头)
        if (bytes.isNotEmpty && bytes.first == 0x7B) {
          try {
            final jsonStr = utf8.decode(bytes);
            final map = jsonDecode(jsonStr);
            if (map is Map) {
              final code = map['error_code'];
              final msg = map['error_msg']?.toString() ?? map['msg']?.toString() ?? '发表失败，请重试';
              if (code == 0 || code == '0') {
                final pid = map['pid']?.toString() ?? map['data']?['pid']?.toString();
                return (success: true, errorMsg: '', pid: pid);
              }
              return (success: false, errorMsg: msg, pid: null);
            }
          } catch (_) {}
        }

        try {
          final resp = AddPostResponse.create()..mergeFromBuffer(bytes);
          final errCode = resp.error.errorCode;
          final errMsg = resp.error.userMsg.isNotEmpty
              ? resp.error.userMsg
              : (resp.error.errorMsg.isNotEmpty ? resp.error.errorMsg : '');
          final pid = resp.data.pid;

          if (errCode == 0) {
            return (success: true, errorMsg: '', pid: pid.isNotEmpty ? pid : null);
          } else {
            return (
              success: false,
              errorMsg: errMsg.isNotEmpty ? errMsg : '发表失败 (代码: $errCode)',
              pid: null,
            );
          }
        } catch (pbErr) {
          try {
            final str = utf8.decode(bytes);
            return (success: false, errorMsg: '发表异常: $str', pid: null);
          } catch (_) {
            return (success: false, errorMsg: '发表异常: 数据解析失败', pid: null);
          }
        }
      }

      if (res.data is Map || res.data is String) {
        final data = res.data is String ? jsonDecode(res.data as String) : res.data;
        if (data is Map) {
          final code = data['error_code'];
          final pid = data['pid']?.toString() ?? data['data']?['pid']?.toString() ?? '';
          if (code == 0 || code == '0') {
            return (success: true, errorMsg: '', pid: pid.isNotEmpty ? pid : null);
          }
          final msg = data['error_msg']?.toString() ?? data['msg']?.toString() ?? '发表失败，请重试';
          return (success: false, errorMsg: msg, pid: null);
        }
      }

      return (success: false, errorMsg: '发表失败，请重试', pid: null);
    } catch (e) {
      if (e is DioException) {
        if (e.response?.data is List<int>) {
          try {
            final text = utf8.decode(e.response!.data as List<int>);
            final map = jsonDecode(text);
            if (map is Map && map['error_msg'] != null) {
              return (success: false, errorMsg: map['error_msg'].toString(), pid: null);
            }
          } catch (_) {}
        }
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return (success: false, errorMsg: '网络连接超时，请重试', pid: null);
        }
        if (e.response?.statusCode != null) {
          return (success: false, errorMsg: '服务器响应异常 (${e.response?.statusCode})', pid: null);
        }
      }
      return (success: false, errorMsg: '发送失败: $e', pid: null);
    }
  }

  Future<({bool success, String errorMsg})> deletePost({
    required String forumId,
    required String forumName,
    required String threadId,
    required String postId,
    required String tbs,
    bool isFloor = false,
  }) async {
    try {
      final cleanFname = forumName.replaceAll(RegExp(r'吧$'), '').trim();
      if (forumId.isEmpty || cleanFname.isEmpty) {
        return (success: false, errorMsg: '缺少吧信息，无法删除');
      }

      final res = await _client.post(
        TiebaConstants.pathDelPost,
        data: {
          'fid': forumId,
          'word': cleanFname,
          'z': threadId,
          'pid': postId,
          'tbs': tbs,
          'isfloor': '0',
          'src': '1',
          'is_vipdel': '0',
          'delete_my_post': '1',
        },
      );
      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        if (code == 0 || code == '0') {
          return (success: true, errorMsg: '');
        }
        final msg = data['error_msg']?.toString() ??
            data['msg']?.toString() ??
            '删除失败，请重试';
        return (success: false, errorMsg: msg);
      }
      return (success: false, errorMsg: '删除失败，请重试');
    } catch (e) {
      return (success: false, errorMsg: '删除失败，请检查网络后重试');
    }
  }

  Future<({bool success, String errorMsg})> deleteThread({
    required String forumId,
    required String forumName,
    required String threadId,
    required String tbs,
  }) async {
    try {
      final cleanFname = forumName.replaceAll(RegExp(r'吧$'), '').trim();
      if (forumId.isEmpty || cleanFname.isEmpty) {
        return (success: false, errorMsg: '缺少吧信息，无法删除');
      }

      final res = await _client.post(
        TiebaConstants.pathDelThread,
        data: {
          'fid': forumId,
          'word': cleanFname,
          'z': threadId,
          'tbs': tbs,
          'src': '1',
          'is_vipdel': '0',
          'delete_my_thread': '1',
          'is_frs_mask': '0',
        },
      );
      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        if (code == 0 || code == '0') {
          return (success: true, errorMsg: '');
        }
        final msg = data['error_msg']?.toString() ??
            data['msg']?.toString() ??
            '删除失败，请重试';
        return (success: false, errorMsg: msg);
      }
      return (success: false, errorMsg: '删除失败，请重试');
    } catch (e) {
      return (success: false, errorMsg: '删除失败，请检查网络后重试');
    }
  }

  Future<({bool success, String errorMsg})> opAgree({
    required String threadId,
    String? postId,
    String? objType,
    required bool isAgree,
    required String tbs,
  }) async {
    try {
      final bool isThread = objType == '3' || (postId == null || postId.isEmpty || postId == '0' || postId == threadId);
      final actualPostId = (postId != null && postId.isNotEmpty && postId != threadId) ? postId : '0';
      final res = await _client.post(
        TiebaConstants.pathAgree,
        data: {
          'thread_id': threadId,
          'post_id': actualPostId,
          'agree_type': '2',
          'obj_type': isThread ? '3' : '1',
          'op_type': isAgree ? '0' : '1',
          'tbs': tbs,
        },
      );
      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        if (code == 0 || code == '0') {
          return (success: true, errorMsg: '');
        }
        final msg = data['error_msg']?.toString() ?? '点赞失败，请重试';
        // 容错处理：若服务端提示“不能重复点赞”或“已点赞”，说明服务端已是已赞状态，视为成功
        if (isAgree && (msg.contains('重复') || msg.contains('已点赞') || msg.contains('已赞') || code == 340006 || code == '340006')) {
          return (success: true, errorMsg: '');
        }
        // 容错处理：若服务端提示“不能重复取消”或“未点赞”，说明服务端已是未赞状态，视为成功
        if (!isAgree && (msg.contains('重复') || msg.contains('未点赞') || msg.contains('未赞'))) {
          return (success: true, errorMsg: '');
        }
        return (success: false, errorMsg: msg);
      }
      return (success: false, errorMsg: '点赞失败，请重试');
    } catch (_) {
      return (success: false, errorMsg: '网络异常，点赞失败');
    }
  }
}

final detailRepositoryProvider = Provider<DetailRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return DetailRepository(client, ref);
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import 'models/hot_topic_model.dart';
import 'models/tieba_thread_model.dart';

class FeedRepository {
  final TiebaDioClient _client;

  FeedRepository(this._client);

  Future<List<TiebaThreadModel>> getPersonalizedFeed({
    required int page,
    required int loadType,
  }) async {
    final res = await _client.post(
      TiebaConstants.pathPersonalizedFeed,
      data: {
        'load_type': loadType.toString(),
        'pn': page.toString(),
        'page_thread_count': '15',
        'need_forumlist': '1',
      },
    );

    final data = res.data;
    if (data is Map && data['thread_list'] is List) {
      final Map<String, Map<String, dynamic>> userMap = {};
      final userListRaw = data['user_list'] as List? ?? [];
      for (var u in userListRaw) {
        if (u is Map && u['id'] != null) {
          userMap[u['id'].toString()] = Map<String, dynamic>.from(u);
        }
      }

      final list = data['thread_list'] as List;
      return list
          .whereType<Map>()
          .map((e) => TiebaThreadModel.fromJson(Map<String, dynamic>.from(e), userMap: userMap))
          .toList();
    }
    return [];
  }

  Future<List<TiebaHotTopicModel>> getHotTopicList() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': TiebaConstants.defaultUserAgent,
        },
      ));
      final res = await dio.get('https://tieba.baidu.com/hottopic/browse/topicList');
      final data = res.data;
      if (data is Map && data['data'] != null && data['data']['bang_topic'] != null) {
        final list = data['data']['bang_topic']['topic_list'] as List? ?? [];
        return list
            .whereType<Map>()
            .map((e) => TiebaHotTopicModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<TiebaThreadModel>> getFollowedUsersFeed({
    required String uid,
    required int page,
  }) async {
    if (uid.isEmpty) return [];
    try {
      final followRes = await _client.post(
        '/c/u/follow/page',
        data: {'uid': uid, 'pn': page.toString(), 'rn': '20'},
      );
      final followData = followRes.data;
      if (followData is! Map || followData['user_list'] is! List) return [];

      final userList = followData['user_list'] as List;
      final List<Map<String, dynamic>> users = userList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (users.isEmpty) return [];

      final threads = <TiebaThreadModel>[];
      final targetUsers = users.take(10).toList();

      final results = await Future.wait(
        targetUsers.map((u) async {
          final targetUid = u['id']?.toString() ?? u['user_id']?.toString() ?? '';
          if (targetUid.isEmpty) return <TiebaThreadModel>[];
          try {
            final res = await _client.post(
              TiebaConstants.pathUserPost,
              data: {
                'uid': targetUid,
                'pn': '1',
                'rn': '5',
                'is_thread': '1',
                'need_content': '1',
              },
            );
            final data = res.data;
            if (data is Map && data['post_list'] is List) {
              final posts = data['post_list'] as List;
              return posts
                  .whereType<Map>()
                  .map((e) => TiebaThreadModel.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
          } catch (_) {}
          return <TiebaThreadModel>[];
        }),
      );

      for (var r in results) {
        threads.addAll(r);
      }

      threads.sort((a, b) => b.createTime.compareTo(a.createTime));
      return threads;
    } catch (_) {
      return [];
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

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return FeedRepository(client);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import 'models/followed_forum_model.dart';

class MyForumsRepository {
  final TiebaDioClient _client;

  // The endpoint currently returns the complete list for most accounts, but
  // some responses are page-sized. Request a large page and keep a bounded
  // fallback loop so a newly followed forum is not hidden by a server-side
  // default page size.
  static const int _requestedPageSize = 200;
  static const int _fallbackPageSize = 50;
  static const int _maxPages = 20;

  MyForumsRepository(this._client);

  Future<List<FollowedForumModel>> getFollowedForums({
    required String uid,
  }) async {
    final result = <FollowedForumModel>[];
    final seen = <String>{};

    for (var page = 1; page <= _maxPages; page++) {
      final res = await _client.post(
        TiebaConstants.pathFollowedForums,
        data: {
          'uid': uid,
          'pn': page.toString(),
          'rn': _requestedPageSize.toString(),
        },
      );

      final root = _asMap(res.data);
      if (root == null) {
        if (page == 1) return [];
        break;
      }

      final payload = _findForumPayload(root);
      _throwIfRequestFailed(root, payload);

      final rawList = _extractForumList(payload);
      var addedCount = 0;
      for (final raw in rawList) {
        if (raw is! Map) continue;
        final forum = FollowedForumModel.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (forum.name.isEmpty && (forum.id.isEmpty || forum.id == '0')) {
          continue;
        }

        final key = forum.id.isNotEmpty && forum.id != '0'
            ? 'id:${forum.id}'
            : 'name:${forum.name}';
        if (seen.add(key)) {
          result.add(forum);
          addedCount++;
        }
      }

      final hasMore = _readHasMore(root, payload);
      final shouldLoadNext =
          hasMore == true ||
          (hasMore == null &&
              rawList.length >= _fallbackPageSize &&
              rawList.isNotEmpty);
      if (!shouldLoadNext || rawList.isEmpty || addedCount == 0) {
        break;
      }
    }

    return result;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic> _findForumPayload(Map<String, dynamic> root) {
    final nested = _asMap(root['data']);
    if (nested != null &&
        (nested['forum_info'] is List || nested['forum_list'] is List)) {
      return nested;
    }
    return root;
  }

  List<dynamic> _extractForumList(Map<String, dynamic> payload) {
    final list = payload['forum_info'] ?? payload['forum_list'];
    return list is List ? list : const [];
  }

  bool? _readHasMore(Map<String, dynamic> root, Map<String, dynamic> payload) {
    dynamic raw = payload['has_more'] ?? payload['hasMore'];
    final page = _asMap(payload['page']) ?? _asMap(root['page']);
    raw ??= page?['has_more'] ?? page?['hasMore'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      if (raw == '1' || raw.toLowerCase() == 'true') return true;
      if (raw == '0' || raw.toLowerCase() == 'false') return false;
    }
    return null;
  }

  void _throwIfRequestFailed(
    Map<String, dynamic> root,
    Map<String, dynamic> payload,
  ) {
    final rawCode = root['error_code'] ?? payload['error_code'];
    if (rawCode == null) return;
    final code = int.tryParse(rawCode.toString());
    if (code != null && code != 0) {
      final message =
          root['error_msg']?.toString() ??
          payload['error_msg']?.toString() ??
          root['msg']?.toString() ??
          '获取关注列表失败';
      throw StateError(message);
    }
  }

  Future<bool> batchSignIn({required String tbs}) async {
    final res = await _client.post(
      TiebaConstants.pathBatchSign,
      data: {'tbs': tbs},
    );
    final data = res.data;
    return data is Map &&
        (data['error_code'] == 0 || data['error_code'] == '0');
  }
}

final myForumsRepositoryProvider = Provider<MyForumsRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return MyForumsRepository(client);
});

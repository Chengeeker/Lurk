import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../feed/data/models/tieba_thread_model.dart';

class BookmarksRepository {
  final TiebaDioClient _client;
  final StorageService _storage;

  BookmarksRepository(this._client, this._storage);

  String _uid(String? userId) => userId?.trim() ?? '';

  String _bookmarkKey(String? userId) =>
      StorageService.bookmarksKeyForAccount(_uid(userId));

  String _pendingAddsKey(String userId) =>
      StorageService.bookmarkPendingAddsKeyForAccount(_uid(userId));

  String _pendingRemovesKey(String userId) =>
      StorageService.bookmarkPendingRemovesKeyForAccount(_uid(userId));

  String _threadIdFromRaw(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map) {
        return value['id']?.toString() ?? value['tid']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<void> _addPendingId(String key, String threadId) async {
    if (threadId.isEmpty) return;
    final ids = _storage.getStringList(key).toSet()..add(threadId);
    await _storage.setStringList(key, ids.toList());
  }

  Future<void> _removePendingId(String key, String threadId) async {
    if (threadId.isEmpty) return;
    final ids = _storage.getStringList(key)..remove(threadId);
    await _storage.setStringList(key, ids);
  }

  /// 将旧版本未按账号隔离的本地收藏迁移到当前账号，并标记为待上传。
  Future<void> migrateLegacyBookmarksToAccount(String userId) async {
    final uid = _uid(userId);
    if (uid.isEmpty) return;

    final legacy = _storage.getStringList(StorageService.keyBookmarks);
    if (legacy.isEmpty) return;

    final accountKey = _bookmarkKey(uid);
    final accountRaw = _storage.getStringList(accountKey);
    final merged = <String>[...accountRaw];
    final existingIds = accountRaw
        .map(_threadIdFromRaw)
        .where((id) => id.isNotEmpty)
        .toSet();
    final pending = _storage.getStringList(_pendingAddsKey(uid)).toSet();

    for (final raw in legacy) {
      final id = _threadIdFromRaw(raw);
      if (id.isEmpty || existingIds.contains(id)) continue;
      merged.add(raw);
      existingIds.add(id);
      pending.add(id);
    }

    await _storage.setStringList(accountKey, merged);
    await _storage.setStringList(_pendingAddsKey(uid), pending.toList());
    await _storage.setStringList(StorageService.keyBookmarks, const []);
  }

  /// 从百度贴吧官方获取云端收藏列表 (分页拉取)
  Future<List<TiebaThreadModel>> getOfficialBookmarks({
    required String userId,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final res = await _client.post(
        TiebaConstants.pathThreadStore,
        data: {
          'rn': pageSize.toString(),
          'offset': (page * pageSize).toString(),
          'user_id': userId,
        },
      );

      final data = res.data;
      if (data is Map && data['store_thread'] is List) {
        final list = (data['store_thread'] as List)
            .map(
              (e) => TiebaThreadModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        return list;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// 添加到官方收藏
  Future<bool> addOfficialBookmark({
    required String threadId,
    String postId = '0',
    required String tbs,
  }) async {
    try {
      final payload = jsonEncode([
        {
          'pid': postId.isEmpty ? '0' : postId,
          'tid': threadId,
          'status': '0',
          'type': '0',
        },
      ]);

      final res = await _client.post(
        TiebaConstants.pathAddStore,
        data: {'data': payload, 'tbs': tbs},
      );

      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        return code == 0 || code == '0';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 从官方收藏移除
  Future<bool> removeOfficialBookmark({
    required String threadId,
    required String tbs,
  }) async {
    try {
      final res = await _client.post(
        TiebaConstants.pathRemoveStore,
        data: {'tid': threadId, 'tbs': tbs},
      );

      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        return code == 0 || code == '0';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 本地收藏缓存读写辅助方法
  List<TiebaThreadModel> getLocalBookmarks({
    String userId = '',
    bool isAscending = false,
  }) {
    final rawList = _storage.getStringList(_bookmarkKey(userId));
    final list = <TiebaThreadModel>[];
    for (var item in rawList) {
      try {
        list.add(TiebaThreadModel.fromJson(jsonDecode(item)));
      } catch (_) {}
    }
    return isAscending ? list : list.reversed.toList();
  }

  Future<void> saveLocalBookmark(
    TiebaThreadModel thread, {
    String userId = '',
  }) async {
    final uid = _uid(userId);
    final key = _bookmarkKey(uid);
    final rawList = _storage.getStringList(key);
    final exists = rawList.any((e) {
      try {
        final m = jsonDecode(e);
        return m['id']?.toString() == thread.id ||
            m['tid']?.toString() == thread.id;
      } catch (_) {
        return false;
      }
    });
    if (!exists) {
      final updated = List<String>.from(rawList)
        ..add(jsonEncode(thread.toJson()));
      await _storage.setStringList(key, updated);
      if (uid.isNotEmpty) {
        await _addPendingId(_pendingAddsKey(uid), thread.id);
        await _removePendingId(_pendingRemovesKey(uid), thread.id);
      }
    }
  }

  Future<void> removeLocalBookmark(
    String threadId, {
    String userId = '',
  }) async {
    final rawList = _storage.getStringList(_bookmarkKey(userId));
    final updated = rawList.where((e) {
      try {
        final m = jsonDecode(e);
        return m['id']?.toString() != threadId &&
            m['tid']?.toString() != threadId;
      } catch (_) {
        return true;
      }
    }).toList();
    await _storage.setStringList(_bookmarkKey(userId), updated);
  }

  bool isLocallyBookmarked(String threadId, {String userId = ''}) {
    final rawList = _storage.getStringList(_bookmarkKey(userId));
    return rawList.any((e) {
      try {
        final m = jsonDecode(e);
        return m['id']?.toString() == threadId ||
            m['tid']?.toString() == threadId;
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> queuePendingRemove(String threadId, String userId) async {
    final uid = _uid(userId);
    if (uid.isEmpty) return;
    await _removePendingId(_pendingAddsKey(uid), threadId);
    await _addPendingId(_pendingRemovesKey(uid), threadId);
  }

  Future<void> clearPendingAdd(String threadId, String userId) async {
    final uid = _uid(userId);
    if (uid.isNotEmpty) await _removePendingId(_pendingAddsKey(uid), threadId);
  }

  Future<void> clearPendingRemove(String threadId, String userId) async {
    final uid = _uid(userId);
    if (uid.isNotEmpty) {
      await _removePendingId(_pendingRemovesKey(uid), threadId);
    }
  }

  List<TiebaThreadModel> getPendingLocalBookmarks(String userId) {
    final uid = _uid(userId);
    if (uid.isEmpty) return const [];
    final pending = _storage.getStringList(_pendingAddsKey(uid)).toSet();
    return getLocalBookmarks(userId: uid)
        .where((thread) => pending.contains(thread.id))
        .toList();
  }

  Set<String> getPendingRemoveIds(String userId) {
    final uid = _uid(userId);
    if (uid.isEmpty) return const <String>{};
    return _storage.getStringList(_pendingRemovesKey(uid)).toSet();
  }

  /// 将官方收藏作为当前账号的权威列表写入缓存，同时保留尚未上传成功的本地收藏。
  Future<void> syncOfficialToLocal(
    List<TiebaThreadModel> threads, {
    String userId = '',
  }) async {
    final uid = _uid(userId);
    final localById = {
      for (final thread in getLocalBookmarks(userId: uid)) thread.id: thread,
    };
    final pendingAdds = _storage.getStringList(_pendingAddsKey(uid)).toSet();
    final pendingRemoves = _storage
        .getStringList(_pendingRemovesKey(uid))
        .toSet();
    final merged = <String, TiebaThreadModel>{
      for (final thread in threads)
        if (!pendingRemoves.contains(thread.id)) thread.id: thread,
    };

    for (final id in pendingAdds) {
      final local = localById[id];
      if (local != null && !pendingRemoves.contains(id)) merged[id] = local;
    }

    await _storage.setStringList(
      _bookmarkKey(uid),
      merged.values.map((thread) => jsonEncode(thread.toJson())).toList(),
    );
  }

  Future<void> mergeOfficialToLocal(
    List<TiebaThreadModel> threads, {
    String userId = '',
  }) async {
    final uid = _uid(userId);
    final pendingRemoves = _storage
        .getStringList(_pendingRemovesKey(uid))
        .toSet();
    final merged = {
      for (final thread in getLocalBookmarks(userId: uid))
        if (!pendingRemoves.contains(thread.id)) thread.id: thread,
    };
    for (final thread in threads) {
      if (!pendingRemoves.contains(thread.id)) {
        merged[thread.id] = thread;
      }
    }
    await _storage.setStringList(
      _bookmarkKey(uid),
      merged.values.map((thread) => jsonEncode(thread.toJson())).toList(),
    );
  }

  Future<({int changed, int failed})> syncPendingOfficialBookmarks({
    required String userId,
    required Set<String> officialIds,
    required String tbs,
  }) async {
    final uid = _uid(userId);
    if (uid.isEmpty || tbs.isEmpty) return (changed: 0, failed: 0);

    var changed = 0;
    var failed = 0;
    final localById = {
      for (final thread in getLocalBookmarks(userId: uid)) thread.id: thread,
    };

    for (final id in _storage.getStringList(_pendingAddsKey(uid)).toList()) {
      if (officialIds.contains(id)) {
        await clearPendingAdd(id, uid);
        continue;
      }
      final thread = localById[id];
      if (thread == null) continue;
      final ok = await addOfficialBookmark(
        threadId: id,
        postId: thread.firstPostId,
        tbs: tbs,
      );
      if (ok) {
        await clearPendingAdd(id, uid);
        changed++;
      } else {
        failed++;
      }
    }

    for (final id in _storage.getStringList(_pendingRemovesKey(uid)).toList()) {
      final ok = await removeOfficialBookmark(threadId: id, tbs: tbs);
      if (ok) {
        await clearPendingRemove(id, uid);
        changed++;
      } else {
        failed++;
      }
    }

    return (changed: changed, failed: failed);
  }
}

final bookmarksRepositoryProvider = Provider<BookmarksRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return BookmarksRepository(client, storage);
});

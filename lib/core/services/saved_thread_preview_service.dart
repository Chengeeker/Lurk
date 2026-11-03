import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../storage/storage_service.dart';
import '../../features/detail/data/detail_repository.dart';
import '../../features/detail/data/models/tieba_post_model.dart';
import '../../features/feed/data/models/tieba_thread_model.dart';

class SavedThreadPreviewService {
  SavedThreadPreviewService(this._ref);
  final Ref _ref;
  final _cache = <String, Future<TiebaThreadModel?>>{};
  final _lanes = [Future<void>.value(), Future<void>.value()];
  int _nextLane = 0;
  Future<void> _writes = Future<void>.value();

  static bool needsRecovery(TiebaThreadModel thread) =>
      thread.snippetSegments.isEmpty &&
      (thread.contentSnippet.trim().isEmpty ||
          RegExp('网页链接|网盘|下载地址|查看链接').hasMatch(thread.contentSnippet));

  Future<TiebaThreadModel?> _fetch(String id) async {
    try {
      final data = await _ref
          .read(detailRepositoryProvider)
          .getThreadDetail(threadId: id, page: 1);
      final floors = (data['floors'] as List?)?.whereType<TiebaFloorModel>();
      final first = floors?.where((floor) => floor.floor == 1).firstOrNull;
      if (first == null) return null;
      final preview = TiebaThreadModel.fromJson({
        'content': [
          for (final part in first.contentList)
            {
              'type': part.type,
              'text': part.text,
              if (part.c != null) 'c': part.c,
              if (part.url != null) 'link': part.url,
            },
        ],
      });
      return preview.snippetSegments.isEmpty ? null : preview;
    } catch (_) {
      return null;
    }
  }

  Future<TiebaThreadModel> recover(TiebaThreadModel thread) async {
    if (!needsRecovery(thread) || thread.id.isEmpty) return thread;
    final uid = _ref.read(authStateProvider).activeAccount?.uid ?? '';
    final request = _cache.putIfAbsent(thread.id, () {
      final lane = _nextLane++ % _lanes.length;
      final request = _lanes[lane].then((_) => _fetch(thread.id));
      _lanes[lane] = request.then<void>((_) {});
      return request;
    });
    if (_cache.length > 64) _cache.remove(_cache.keys.first);
    final preview = await request;
    if (preview == null ||
        (_ref.read(authStateProvider).activeAccount?.uid ?? '') != uid) {
      return thread;
    }
    final updated = thread.copyWith(
      contentSnippet: preview.contentSnippet,
      snippetSegments: preview.snippetSegments,
    );
    _writes = _writes
        .then((_) async {
          if ((_ref.read(authStateProvider).activeAccount?.uid ?? '') != uid) {
            return;
          }
          final storage = _ref.read(storageServiceProvider);
          for (final key in [
            StorageService.keyBrowsingHistory,
            StorageService.bookmarksKeyForAccount(uid),
          ]) {
            var changed = false;
            final values = storage.getStringList(key).map((raw) {
              try {
                final current = TiebaThreadModel.fromJson(jsonDecode(raw));
                if (current.id == thread.id &&
                    current.snippetSegments.isEmpty) {
                  changed = true;
                  return jsonEncode(
                    current
                        .copyWith(
                          contentSnippet: preview.contentSnippet,
                          snippetSegments: preview.snippetSegments,
                        )
                        .toJson(),
                  );
                }
              } catch (_) {}
              return raw;
            }).toList();
            if (changed) await storage.setStringList(key, values);
          }
        })
        .catchError((_) {});
    await _writes;
    return updated;
  }
}

final savedThreadPreviewServiceProvider = Provider(
  (ref) => SavedThreadPreviewService(ref),
);

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/haptic_feedback_util.dart';
import '../../../feed/data/models/tieba_thread_model.dart';
import '../../../feed/presentation/widgets/tieba_card.dart';
import '../../data/bookmarks_repository.dart';

class BookmarksView extends ConsumerStatefulWidget {
  const BookmarksView({super.key});

  @override
  ConsumerState<BookmarksView> createState() => _BookmarksViewState();
}

class _BookmarksViewState extends ConsumerState<BookmarksView> {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  List<TiebaThreadModel> _bookmarks = [];
  bool _isLoading = true;
  bool _isAscending = false;
  int _page = 0;
  bool _hasMore = false;
  bool _isCloudSync = false;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _isAscending = storage.getBool(
      StorageService.keyBookmarkSortOrder,
      defaultValue: false,
    );
    _initLoad();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    final authState = ref.read(authStateProvider);
    if (authState.isLoggedIn &&
        authState.activeAccount?.uid != null &&
        authState.activeAccount!.uid.isNotEmpty) {
      _isCloudSync = true;
      await ref
          .read(bookmarksRepositoryProvider)
          .migrateLegacyBookmarksToAccount(authState.activeAccount!.uid);
      await _fetchOfficialBookmarks(isRefresh: true);
    } else {
      _isCloudSync = false;
      _loadLocalBookmarks();
    }
  }

  void _loadLocalBookmarks() {
    final repo = ref.read(bookmarksRepositoryProvider);
    final uid = ref.read(authStateProvider).activeAccount?.uid ?? '';
    final list = repo.getLocalBookmarks(userId: uid, isAscending: _isAscending);
    setState(() {
      _bookmarks = list;
      _isLoading = false;
      _hasMore = false;
    });
  }

  Future<void> _fetchOfficialBookmarks({required bool isRefresh}) async {
    final authState = ref.read(authStateProvider);
    final uid = authState.activeAccount?.uid ?? '';
    final repo = ref.read(bookmarksRepositoryProvider);

    if (uid.isEmpty) {
      _loadLocalBookmarks();
      return;
    }

    final targetPage = isRefresh ? 0 : _page + 1;

    try {
      var list = await repo.getOfficialBookmarks(
        userId: uid,
        page: targetPage,
        pageSize: 20,
      );

      if (isRefresh) {
        final tbs = await ref.read(authStateProvider.notifier).getValidTbs();
        if (tbs.isNotEmpty) {
          final sync = await repo.syncPendingOfficialBookmarks(
            userId: uid,
            officialIds: list.map((thread) => thread.id).toSet(),
            tbs: tbs,
          );
          if (sync.changed > 0) {
            list = await repo.getOfficialBookmarks(
              userId: uid,
              page: 0,
              pageSize: 20,
            );
          }
        }
        await repo.syncOfficialToLocal(list, userId: uid);
        final pendingRemoves = repo.getPendingRemoveIds(uid);
        if (pendingRemoves.isNotEmpty) {
          list = list
              .where((thread) => !pendingRemoves.contains(thread.id))
              .toList();
        }
        final officialIds = list.map((thread) => thread.id).toSet();
        final pendingLocal = repo
            .getPendingLocalBookmarks(uid)
            .where((thread) => !officialIds.contains(thread.id))
            .toList();
        if (pendingLocal.isNotEmpty) list = [...list, ...pendingLocal];
      } else {
        await repo.mergeOfficialToLocal(list, userId: uid);
      }

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _bookmarks = list;
          _page = 0;
        } else {
          _bookmarks.addAll(list);
          _page = targetPage;
        }
        _hasMore = list.length >= 20;
        _isLoading = false;
      });

      if (isRefresh) {
        _refreshController.finishRefresh(IndicatorResult.success);
      } else {
        _refreshController.finishLoad(
          _hasMore ? IndicatorResult.success : IndicatorResult.noMore,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _isCloudSync = false;
      // 官方拉取失败时兜底读取本地
      if (_bookmarks.isEmpty) {
        _loadLocalBookmarks();
        AppToast.show(context, '云端同步失败，已展示本地缓存');
      } else {
        AppToast.show(context, '加载失败，请检查网络');
      }

      if (isRefresh) {
        _refreshController.finishRefresh(IndicatorResult.fail);
      } else {
        _refreshController.finishLoad(IndicatorResult.fail);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(TiebaThreadModel thread) async {
    final repo = ref.read(bookmarksRepositoryProvider);
    final authState = ref.read(authStateProvider);

    // 1. 本地立即清除
    setState(() {
      _bookmarks.removeWhere((e) => e.id == thread.id);
    });
    final uid = authState.activeAccount?.uid ?? '';
    await repo.removeLocalBookmark(thread.id, userId: uid);

    // 2. 如果登录，异步调用官方取消收藏
    if (authState.isLoggedIn) {
      final tbs = await ref.read(authStateProvider.notifier).getValidTbs();
      if (tbs.isNotEmpty) {
        final ok = await repo.removeOfficialBookmark(
          threadId: thread.id,
          tbs: tbs,
        );
        if (ok) {
          await repo.clearPendingAdd(thread.id, uid);
          await repo.clearPendingRemove(thread.id, uid);
        } else {
          await repo.queuePendingRemove(thread.id, uid);
        }
        if (mounted) {
          AppToast.show(context, ok ? '已从百度账号云端收藏中移除' : '已移除本地收藏（联网后自动重试云端同步）');
        }
        return;
      }
      await repo.queuePendingRemove(thread.id, uid);
    }

    if (mounted) {
      AppToast.show(context, '已移除收藏');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '我的收藏',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Row(
              children: [
                Icon(
                  _isCloudSync
                      ? Icons.cloud_done_rounded
                      : Icons.phone_android_rounded,
                  size: 12,
                  color: _isCloudSync
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  _isCloudSync ? '已与百度贴吧官方云端同步' : '本地收藏 (未登录百度账号)',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isCloudSync
                        ? colorScheme.primary
                        : colorScheme.outline,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: "排序预览",
            onSelected: (isAsc) {
              if (_isAscending != isAsc) {
                HapticFeedbackUtil.selection();
                setState(() {
                  _isAscending = isAsc;
                  _bookmarks = _bookmarks.reversed.toList();
                });
                ref
                    .read(storageServiceProvider)
                    .setBool(StorageService.keyBookmarkSortOrder, isAsc);
                AppToast.show(context, isAsc ? "已切换为：顺序预览" : "已切换为：倒序预览");
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    const Text("倒序预览（最新在前）"),
                    if (!_isAscending) ...[
                      const Spacer(),
                      Icon(
                        Icons.check_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    const Text("顺序预览（最早在前）"),
                    if (_isAscending) ...[
                      const Spacer(),
                      Icon(
                        Icons.check_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 64,
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无收藏的贴子',
                      style: TextStyle(
                        color: colorScheme.outline,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCloudSync
                          ? '您在贴吧官方客户端收藏的帖子将自动同步展现在这里'
                          : '在浏览帖子时点击收藏，将自动保存在这里；登录后可双向同步官方云端收藏',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.outline.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : EasyRefresh(
              controller: _refreshController,
              onRefresh: () async {
                if (authState.isLoggedIn) {
                  await _fetchOfficialBookmarks(isRefresh: true);
                } else {
                  _loadLocalBookmarks();
                  _refreshController.finishRefresh();
                }
              },
              onLoad: authState.isLoggedIn && _hasMore
                  ? () async {
                      await _fetchOfficialBookmarks(isRefresh: false);
                    }
                  : null,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _bookmarks.length,
                itemBuilder: (context, index) {
                  final thread = _bookmarks[index];
                  return Dismissible(
                    key: Key('bm_${thread.id}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    onDismissed: (_) => _removeBookmark(thread),
                    child: TiebaCard(thread: thread),
                  );
                },
              ),
            ),
    );
  }
}

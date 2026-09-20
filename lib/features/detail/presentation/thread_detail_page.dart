import 'dart:convert';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/providers/thread_agree_provider.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/app_dialog.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../../core/utils/tieba_emoticon_util.dart';
import '../../../core/utils/tieba_text_parser.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../feed/data/models/tieba_thread_model.dart';
import '../../forum/presentation/forum_view.dart';
import '../../profile/presentation/user_profile_page.dart';
import '../../profile/data/bookmarks_repository.dart';
import '../data/models/tieba_post_model.dart';
import 'detail_controller.dart';
import 'widgets/floor_item.dart';
import 'widgets/image_gallery_page.dart';

class ThreadDetailPage extends ConsumerStatefulWidget {
  final TiebaThreadModel thread;
  final String initialPostId;

  const ThreadDetailPage({
    super.key,
    required this.thread,
    this.initialPostId = '',
  });

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mainArticleKey = GlobalKey();
  final Map<String, GlobalKey> _floorKeys = {};
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );
  final TextEditingController _textController = TextEditingController();
  bool _isBookmarked = false;
  bool _targetScrollScheduled = false;

  void _scheduleTargetPostScroll(DetailState detailState) {
    final targetPostId = widget.initialPostId.trim();
    if (_targetScrollScheduled || targetPostId.isEmpty || targetPostId == '0') {
      return;
    }

    final targetFloor = detailState.floors.cast<TiebaFloorModel?>().firstWhere(
      (floor) => floor?.id == targetPostId,
      orElse: () => null,
    );
    if (targetFloor == null) return;

    _targetScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = targetFloor.floor == 1
          ? _mainArticleKey
          : _floorKeys[targetPostId];
      final targetContext = key?.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.thread.fid.isNotEmpty || widget.thread.fname.isNotEmpty) {
        ref
            .read(detailControllerFamily(widget.thread.id).notifier)
            .setForumInfo(
              widget.thread.fid,
              widget.thread.fname,
              widget.thread.forumAvatar,
            );
      }
      _recordHistory();
      _checkBookmark();
    });
  }

  void _recordHistory() {
    final storage = ref.read(storageServiceProvider);
    final doNotSave = storage.getBool(
      StorageService.keyHabitDoNotSaveHistory,
      defaultValue: false,
    );
    if (doNotSave) return;

    final historyList = storage.getStringList(
      StorageService.keyBrowsingHistory,
    );
    final threadJson = jsonEncode(widget.thread.toJson());

    final updated = historyList.where((e) {
      try {
        final map = jsonDecode(e);
        return map['id']?.toString() != widget.thread.id &&
            map['tid']?.toString() != widget.thread.id;
      } catch (_) {
        return true;
      }
    }).toList();

    updated.add(threadJson);
    if (updated.length > 200) {
      updated.removeRange(0, updated.length - 200);
    }
    storage.setStringList(StorageService.keyBrowsingHistory, updated);
  }

  void _checkBookmark() {
    final repo = ref.read(bookmarksRepositoryProvider);
    final uid = ref.read(authStateProvider).activeAccount?.uid ?? '';
    final isSaved = repo.isLocallyBookmarked(widget.thread.id, userId: uid);
    if (mounted && isSaved != _isBookmarked) {
      setState(() => _isBookmarked = isSaved);
    }
  }

  void _toggleBookmark() async {
    HapticFeedbackUtil.light();
    final repo = ref.read(bookmarksRepositoryProvider);
    final authState = ref.read(authStateProvider);
    final uid = authState.activeAccount?.uid ?? '';
    final isCurrentlySaved = _isBookmarked;

    if (isCurrentlySaved) {
      setState(() => _isBookmarked = false);
      await repo.removeLocalBookmark(widget.thread.id, userId: uid);
      if (authState.isLoggedIn) {
        final tbs = await ref.read(authStateProvider.notifier).getValidTbs();
        if (tbs.isNotEmpty) {
          final ok = await repo.removeOfficialBookmark(
            threadId: widget.thread.id,
            tbs: tbs,
          );
          if (ok) {
            await repo.clearPendingAdd(widget.thread.id, uid);
            await repo.clearPendingRemove(widget.thread.id, uid);
          } else {
            await repo.queuePendingRemove(widget.thread.id, uid);
          }
          if (mounted) {
            AppToast.show(
              context,
              ok ? '已从百度账号云端移除收藏' : '已取消本地收藏（联网后自动重试云端同步）',
            );
          }
          return;
        }
        await repo.queuePendingRemove(widget.thread.id, uid);
      }
      if (mounted) AppToast.show(context, '已取消收藏');
    } else {
      setState(() => _isBookmarked = true);
      await repo.saveLocalBookmark(widget.thread, userId: uid);
      if (authState.isLoggedIn) {
        final tbs = await ref.read(authStateProvider.notifier).getValidTbs();
        if (tbs.isNotEmpty) {
          final ok = await repo.addOfficialBookmark(
            threadId: widget.thread.id,
            postId: widget.thread.firstPostId,
            tbs: tbs,
          );
          if (ok) {
            await repo.clearPendingAdd(widget.thread.id, uid);
          }
          if (mounted) {
            AppToast.show(
              context,
              ok ? '已成功同步收藏至百度贴吧账号' : '已保存至本地收藏（联网后自动重试云端同步）',
            );
          }
          return;
        }
        // Keep the local copy marked as pending when TBS cannot be refreshed.
      }
      if (mounted) AppToast.show(context, '已保存至本地收藏（登录后可同步云端）');
    }
  }

  bool _isMyThread({TiebaAuthorModel? author}) {
    final account = ref.read(authStateProvider).activeAccount;
    final target = author ?? widget.thread.author;
    return account != null &&
        account.isLogin &&
        ((target.id.isNotEmpty &&
                target.id != '0' &&
                target.id == account.uid) ||
            (target.name.isNotEmpty && target.name == account.name) ||
            (target.portrait.isNotEmpty &&
                account.portrait.isNotEmpty &&
                target.portrait == account.portrait) ||
            (target.displayName.isNotEmpty &&
                (target.displayName == account.nameShow ||
                    target.displayName == account.name)));
  }

  Future<void> _deleteCurrentThread() async {
    if (!context.mounted) return;
    final confirmed = await AppDialog.confirm(
      context,
      title: '删除贴子',
      content: '确定要删除这个贴子吗？删除后将无法恢复。',
      confirmText: '删除',
      isDanger: true,
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(detailControllerFamily(widget.thread.id).notifier)
        .deleteCurrentThread(
          fallbackFid: widget.thread.fid,
          fallbackFname: widget.thread.fname,
        );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _cleanForumName(String name) {
    return name.replaceFirst(RegExp(r'吧$'), '').trim();
  }

  void _openForum(String forumName) {
    final cleanName = _cleanForumName(forumName);
    if (cleanName.isEmpty) return;
    Navigator.push(
      context,
      SpringPageRoute(page: ForumView(forumName: cleanName)),
    );
  }

  Widget _buildForumPill(
    BuildContext context, {
    required String forumName,
    required String forumAvatar,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = forumName.endsWith('吧') ? forumName : '$forumName吧';
    final avatarUrl = AppNetworkImage.safeUrl(
      TiebaConstants.getForumAvatarUrl(forumAvatar),
    );
    final maxTextWidth = (MediaQuery.sizeOf(context).width - 230)
        .clamp(72.0, 156.0)
        .toDouble();

    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openForum(forumName),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(url: avatarUrl, size: 32, radius: 16),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTextWidth),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAction({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: selected
                        ? (selectedColor ?? colorScheme.onSurface)
                        : colorScheme.outline,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detailState = ref.watch(detailControllerFamily(widget.thread.id));
    final forumName = detailState.forumName.isNotEmpty
        ? detailState.forumName
        : widget.thread.fname;
    final forumAvatar = detailState.forumAvatar.isNotEmpty
        ? detailState.forumAvatar
        : widget.thread.forumAvatar;
    _scheduleTargetPostScroll(detailState);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: forumName.isNotEmpty
            ? _buildForumPill(
                context,
                forumName: forumName,
                forumAvatar: forumAvatar,
              )
            : const SizedBox.shrink(),
        actions: [
          if (_isMyThread())
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '删除我的贴子',
              onPressed: _deleteCurrentThread,
            ),
          IconButton(
            icon: Icon(
              _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isBookmarked ? Colors.amber : null,
            ),
            tooltip: _isBookmarked ? '取消收藏' : '收藏贴子',
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: SelectionArea(
        child: EasyRefresh(
          controller: _refreshController,
          onRefresh: () async {
            await ref
                .read(detailControllerFamily(widget.thread.id).notifier)
                .refresh();
            _refreshController.finishRefresh();
          },
          onLoad: () async {
            await ref
                .read(detailControllerFamily(widget.thread.id).notifier)
                .loadMore();
            _refreshController.finishLoad(
              detailState.hasMore
                  ? IndicatorResult.success
                  : IndicatorResult.noMore,
            );
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. LZ Article Post Hero Card (楼主正文卡片)
              SliverToBoxAdapter(
                key: _mainArticleKey,
                child: _buildMainArticleCard(context, detailState),
              ),

              // 2. Comments Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '回复 ${detailState.floors.length > 1 ? detailState.floors.length - 1 : widget.thread.replyNum}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterAction(
                        label: '只看楼主',
                        selected: detailState.seeLzOnly,
                        selectedColor: colorScheme.primary,
                        onTap: () {
                          HapticFeedbackUtil.light();
                          ref
                              .read(
                                detailControllerFamily(widget.thread.id)
                                    .notifier,
                              )
                              .toggleSeeLzOnly();
                        },
                      ),
                      const Spacer(),
                      _buildFilterAction(
                        label: '正序',
                        selected: detailState.sortType == CommentSortType.asc,
                        onTap: () {
                          HapticFeedbackUtil.light();
                          ref
                              .read(
                                detailControllerFamily(widget.thread.id)
                                    .notifier,
                              )
                              .setSortType(CommentSortType.asc);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterAction(
                        label: '倒序',
                        selected: detailState.sortType == CommentSortType.desc,
                        onTap: () {
                          HapticFeedbackUtil.light();
                          ref
                              .read(
                                detailControllerFamily(widget.thread.id)
                                    .notifier,
                              )
                              .setSortType(CommentSortType.desc);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Comments Floors List (Floor 2, 3, 4...)
              if (detailState.floors.isEmpty && detailState.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else ...[
                () {
                  var comments = detailState.floors
                      .where((f) => f.floor != 1)
                      .toList();
                  if (detailState.seeLzOnly) {
                    comments = comments
                        .where(
                          (f) =>
                              f.author.id == widget.thread.author.id ||
                              f.author.displayName ==
                                  widget.thread.author.displayName,
                        )
                        .toList();
                  }

                  if (detailState.sortType == CommentSortType.hot) {
                    comments.sort(
                      (a, b) => (b.agreeNum + b.subPostCount * 2).compareTo(
                        a.agreeNum + a.subPostCount * 2,
                      ),
                    );
                  } else if (detailState.sortType == CommentSortType.desc) {
                    comments.sort((a, b) => b.floor.compareTo(a.floor));
                  } else {
                    comments.sort((a, b) => a.floor.compareTo(b.floor));
                  }

                  if (comments.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            detailState.seeLzOnly
                                ? '楼主暂无其他回复'
                                : '暂无更多回复，快来抢沙发吧~',
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final floor = comments[index];
                      final isLz =
                          floor.author.id == widget.thread.author.id ||
                          floor.author.displayName ==
                              widget.thread.author.displayName;
                      final floorItem = FloorItem(
                        floor: floor,
                        threadId: widget.thread.id,
                        isLz: isLz,
                        fallbackFid: widget.thread.fid,
                        fallbackFname: widget.thread.fname,
                      );
                      if (floor.id.isEmpty) return floorItem;
                      return KeyedSubtree(
                        key: _floorKeys.putIfAbsent(floor.id, GlobalKey.new),
                        child: floorItem,
                      );
                    }, childCount: comments.length),
                  );
                }(),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, detailState),
    );
  }

  Widget _buildBottomBar(BuildContext context, DetailState detailState) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom == 0
              ? MediaQuery.of(context).padding.bottom + 8
              : 8,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _textController,
                  enabled: !detailState.isSubmittingReply,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: detailState.isSubmittingReply
                        ? '正在发送中...'
                        : '说点什么吧...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: colorScheme.outline,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onSubmitted: (_) {
                    if (!detailState.isSubmittingReply) {
                      _handleSendReply(detailState);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: detailState.isSubmittingReply
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              onPressed: detailState.isSubmittingReply
                  ? null
                  : () => _handleSendReply(detailState),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendReply(DetailState detailState) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final auth = ref.read(authStateProvider);
    if (auth.activeAccount == null || !auth.activeAccount!.isLogin) {
      AppToast.show(context, '请先登录后再发表评论');
      return;
    }

    HapticFeedbackUtil.light();
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(detailControllerFamily(widget.thread.id).notifier)
        .sendReply(
          content: text,
          fallbackFid: widget.thread.fid.isNotEmpty ? widget.thread.fid : null,
          fallbackFname: widget.thread.fname.isNotEmpty
              ? widget.thread.fname
              : null,
        );

    if (success && mounted) {
      _textController.clear();
    }
  }

  Widget _buildLevelBadge(int level) {
    if (level <= 0) return const SizedBox.shrink();
    Color bgColor = const Color(0xFF8E8E93);
    if (level >= 16) {
      bgColor = const Color(0xFFFF9500);
    } else if (level >= 10) {
      bgColor = const Color(0xFFFF6A00);
    } else if (level >= 4) {
      bgColor = const Color(0xFF34C759);
    } else {
      bgColor = const Color(0xFF007AFF);
    }
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$level',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }

  String _formatDateTimeAndIp(int timestamp, String ip) {
    String dateStr = '';
    if (timestamp > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      dateStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final cleanIp = ip.replaceAll('来自', '').trim();
    if (cleanIp.isNotEmpty) {
      if (dateStr.isNotEmpty) {
        return '$dateStr · 来自$cleanIp';
      } else {
        return '来自$cleanIp';
      }
    }
    return dateStr;
  }

  Widget _buildMainArticleCard(BuildContext context, DetailState detailState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstFloor =
        detailState.floors.isNotEmpty && detailState.floors.first.floor == 1
        ? detailState.floors.first
        : null;

    final lzAuthor = firstFloor != null
        ? firstFloor.author
        : widget.thread.author;
    final authorName = lzAuthor.displayName;
    final authorPortrait = lzAuthor.portrait;

    // Collect all images from floor 1 or widget.thread.mediaList
    final List<String> imageUrls = [];
    if (firstFloor != null) {
      for (var seg in firstFloor.contentList) {
        if (seg.type == 3 || seg.type == 5) {
          final url = seg.originSrc ?? seg.bigCdnSrc ?? seg.cdnSrc ?? '';
          if (url.isNotEmpty) imageUrls.add(url);
        }
      }
    } else {
      for (var m in widget.thread.mediaList) {
        final url = m.originUrl.isNotEmpty ? m.originUrl : m.bigCdnUrl;
        if (url.isNotEmpty) imageUrls.add(url);
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LZ Author Header
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.push(
                      context,
                      SpringPageRoute(page: UserProfilePage(user: lzAuthor)),
                    );
                  },
                  child: AppAvatar(
                    portrait: authorPortrait,
                    size: 44,
                    radius: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedbackUtil.light();
                                Navigator.push(
                                  context,
                                  SpringPageRoute(
                                    page: UserProfilePage(user: lzAuthor),
                                  ),
                                );
                              },
                              child: Text(
                                authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          _buildLevelBadge(lzAuthor.level),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '楼主',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      () {
                        final time = (firstFloor != null && firstFloor.time > 0)
                            ? firstFloor.time
                            : (widget.thread.createTime > 0
                                  ? widget.thread.createTime
                                  : detailState.threadCreateTime);
                        final ip = lzAuthor.ipAddress.isNotEmpty
                            ? lzAuthor.ipAddress
                            : (widget.thread.author.ipAddress.isNotEmpty
                                  ? widget.thread.author.ipAddress
                                  : detailState.threadIp);
                        final timeAndIp = _formatDateTimeAndIp(time, ip);
                        final subtitleText = timeAndIp.isNotEmpty
                            ? timeAndIp
                            : (widget.thread.fname.isNotEmpty
                                  ? "${widget.thread.fname}吧"
                                  : "百度贴吧");

                        return Text(
                          subtitleText,
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 11.5,
                          ),
                        );
                      }(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Thread Title
            () {
              final titleText = widget.thread.title.isNotEmpty
                  ? widget.thread.title
                  : detailState.threadTitle;
              if (titleText.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              return const SizedBox.shrink();
            }(),

            // Post Content Text (Inline rich text supporting emoticons without linebreaks)
            if (firstFloor != null) ...[
              () {
                final spans = <InlineSpan>[];
                for (var seg in firstFloor.contentList) {
                  if (seg.type != 3 && seg.type != 5) {
                    if (seg.type == 2) {
                      spans.add(
                        TiebaEmoticonUtil.buildEmoticonSpan(
                          text: seg.text,
                          c: seg.c,
                          cdnUrl: seg.cdnSrc,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          size: 20.0,
                        ),
                      );
                    } else if (seg.text.isNotEmpty) {
                      spans.addAll(
                        TiebaTextParser.parseRichText(
                          context,
                          seg.text,
                          baseStyle: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                      );
                    }
                  }
                }
                if (spans.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: RichText(text: TextSpan(children: spans)),
                );
              }(),
            ] else if (widget.thread.contentSnippet.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: RichText(
                  text: TextSpan(
                    children: TiebaTextParser.parseRichText(
                      context,
                      widget.thread.contentSnippet,
                      baseStyle: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),

            // Post Images
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (int i = 0; i < imageUrls.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedbackUtil.light();
                      ImageGalleryPage.open(
                        context,
                        images: imageUrls,
                        initialIndex: i,
                        folderName: widget.thread.author.displayName,
                      );
                    },
                    child: AppNetworkImage(
                      url: imageUrls[i],
                      fit: BoxFit.contain,
                      constraints: const BoxConstraints(maxHeight: 400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                () {
                  final agreeRecord = ref.watch(
                    threadAgreeProvider,
                  )[widget.thread.id];
                  final bool currentAgreed =
                      agreeRecord?.isAgreed ??
                      detailState.isAgreed ??
                      widget.thread.isAgreed;
                  final int currentAgreeNum =
                      agreeRecord?.agreeNum ??
                      detailState.agreeNum ??
                      widget.thread.agreeNum;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedbackUtil.light();
                      final auth = ref.read(authStateProvider);
                      if (auth.activeAccount == null ||
                          !auth.activeAccount!.isLogin) {
                        AppToast.show(context, '请先登录后再点赞');
                        return;
                      }
                      final firstPostId =
                          (firstFloor != null && firstFloor.id.isNotEmpty)
                          ? firstFloor.id
                          : (detailState.firstPostId.isNotEmpty
                                ? detailState.firstPostId
                                : widget.thread.firstPostId);
                      ref
                          .read(
                            detailControllerFamily(widget.thread.id).notifier,
                          )
                          .toggleThreadAgree(
                            currentAgreed: currentAgreed,
                            currentAgreeNum: currentAgreeNum,
                            firstPostId: firstPostId,
                          );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentAgreed
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: currentAgreed
                                ? Colors.redAccent
                                : colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentAgreeNum > 0 ? '$currentAgreeNum' : '赞',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: currentAgreed
                                  ? Colors.redAccent
                                  : colorScheme.outline,
                              fontWeight: currentAgreed
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

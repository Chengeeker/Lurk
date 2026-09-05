import 'dart:convert';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../detail/presentation/thread_detail_page.dart';
import '../../feed/presentation/widgets/tieba_card.dart';
import '../../search/presentation/search_view.dart';
import '../data/models/forum_model.dart';
import '../data/forum_repository.dart';
import 'forum_controller.dart';

class ForumView extends ConsumerStatefulWidget {
  final String forumName;

  const ForumView({super.key, required this.forumName});

  @override
  ConsumerState<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends ConsumerState<ForumView> {
  final ScrollController _scrollController = ScrollController();
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );
  bool _showPinnedList = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordForumVisit();
    });
  }

  void _recordForumVisit([String? avatar]) {
    try {
      final storage = ref.read(storageServiceProvider);
      final doNotSave = storage.getBool(
        StorageService.keyHabitDoNotSaveHistory,
        defaultValue: false,
      );
      if (doNotSave) return;

      final historyList = storage.getStringList(
        StorageService.keyForumBrowsingHistory,
      );
      final List<Map<String, dynamic>> parsedList = [];
      String existingAvatar = "";
      for (var item in historyList) {
        try {
          final m = jsonDecode(item);
          if (m is Map) {
            if (m['name'] != widget.forumName) {
              parsedList.add(Map<String, dynamic>.from(m));
            } else {
              final oldAvatar = m['avatar']?.toString();
              if (oldAvatar != null && oldAvatar.isNotEmpty) {
                existingAvatar = oldAvatar;
              }
            }
          }
        } catch (_) {}
      }

      final resolvedAvatar = (avatar != null && avatar.isNotEmpty)
          ? avatar
          : existingAvatar;

      parsedList.insert(0, {
        'name': widget.forumName,
        'avatar': resolvedAvatar,
        'time': DateTime.now().millisecondsSinceEpoch,
      });

      if (parsedList.length > 100) {
        parsedList.removeRange(100, parsedList.length);
      }

      storage.setStringList(
        StorageService.keyForumBrowsingHistory,
        parsedList.map((e) => jsonEncode(e)).toList(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _showRuleDetailBottomSheet(
    BuildContext context,
    String forumId,
    String ruleTitle,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ruleFuture = ref
        .read(forumRepositoryProvider)
        .getForumRuleDetail(forumId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Top drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '本吧吧规',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: FutureBuilder<ForumRuleDetailModel?>(
                    future: ruleFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                '正在拉取官方吧规详细内容...',
                                style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '官方吧规加载失败',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '当前没有展示占位内容，请检查网络后关闭并重新打开。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.outline,
                                height: 1.5,
                              ),
                            ),
                          ],
                        );
                      }

                      final detail = snapshot.data;
                      if (detail == null || detail.isEmpty) {
                        // Only show the official summary; never fabricate rule text locally.
                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (ruleTitle.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.campaign_rounded,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ruleTitle,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '官方暂未返回详细条款内容。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.gavel_outlined,
                                        size: 48,
                                        color: colorScheme.outline.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '本吧暂未配置详细吧规',
                                        style: TextStyle(
                                          color: colorScheme.outline,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        children: [
                          if (detail.title.isNotEmpty) ...[
                            Text(
                              detail.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // Meta info (publisher, date)
                          if (detail.bazhuName.isNotEmpty ||
                              detail.publishTime.isNotEmpty) ...[
                            Row(
                              children: [
                                if (detail.bazhuName.isNotEmpty) ...[
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '发布人：${detail.bazhuName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (detail.publishTime.isNotEmpty) ...[
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '更新时间：${detail.publishTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Preface
                          if (detail.preface.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.tertiary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.format_quote_rounded,
                                    size: 18,
                                    color: colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      detail.preface,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Rules list
                          ...detail.rules.map((r) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (r.title.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  ...r.contents.map(
                                    (line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        line,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.55,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              '文明发帖，理性交流，共同维护良好贴吧秩序',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmUnfollow(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          '取消关注',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text('确定要取消关注「${widget.forumName}吧」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final res = await ref
                  .read(forumControllerFamily(widget.forumName).notifier)
                  .unfollowForum();
              if (context.mounted) {
                AppToast.show(
                  context,
                  res.success
                      ? '已取消关注'
                      : (res.errorMsg.isNotEmpty ? res.errorMsg : '操作失败，请稍后重试'),
                );
              }
            },
            child: Text(
              '确定取消',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final forumState = ref.watch(forumControllerFamily(widget.forumName));
    ref.listen<ForumState>(forumControllerFamily(widget.forumName), (
      prev,
      next,
    ) {
      final newAvatar = next.forum?.avatar;
      if (newAvatar != null &&
          newAvatar.isNotEmpty &&
          newAvatar != prev?.forum?.avatar) {
        _recordForumVisit(newAvatar);
      }
    });
    final forum = forumState.forum;
    final tabs = forum?.tabs ?? [];
    final rule = forum?.rule;
    final pinnedThreads = forumState.pinnedThreads;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.forumName}吧",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: '吧内搜索',
            onPressed: () {
              HapticFeedbackUtil.light();
              Navigator.push(
                context,
                SpringPageRoute(page: SearchView(forumName: widget.forumName)),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: '更多',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) async {
              HapticFeedbackUtil.light();
              if (value == 'share') {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        'https://tieba.baidu.com/f?kw=${Uri.encodeComponent(widget.forumName)}',
                  ),
                );
                AppToast.show(context, '已复制贴吧链接');
              } else if (value == 'unfollow') {
                final account = ref.read(authStateProvider).activeAccount;
                if (account == null || !account.isLogin) {
                  AppToast.show(context, '请先登录百度账号');
                  return;
                }
                if (!(forum?.isLiked ?? false)) {
                  AppToast.show(context, '尚未关注该贴吧');
                  return;
                }
                _confirmUnfollow(context);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('分享'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'unfollow',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('取消关注'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: EasyRefresh(
        controller: _refreshController,
        onRefresh: () async {
          await ref
              .read(forumControllerFamily(widget.forumName).notifier)
              .refresh();
          _refreshController.finishRefresh();
        },
        onLoad: () async {
          await ref
              .read(forumControllerFamily(widget.forumName).notifier)
              .loadMore();
          _refreshController.finishLoad(
            forumState.hasMore
                ? IndicatorResult.success
                : IndicatorResult.noMore,
          );
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1. Unified Forum Header Card (Avatar + Info + Slogan + Tabs + Rule + Pinned + Sort)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Forum Info Banner Card
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            AppAvatar(
                              url: forum != null
                                  ? TiebaConstants.getForumAvatarUrl(
                                      forum.avatar,
                                    )
                                  : null,
                              size: 48,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${widget.forumName}吧",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (forum != null)
                                    Text(
                                      "关注 ${forum.memberNum}  |  帖子 ${forum.postNum}",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  if (forum != null && forum.slogan.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        forum.slogan,
                                        style: TextStyle(
                                          color: colorScheme.outline,
                                          fontSize: 10.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (forum != null) ...[
                              const SizedBox(width: 8),
                              _buildHeaderActionButton(
                                context: context,
                                forum: forum,
                                forumState: forumState,
                                colorScheme: colorScheme,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Dynamic Tabs Row (全部, 最新精华, 吧友互助, 前瞻资讯区, 强度讨论区, 剧情交流区...)
                    if (tabs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: tabs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final tab = tabs[index];
                            final isSelected =
                                forumState.currentTabIndex == index;

                            return FilterChip(
                              selected: isSelected,
                              label: Text(
                                tab.tabName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              backgroundColor: colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              selectedColor: colorScheme.primaryContainer,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant.withValues(
                                        alpha: 0.25,
                                      ),
                                width: 0.8,
                              ),
                              onSelected: (_) {
                                HapticFeedbackUtil.light();
                                ref
                                    .read(
                                      forumControllerFamily(widget.forumName)
                                          .notifier,
                                    )
                                    .selectTab(index, tab);
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    // Forum Rule Bar (吧规)
                    if (rule != null && rule.title.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedbackUtil.light();
                          _showRuleDetailBottomSheet(
                            context,
                            forum?.id ?? '',
                            rule.title,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.2,
                              ),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.campaign_rounded,
                                size: 16,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "吧规: ${rule.title}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: colorScheme.tertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Pinned Threads Section (置顶贴)
                    if (pinnedThreads.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.25,
                            ),
                            width: 0.6,
                          ),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedbackUtil.light();
                                setState(
                                  () => _showPinnedList = !_showPinnedList,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '置顶',
                                        style: TextStyle(
                                          color: colorScheme.onErrorContainer,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${pinnedThreads.length} 篇置顶帖',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: colorScheme.outline,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      _showPinnedList
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: colorScheme.outline,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showPinnedList) ...[
                              const Divider(height: 1),
                              for (
                                int i = 0;
                                i < pinnedThreads.length;
                                i++
                              ) ...[
                                if (i > 0) const Divider(height: 1, indent: 10),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                  leading: Icon(
                                    Icons.push_pin_rounded,
                                    size: 14,
                                    color: colorScheme.error,
                                  ),
                                  title: Text(
                                    pinnedThreads[i].title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    '${pinnedThreads[i].replyNum} 回复',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  onTap: () {
                                    HapticFeedbackUtil.light();
                                    Navigator.push(
                                      context,
                                      SpringPageRoute(
                                        page: ThreadDetailPage(
                                          thread: pinnedThreads[i],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Sort Options Row
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildSortChip(0, '按回复时间', colorScheme),
                        const SizedBox(width: 8),
                        _buildSortChip(1, '按发帖时间', colorScheme),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Thread List
            if (forumState.threads.isEmpty &&
                (forumState.isLoading || forumState.isRefreshing))
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (forumState.threads.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 48,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '本板块暂无帖子',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final thread = forumState.threads[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: TiebaCard(thread: thread),
                  );
                }, childCount: forumState.threads.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(int type, String label, ColorScheme colorScheme) {
    final forumState = ref.watch(forumControllerFamily(widget.forumName));
    final isSelected = forumState.sortType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedbackUtil.light();
        ref
            .read(forumControllerFamily(widget.forumName).notifier)
            .setSortType(type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required BuildContext context,
    required ForumDetailModel forum,
    required ForumState forumState,
    required ColorScheme colorScheme,
  }) {
    // 1. 未关注贴吧: 显示关注按钮
    if (!forum.isLiked) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: forumState.isFollowing
              ? null
              : () async {
                  HapticFeedbackUtil.light();
                  final res = await ref
                      .read(forumControllerFamily(widget.forumName).notifier)
                      .followForum();
                  if (context.mounted) {
                    AppToast.show(
                      context,
                      res.success
                          ? '关注成功！'
                          : (res.errorMsg.isNotEmpty
                                ? res.errorMsg
                                : '关注失败，请稍后重试'),
                    );
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: forumState.isFollowing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '关注',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    // 2. 已关注且已签到: 显示已签到（置灰禁用）
    if (forum.isSigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 14,
              color: colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              '已签到',
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // 3. 已关注且未签到: 显示签到按钮
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: forumState.isSigningIn
            ? null
            : () async {
                HapticFeedbackUtil.light();
                final success = await ref
                    .read(forumControllerFamily(widget.forumName).notifier)
                    .signIn();
                if (context.mounted) {
                  AppToast.show(context, success ? '签到成功！' : '签到失败，请稍后重试');
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: forumState.isSigningIn
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onPrimary,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 14,
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '签到',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

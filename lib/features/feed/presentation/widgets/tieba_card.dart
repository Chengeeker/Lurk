import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/auth/auth_provider.dart";
import "../../../../core/providers/thread_agree_provider.dart";
import "../../../../core/services/share_service.dart";
import "../../../../core/utils/app_toast.dart";
import "../../../../core/utils/haptic_feedback_util.dart";
import "../../../../core/utils/spring_page_route.dart";
import "../../../../core/utils/tieba_text_parser.dart";
import "../../../../core/widgets/app_avatar.dart";
import "../../../../core/widgets/app_network_image.dart";
import "../../../detail/presentation/thread_detail_page.dart";
import "../../../forum/presentation/forum_view.dart";
import "../../../profile/presentation/user_profile_page.dart";
import "../../data/feed_repository.dart";
import "../../data/models/tieba_thread_model.dart";
import "../../../settings/presentation/providers/habit_settings_provider.dart";
import "../feed_controller.dart";
import "nine_grid_view.dart";

class TiebaCard extends ConsumerStatefulWidget {
  final TiebaThreadModel thread;
  final ValueChanged<bool>? onAgreeToggle;

  const TiebaCard({super.key, required this.thread, this.onAgreeToggle});

  @override
  ConsumerState<TiebaCard> createState() => _TiebaCardState();
}

class _TiebaCardState extends ConsumerState<TiebaCard> {
  late bool _isAgreed;
  late int _agreeNum;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isAgreed = widget.thread.isAgreed;
    _agreeNum = widget.thread.agreeNum;
  }

  @override
  void didUpdateWidget(covariant TiebaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.id != widget.thread.id ||
        oldWidget.thread.isAgreed != widget.thread.isAgreed ||
        oldWidget.thread.agreeNum != widget.thread.agreeNum) {
      _isAgreed = widget.thread.isAgreed;
      _agreeNum = widget.thread.agreeNum;
    }
  }

  String _formatRelativeTime(int timestamp) {
    if (timestamp <= 0) return "";
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;
    if (diff < 60) return "${diff > 0 ? diff : 1}秒前";
    if (diff < 3600) return "${(diff / 60).floor()}分钟前";
    if (diff < 86400) return "${(diff / 3600).floor()}小时前";
    if (diff < 86400 * 30) return "${(diff / 86400).floor()}天前";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _navigateToUserProfile(BuildContext context) {
    HapticFeedbackUtil.light();
    Navigator.push(
      context,
      SpringPageRoute(page: UserProfilePage(user: widget.thread.author)),
    );
  }

  Future<void> _handleToggleAgree() async {
    if (_isProcessing) return;
    HapticFeedbackUtil.light();
    final auth = ref.read(authStateProvider);
    if (auth.activeAccount == null || !auth.activeAccount!.isLogin) {
      AppToast.show(context, '请先登录后再点赞');
      return;
    }

    final agreeRecord = ref.read(threadAgreeProvider)[widget.thread.id];
    final oldAgreed = agreeRecord?.isAgreed ?? _isAgreed;
    final oldCount = agreeRecord?.agreeNum ?? _agreeNum;
    final newAgreed = !oldAgreed;
    final newCount = (oldCount + (newAgreed ? 1 : -1)).clamp(0, 999999);

    // 0 延迟即刻在全局与卡片呈现红心与计数
    ref
        .read(threadAgreeProvider.notifier)
        .setAgree(widget.thread.id, newAgreed, newCount);
    setState(() {
      _isAgreed = newAgreed;
      _agreeNum = newCount;
      _isProcessing = true;
    });

    final account = auth.activeAccount!;
    final tbs = await ref.read(authStateProvider.notifier).getValidTbs();
    final repo = ref.read(feedRepositoryProvider);
    final targetPostId = widget.thread.firstPostId.isNotEmpty
        ? widget.thread.firstPostId
        : '0';

    try {
      var res = await repo.opAgree(
        threadId: widget.thread.id,
        postId: targetPostId,
        objType: '3',
        isAgree: newAgreed,
        tbs: tbs.isNotEmpty ? tbs : account.tbs,
      );

      // 若返回 TBS 校验失败，通过原生客户端重新刷新并重试一次
      if (!res.success &&
          (res.errorMsg.contains('TBS') || res.errorMsg.contains('tbs'))) {
        final freshTbs = await ref
            .read(authStateProvider.notifier)
            .getValidTbs(forceRefresh: true);
        if (freshTbs.isNotEmpty && freshTbs != tbs) {
          res = await repo.opAgree(
            threadId: widget.thread.id,
            postId: targetPostId,
            objType: '3',
            isAgree: newAgreed,
            tbs: freshTbs,
          );
        }
      }

      if (!res.success) {
        ref
            .read(threadAgreeProvider.notifier)
            .setAgree(widget.thread.id, oldAgreed, oldCount);
        if (mounted) {
          setState(() {
            _isAgreed = oldAgreed;
            _agreeNum = oldCount;
          });
          AppToast.show(
            context,
            res.errorMsg.isNotEmpty ? res.errorMsg : '点赞失败，请重试',
          );
        }
      } else {
        widget.onAgreeToggle?.call(newAgreed);
        ref
            .read(feedControllerProvider.notifier)
            .syncThreadAgree(widget.thread.id, newAgreed, newCount);
        ref
            .read(followFeedControllerProvider.notifier)
            .syncThreadAgree(widget.thread.id, newAgreed, newCount);
      }
    } catch (_) {
      ref
          .read(threadAgreeProvider.notifier)
          .setAgree(widget.thread.id, oldAgreed, oldCount);
      if (mounted) {
        setState(() {
          _isAgreed = oldAgreed;
          _agreeNum = oldCount;
        });
        AppToast.show(context, '网络异常，点赞失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final habitState = ref.watch(habitSettingsProvider);
    final isNoImageMode =
        habitState.imageLoadMode == 1 || habitState.imageLoadMode == 3;
    final timeStr = _formatRelativeTime(thread.createTime);

    final agreeRecord = ref.watch(threadAgreeProvider)[thread.id];
    final bool isAgreed = agreeRecord?.isAgreed ?? _isAgreed;
    final int agreeNum = agreeRecord?.agreeNum ?? _agreeNum;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            SpringPageRoute(
              page: ThreadDetailPage(
                thread: thread.copyWith(isAgreed: isAgreed, agreeNum: agreeNum),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 作者头像与信息
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToUserProfile(context),
                    child: AppAvatar(
                      portrait: thread.author.portrait,
                      size: 38,
                      radius: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _navigateToUserProfile(context),
                          child: Text(
                            thread.author.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        () {
                          final cleanIp = thread.author.ipAddress
                              .replaceAll('来自', '')
                              .trim();
                          final displaySub = [
                            if (timeStr.isNotEmpty) timeStr,
                            if (cleanIp.isNotEmpty) '来自$cleanIp',
                          ].join(' · ');

                          if (displaySub.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 1.5),
                            child: Text(
                              displaySub,
                              style: TextStyle(
                                color: colorScheme.outline,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }(),
                      ],
                    ),
                  ),
                  if (thread.isTop)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "置顶",
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. 贴子标题
              if (thread.title.isNotEmpty)
                Text(
                  thread.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              // 3. 贴子正文摘要
              if (thread.contentSnippet.isNotEmpty &&
                  thread.contentSnippet != thread.title)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RichText(
                    text: TextSpan(
                      children: TiebaTextParser.parseRichText(
                        context,
                        thread.contentSnippet,
                        baseStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // 4. 图片 / 视频媒体九宫格（无图模式下直接隐藏，纯文本展示，不留任何占位空白）
              if (thread.mediaList.isNotEmpty && !isNoImageMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: NineGridView(
                    mediaList: thread.mediaList,
                    threadId: thread.id,
                    folderName: thread.author.displayName,
                  ),
                ),

              // 5. 吧名标签胶囊
              if (thread.fname.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Navigator.push(
                        context,
                        SpringPageRoute(
                          page: ForumView(forumName: thread.fname),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (thread.forumAvatar.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: AppNetworkImage(
                                url: thread.forumAvatar,
                                width: 15,
                                height: 15,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ] else
                            Icon(
                              Icons.forum_outlined,
                              size: 13,
                              color: colorScheme.outline,
                            ),
                          Text(
                            "${thread.fname}吧",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 4),

              // 6. 交互底栏 (分享、回复、点赞)
              Row(
                children: [
                  // 分享
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedbackUtil.light();
                        ShareService.shareThread(context, thread);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.share_outlined,
                              size: 17,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "分享",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 回复
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedbackUtil.light();
                        Navigator.push(
                          context,
                          SpringPageRoute(
                            page: ThreadDetailPage(
                              thread: thread.copyWith(
                                isAgreed: isAgreed,
                                agreeNum: agreeNum,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 17,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              thread.replyNum > 0 ? "${thread.replyNum}" : "回复",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 点赞
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _handleToggleAgree,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isAgreed
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: isAgreed
                                  ? Colors.redAccent
                                  : colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              agreeNum > 0 ? "$agreeNum" : "点赞",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isAgreed
                                    ? Colors.redAccent
                                    : colorScheme.outline,
                                fontWeight: isAgreed
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

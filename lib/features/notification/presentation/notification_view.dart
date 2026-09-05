import "package:easy_refresh/easy_refresh.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/utils/app_toast.dart";
import "../../../core/utils/haptic_feedback_util.dart";
import "../../../core/utils/spring_page_route.dart";
import "../../../core/widgets/app_avatar.dart";
import "../../detail/presentation/thread_detail_page.dart";
import "../../feed/data/models/tieba_thread_model.dart";
import "../../profile/presentation/user_profile_page.dart";
import "../data/models/tieba_notification_model.dart";
import "notification_controller.dart";

class NotificationView extends ConsumerWidget {
  const NotificationView({super.key});

  String _formatRelativeTime(int timestamp) {
    if (timestamp <= 0) return "";
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;
    if (diff < 60) return "刚刚";
    if (diff < 3600) return "${diff ~/ 60}分钟前";
    if (diff < 86400) return "${diff ~/ 3600}小时前";
    if (diff < 86400 * 30) return "${diff ~/ 86400}天前";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return "${date.month}月${date.day}日";
  }

  void _openThread(BuildContext context, TiebaNotificationModel item) {
    if (item.threadId.isEmpty || item.threadId == "0") {
      AppToast.show(context, "未找到关联贴子");
      return;
    }
    HapticFeedbackUtil.light();
    Navigator.push(
      context,
      SpringPageRoute(
        page: ThreadDetailPage(
          thread: TiebaThreadModel(
            id: item.threadId,
            title: item.title.isNotEmpty
                ? item.title
                : (item.quoteContent.isNotEmpty ? item.quoteContent : "贴子详情"),
            fname: item.fname,
            contentSnippet: item.quoteContent.isNotEmpty ? item.quoteContent : item.content,
            replyNum: 0,
            agreeNum: 0,
            isAgreed: false,
            isTop: false,
            author: const TiebaAuthorModel(id: "0", name: "", nameShow: "贴吧吧友", portrait: ""),
          ),
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context, TiebaNotificationModel item) {
    HapticFeedbackUtil.light();
    Navigator.push(
      context,
      SpringPageRoute(
        page: UserProfilePage(
          user: TiebaAuthorModel(
            id: item.authorId,
            name: item.authorName,
            nameShow: item.authorName,
            portrait: item.authorPortrait,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    TiebaNotificationModel item,
  ) {
    final timeStr = _formatRelativeTime(item.time);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08), width: 0.8),
      ),
      child: InkWell(
        onTap: () => _openThread(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：头像 + 昵称 + 吧名 + 时间
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openUserProfile(context, item),
                    child: AppAvatar(portrait: item.authorPortrait, size: 38, radius: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () => _openUserProfile(context, item),
                                child: Text(
                                  item.authorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (item.fname.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${item.fname}吧",
                                  style: TextStyle(fontSize: 10, color: colorScheme.outline),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (timeStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              timeStr,
                              style: TextStyle(fontSize: 11, color: colorScheme.outline),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.outline.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 8),

              // 正文内容
              if (item.content.isNotEmpty)
                Text(
                  item.content,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13.5, height: 1.4),
                ),

              // 原贴 / 引用内容卡片
              if (item.quoteContent.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: colorScheme.primary.withValues(alpha: 0.6), width: 3),
                    ),
                  ),
                  child: Text(
                    "原内容：${item.quoteContent}",
                    style: TextStyle(fontSize: 12, color: colorScheme.outline, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifState = ref.watch(notificationControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("消息通知", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          bottom: const TabBar(
            tabs: [
              Tab(text: "回复我的"),
              Tab(text: "@提到我的"),
            ],
          ),
        ),
        body: EasyRefresh(
          onRefresh: () async {
            await ref.read(notificationControllerProvider.notifier).refresh();
          },
          child: TabBarView(
            children: [
              // 回复列表
              notifState.replies.isEmpty && !notifState.isLoading
                  ? Center(child: Text("暂无回复消息", style: TextStyle(color: colorScheme.outline)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: notifState.replies.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(context, theme, colorScheme, notifState.replies[index]);
                      },
                    ),

              // @ 列表
              notifState.atList.isEmpty && !notifState.isLoading
                  ? Center(child: Text("暂无@消息", style: TextStyle(color: colorScheme.outline)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: notifState.atList.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(context, theme, colorScheme, notifState.atList[index]);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

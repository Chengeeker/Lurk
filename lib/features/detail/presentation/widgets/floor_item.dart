import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/haptic_feedback_util.dart';
import '../../../../core/utils/spring_page_route.dart';
import '../../../../core/utils/tieba_emoticon_util.dart';
import '../../../../core/utils/tieba_text_parser.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../profile/presentation/user_profile_page.dart';
import '../../data/models/tieba_post_model.dart';
import '../detail_controller.dart';
import 'image_gallery_page.dart';
import 'sub_floor_sheet.dart';

/// 贴吧原生楼层评论组件 (支持发帖时间、作者ID、等级、第几楼、IP属地、原生点赞)
class FloorItem extends ConsumerWidget {
  final TiebaFloorModel floor;
  final String threadId;
  final bool isLz;
  final String? fallbackFid;
  final String? fallbackFname;

  const FloorItem({
    super.key,
    required this.floor,
    required this.threadId,
    this.isLz = false,
    this.fallbackFid,
    this.fallbackFname,
  });

  String _formatRelativeTime(int timestamp) {
    if (timestamp <= 0) return '';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;
    if (diff < 60) return '刚刚';
    if (diff < 3600) return '${(diff / 60).floor()}分钟前';
    if (diff < 86400) return '${(diff / 3600).floor()}小时前';
    if (diff < 86400 * 30) return '${(diff / 86400).floor()}天前';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildLevelBadge(int level) {
    Color bgColor;
    if (level >= 16) {
      bgColor = const Color(0xFFFF5252);
    } else if (level >= 10) {
      bgColor = const Color(0xFFE67E22);
    } else if (level >= 4) {
      bgColor = const Color(0xFF2E86DE);
    } else {
      bgColor = const Color(0xFF16A085);
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

  String _buildSubtitle() {
    final List<String> parts = [];
    final timeStr = _formatRelativeTime(floor.time);
    if (timeStr.isNotEmpty) parts.add(timeStr);
    parts.add('第 ${floor.floor} 楼');
    if (floor.author.ipAddress.isNotEmpty) {
      parts.add('来自${floor.author.ipAddress}');
    }
    return parts.join(' · ');
  }

  void _navigateToUserProfile(BuildContext context) {
    HapticFeedbackUtil.light();
    Navigator.push(
      context,
      SpringPageRoute(page: UserProfilePage(user: floor.author)),
    );
  }

  Widget _buildAgreeButton(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedbackUtil.light();
        ref
            .read(detailControllerFamily(threadId).notifier)
            .toggleFloorAgree(floor.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              floor.isAgreed
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 18,
              color: floor.isAgreed ? Colors.redAccent : colorScheme.outline,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 26,
              child: Text(
                floor.agreeNum > 0 ? '${floor.agreeNum}' : '',
                style: TextStyle(
                  fontSize: 12,
                  color: floor.isAgreed
                      ? Colors.redAccent
                      : colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton(
    BuildContext context,
    WidgetRef ref, {
    required bool canDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedbackUtil.light();
        _showFloorActionSheet(context, ref, canDelete: canDelete);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: colorScheme.outline.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  void _showFloorActionSheet(
    BuildContext context,
    WidgetRef ref, {
    required bool canDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textContent = floor.contentList.map((c) => c.text).join('');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: Text('回复第 ${floor.floor} 楼'),
                  onTap: () {
                    Navigator.pop(ctx);
                    SubFloorSheet.show(
                      context,
                      threadId: threadId,
                      postId: floor.id,
                      floorNum: floor.floor,
                      fallbackFid: fallbackFid,
                      fallbackFname: fallbackFname,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('复制内容'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (textContent.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: textContent));
                      AppToast.show(context, '已复制到剪贴板');
                    }
                  },
                ),
                if (canDelete)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      '删除评论',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await AppDialog.confirm(
                        context,
                        title: '删除评论',
                        content: '确定要删除这条回复吗？删除后将无法恢复。',
                        confirmText: '删除',
                        isDanger: true,
                      );
                      if (confirmed == true) {
                        ref
                            .read(detailControllerFamily(threadId).notifier)
                            .deleteFloor(
                              floor.id,
                              fallbackFid: fallbackFid,
                              fallbackFname: fallbackFname,
                            );
                      }
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final account = ref.watch(authStateProvider).activeAccount;
    final bool isMyPost =
        account != null &&
        account.isLogin &&
        ((floor.author.id.isNotEmpty &&
                floor.author.id != '0' &&
                floor.author.id == account.uid) ||
            (floor.author.name.isNotEmpty &&
                floor.author.name == account.name) ||
            (floor.author.portrait.isNotEmpty &&
                account.portrait.isNotEmpty &&
                floor.author.portrait == account.portrait) ||
            (floor.author.displayName.isNotEmpty &&
                (floor.author.displayName == account.nameShow ||
                    floor.author.displayName == account.name)));

    final detailState = ref.watch(detailControllerFamily(threadId));
    final bool isUserThreadAuthor =
        account != null &&
        account.isLogin &&
        detailState.floors.isNotEmpty &&
        detailState.floors.first.floor == 1 &&
        ((detailState.floors.first.author.id.isNotEmpty &&
                detailState.floors.first.author.id != '0' &&
                detailState.floors.first.author.id == account.uid) ||
            (detailState.floors.first.author.name.isNotEmpty &&
                detailState.floors.first.author.name == account.name));

    final bool canDelete = isMyPost || isUserThreadAuthor;

    final imageSegments = floor.contentList
        .where((c) => c.type == 3 || c.type == 5)
        .toList();
    final imageUrls = imageSegments
        .map((s) => s.originSrc ?? s.bigCdnSrc ?? s.cdnSrc ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return InkWell(
      onLongPress: () {
        HapticFeedbackUtil.light();
        _showFloorActionSheet(context, ref, canDelete: canDelete);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 发帖人头像 (可点击进入个人主页)
            GestureDetector(
              onTap: () => _navigateToUserProfile(context),
              child: AppAvatar(
                portrait: floor.author.portrait,
                size: 36,
                radius: 18,
              ),
            ),
            const SizedBox(width: 10),

            // 2. 评论右侧主体
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部信息栏：左侧身份信息 (自适应) + 右侧锚定点赞与更多
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () => _navigateToUserProfile(context),
                                child: Text(
                                  floor.author.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            _buildLevelBadge(floor.author.level),
                            if (isLz) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.6),
                                    width: 0.6,
                                  ),
                                ),
                                child: const Text(
                                  '楼主',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 统一右侧严丝合缝点赞组件
                      _buildAgreeButton(context, ref),
                      const SizedBox(width: 2),
                      _buildMoreButton(context, ref, canDelete: canDelete),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // 发帖时间 · 第几楼 · 来自 IP
                  Text(
                    _buildSubtitle(),
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 评论正文内容 (富文本 + 贴吧高清表情)
                  ...() {
                    final widgets = <Widget>[];
                    var currentInlineSpans = <InlineSpan>[];
                    int imgIdx = 0;

                    void flushSpans() {
                      if (currentInlineSpans.isNotEmpty) {
                        widgets.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: RichText(
                              text: TextSpan(
                                children: List.from(currentInlineSpans),
                              ),
                            ),
                          ),
                        );
                        currentInlineSpans = [];
                      }
                    }

                    for (final seg in floor.contentList) {
                      if (seg.type == 3 || seg.type == 5) {
                        flushSpans();
                        final displayUrl =
                            seg.originSrc ?? seg.bigCdnSrc ?? seg.cdnSrc ?? '';
                        if (displayUrl.isNotEmpty) {
                          final currentIdx = imgIdx++;
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: GestureDetector(
                                onTap: () => ImageGalleryPage.open(
                                  context,
                                  images: imageUrls,
                                  initialIndex: currentIdx.clamp(
                                    0,
                                    imageUrls.isEmpty
                                        ? 0
                                        : imageUrls.length - 1,
                                  ),
                                  folderName: floor.author.displayName,
                                ),
                                child: AppNetworkImage(
                                  url: displayUrl,
                                  fit: BoxFit.cover,
                                  constraints: const BoxConstraints(
                                    maxHeight: 280,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          );
                        }
                      } else if (seg.type == 2) {
                        currentInlineSpans.add(
                          TiebaEmoticonUtil.buildEmoticonSpan(
                            text: seg.text,
                            c: seg.c,
                            cdnUrl: seg.cdnSrc,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            size: 19.0,
                          ),
                        );
                      } else if (seg.text.isNotEmpty) {
                        currentInlineSpans.addAll(
                          TiebaTextParser.parseRichText(
                            context,
                            seg.text,
                            baseStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        );
                      }
                    }
                    flushSpans();
                    return widgets;
                  }(),

                  // 楼中楼回复卡片预览
                  if (floor.subPostCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          SubFloorSheet.show(
                            context,
                            threadId: threadId,
                            postId: floor.id,
                            floorNum: floor.floor,
                            fallbackFid: fallbackFid,
                            fallbackFname: fallbackFname,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...floor.subPosts.take(2).map((sp) {
                                final text = sp.contentList
                                    .map((c) => c.text)
                                    .join('');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "${sp.author.displayName}: ",
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        TextSpan(
                                          text: text,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              Text(
                                "共 ${floor.subPostCount} 条回复 >",
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

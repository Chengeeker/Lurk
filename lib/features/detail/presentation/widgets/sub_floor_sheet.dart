import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/haptic_feedback_util.dart';
import '../../../../core/utils/tieba_emoticon_util.dart';
import '../../../../core/utils/tieba_text_parser.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../data/detail_repository.dart';
import '../../data/models/tieba_post_model.dart';
import '../detail_controller.dart';

class SubFloorSheet extends ConsumerStatefulWidget {
  final String threadId;
  final String postId;
  final int floorNum;
  final String? fallbackFid;
  final String? fallbackFname;

  const SubFloorSheet({
    super.key,
    required this.threadId,
    required this.postId,
    required this.floorNum,
    this.fallbackFid,
    this.fallbackFname,
  });

  static void show(
    BuildContext context, {
    required String threadId,
    required String postId,
    required int floorNum,
    String? fallbackFid,
    String? fallbackFname,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubFloorSheet(
        threadId: threadId,
        postId: postId,
        floorNum: floorNum,
        fallbackFid: fallbackFid,
        fallbackFname: fallbackFname,
      ),
    );
  }

  @override
  ConsumerState<SubFloorSheet> createState() => _SubFloorSheetState();
}

class _SubFloorSheetState extends ConsumerState<SubFloorSheet> {
  final List<TiebaSubPostModel> _subPosts = [];
  bool _isLoading = true;
  final int _page = 1;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  TiebaSubPostModel? _replyTarget;

  @override
  void initState() {
    super.initState();
    _fetchSubPosts();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchSubPosts({bool clear = false}) async {
    if (clear) {
      setState(() => _isLoading = true);
    }
    try {
      final repo = ref.read(detailRepositoryProvider);
      final list = await repo.getFloorReplies(
        threadId: widget.threadId,
        postId: widget.postId,
        page: _page,
      );
      if (mounted) {
        setState(() {
          if (clear) _subPosts.clear();
          _subPosts.addAll(list);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  void _showSubPostActionSheet(TiebaSubPostModel sp, int index) {
    final account = ref.read(authStateProvider).activeAccount;
    final isMyPost = account != null &&
        account.isLogin &&
        ((sp.author.id.isNotEmpty && sp.author.id != '0' && sp.author.id == account.uid) ||
            (sp.author.name.isNotEmpty && sp.author.name == account.name) ||
            (sp.author.portrait.isNotEmpty && account.portrait.isNotEmpty && sp.author.portrait == account.portrait) ||
            (sp.author.displayName.isNotEmpty &&
                (sp.author.displayName == account.nameShow || sp.author.displayName == account.name)));

    final detailState = ref.read(detailControllerFamily(widget.threadId));
    final isUserThreadAuthor = account != null &&
        account.isLogin &&
        detailState.floors.isNotEmpty &&
        detailState.floors.first.floor == 1 &&
        ((detailState.floors.first.author.id.isNotEmpty &&
                detailState.floors.first.author.id != '0' &&
                detailState.floors.first.author.id == account.uid) ||
            (detailState.floors.first.author.name.isNotEmpty &&
                detailState.floors.first.author.name == account.name));

    final canDelete = isMyPost || isUserThreadAuthor;
    final textContent = sp.contentList.map((c) => c.text).join('');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
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
                  title: Text('回复 @${sp.author.displayName}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyTarget = sp;
                    });
                    _focusNode.requestFocus();
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
                    leading: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                    title: Text('删除回复', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await AppDialog.confirm(
                        context,
                        title: '删除回复',
                        content: '确定要删除这条楼中楼回复吗？删除后将无法恢复。',
                        confirmText: '删除',
                        isDanger: true,
                      );
                      if (confirmed == true) {
                        final success = await ref
                            .read(detailControllerFamily(widget.threadId).notifier)
                            .deleteSubPost(
                              subPostId: sp.id,
                              fallbackFid: widget.fallbackFid,
                              fallbackFname: widget.fallbackFname,
                            );
                        if (success && mounted) {
                          setState(() {
                            _subPosts.removeWhere((item) => item.id == sp.id);
                          });
                        }
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

  Future<void> _handleSendSubReply() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final auth = ref.read(authStateProvider);
    if (auth.activeAccount == null || !auth.activeAccount!.isLogin) {
      AppToast.show(context, '请先登录后再发表回复');
      return;
    }

    HapticFeedbackUtil.light();
    FocusScope.of(context).unfocus();

    final targetName = _replyTarget?.author.nameShow.isNotEmpty == true
        ? _replyTarget!.author.nameShow
        : _replyTarget?.author.name;
    final targetPortrait = _replyTarget?.author.portrait;

    final success = await ref.read(detailControllerFamily(widget.threadId).notifier).sendReply(
          content: text,
          postId: widget.postId,
          subPostId: _replyTarget?.id,
          replyUserId: _replyTarget?.author.id,
          replyUserName: targetName,
          replyUserPortrait: targetPortrait,
          fallbackFid: widget.fallbackFid,
          fallbackFname: widget.fallbackFname,
        );

    if (success && mounted) {
      _textController.clear();
      setState(() {
        _replyTarget = null;
      });
      await _fetchSubPosts(clear: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detailState = ref.watch(detailControllerFamily(widget.threadId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.floorNum} 楼的回复 (${_subPosts.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subPosts.isEmpty
                    ? Center(child: Text('暂无更多楼中楼回复', style: TextStyle(color: colorScheme.outline)))
                    : SelectionArea(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _subPosts.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final sp = _subPosts[index];
                            final timeStr = _formatRelativeTime(sp.time);
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onLongPress: () {
                                HapticFeedbackUtil.light();
                                _showSubPostActionSheet(sp, index);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppAvatar(portrait: sp.author.portrait, size: 32, radius: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  sp.author.displayName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (timeStr.isNotEmpty)
                                                Text(
                                                  timeStr,
                                                  style: TextStyle(color: colorScheme.outline, fontSize: 11),
                                                ),
                                              InkWell(
                                                borderRadius: BorderRadius.circular(12),
                                                onTap: () {
                                                  HapticFeedbackUtil.light();
                                                  _showSubPostActionSheet(sp, index);
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 6),
                                                  child: Icon(
                                                    Icons.more_horiz_rounded,
                                                    size: 16,
                                                    color: colorScheme.outline.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          RichText(
                                            text: TextSpan(
                                              children: sp.contentList.map((seg) {
                                                if (seg.type == 4) {
                                                  return TextSpan(
                                                    text: '${seg.text} ',
                                                    style: TextStyle(
                                                      color: colorScheme.primary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  );
                                                }
                                                if (seg.type == 2) {
                                                  return TiebaEmoticonUtil.buildEmoticonSpan(
                                                    text: seg.text,
                                                    c: seg.c,
                                                    cdnUrl: seg.cdnSrc,
                                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                                    size: 18.0,
                                                  );
                                                }
                                                return TextSpan(
                                                  children: TiebaTextParser.parseRichText(
                                                    context,
                                                    seg.text,
                                                    baseStyle: TextStyle(
                                                      color: colorScheme.onSurface,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Bottom Input Bar
          AnimatedPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  if (_replyTarget != null) ...[
                    InputChip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      label: Text(
                        '@${_replyTarget!.author.displayName}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onDeleted: () {
                        setState(() => _replyTarget = null);
                      },
                      deleteIcon: const Icon(Icons.close, size: 14),
                    ),
                    const SizedBox(width: 6),
                  ],
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
                        focusNode: _focusNode,
                        enabled: !detailState.isSubmittingReply,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: detailState.isSubmittingReply
                              ? '正在发送中...'
                              : (_replyTarget != null
                                  ? '回复 @${_replyTarget!.author.displayName}...'
                                  : '回复 ${widget.floorNum} 楼...'),
                          hintStyle: TextStyle(fontSize: 13.5, color: colorScheme.outline),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onSubmitted: (_) {
                          if (!detailState.isSubmittingReply) {
                            _handleSendSubReply();
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    onPressed: detailState.isSubmittingReply ? null : _handleSendSubReply,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

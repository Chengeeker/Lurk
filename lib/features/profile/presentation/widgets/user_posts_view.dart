import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../feed/data/models/tieba_thread_model.dart';
import '../../../feed/presentation/widgets/tieba_card.dart';
import '../../data/profile_repository.dart';
import '../profile_controller.dart';

class UserPostsView extends ConsumerStatefulWidget {
  final TiebaAuthorModel? user;
  const UserPostsView({super.key, this.user});

  @override
  ConsumerState<UserPostsView> createState() => _UserPostsViewState();
}

class _UserPostsViewState extends ConsumerState<UserPostsView> {
  final ScrollController _scrollController = ScrollController();
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );
  List<TiebaThreadModel> _otherUserPosts = [];
  bool _isLoadingOther = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _fetchOtherUserPosts();
    }
  }

  Future<void> _fetchOtherUserPosts() async {
    final uid = widget.user!.id;
    if (uid.isEmpty || uid == '0') return;
    setState(() => _isLoadingOther = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final list = await repo.getUserPosts(uid: uid, page: 1);
      setState(() {
        _otherUserPosts = list;
        _isLoadingOther = false;
      });
    } catch (_) {
      setState(() => _isLoadingOther = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;
    final activeAccount = authState.activeAccount;

    final isTargetUser = widget.user != null;
    final targetDisplayName = isTargetUser
        ? (widget.user!.nameShow.isNotEmpty ? widget.user!.nameShow : (widget.user!.name.isNotEmpty ? widget.user!.name : '贴吧吧友'))
        : (profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : (activeAccount?.nameShow.isNotEmpty == true ? activeAccount!.nameShow : (activeAccount?.name ?? '贴吧用户')));
    final targetPortrait = isTargetUser ? widget.user!.portrait : (profile?.portrait.isNotEmpty == true ? profile!.portrait : (activeAccount?.portrait ?? ''));
    final targetUid = isTargetUser ? widget.user!.id : (activeAccount?.uid ?? '');
    final postsList = isTargetUser ? _otherUserPosts : profileState.userPosts;
    final isPageLoading = isTargetUser ? _isLoadingOther : profileState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTargetUser ? "$targetDisplayName的主页" : '个人主页', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: EasyRefresh(
        controller: _refreshController,
        onRefresh: () async {
          if (isTargetUser) {
            await _fetchOtherUserPosts();
          } else {
            await ref.read(profileControllerProvider.notifier).refresh();
          }
          _refreshController.finishRefresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1), width: 0.8),
                ),
                child: Row(
                  children: [
                    AppAvatar(portrait: targetPortrait, size: 64, radius: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isTargetUser
                                ? 'UID: $targetUid'
                                : '吧龄: ${profile?.tiebaAge ?? 0} 年  •  UID: $targetUid',
                            style: TextStyle(color: colorScheme.outline, fontSize: 12),
                          ),
                          if (!isTargetUser) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('关注 ${profile?.concernNum ?? 0}   ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('粉丝 ${profile?.fansNum ?? 0}   ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('帖子 ${profile?.postNum ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(isTargetUser ? 'TA 的发帖与动态' : '我的发帖与回帖', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            if (postsList.isEmpty && !isPageLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notes_rounded, size: 56, color: colorScheme.outline.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('暂无发帖记录', style: TextStyle(color: colorScheme.outline)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final thread = postsList[index];
                    return TiebaCard(thread: thread);
                  },
                  childCount: postsList.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

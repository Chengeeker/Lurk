import "package:easy_refresh/easy_refresh.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/auth/auth_provider.dart";
import "../../../../core/network/tieba_dio_client.dart";
import "../../../../core/utils/app_toast.dart";
import "../../../../core/utils/haptic_feedback_util.dart";
import "../../../../core/utils/spring_page_route.dart";
import "../../../../core/widgets/app_avatar.dart";
import "../../../feed/data/models/tieba_thread_model.dart";
import "../../data/profile_repository.dart";
import "../user_profile_page.dart";

class FollowUserModel {
  final String id;
  final String name;
  final String nameShow;
  final String portrait;
  final String intro;

  const FollowUserModel({
    required this.id,
    this.name = "",
    this.nameShow = "",
    this.portrait = "",
    this.intro = "",
  });

  String get displayName => nameShow.isNotEmpty ? nameShow : (name.isNotEmpty ? name : "贴吧吧友");

  factory FollowUserModel.fromJson(Map<String, dynamic> json) {
    return FollowUserModel(
      id: json["id"]?.toString() ?? json["user_id"]?.toString() ?? "0",
      name: json["name"]?.toString() ?? "",
      nameShow: json["name_show"]?.toString() ?? json["show_nickname"]?.toString() ?? "",
      portrait: json["portrait"]?.toString() ?? json["portraith"]?.toString() ?? "",
      intro: json["intro"]?.toString() ?? "",
    );
  }
}

class FollowUsersView extends ConsumerStatefulWidget {
  final String? uid;
  const FollowUsersView({super.key, this.uid});

  @override
  ConsumerState<FollowUsersView> createState() => _FollowUsersViewState();
}

class _FollowUsersViewState extends ConsumerState<FollowUsersView> {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );
  List<FollowUserModel> _users = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers(refresh: true);
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    final client = ref.read(tiebaDioClientProvider);
    final auth = ref.read(authStateProvider);
    final targetUid = widget.uid ?? auth.activeAccount?.uid ?? "";

    if (targetUid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final p = refresh ? 1 : _page + 1;
    try {
      final res = await client.post(
        "/c/u/follow/page",
        data: {"uid": targetUid, "pn": p.toString()},
      );
      final data = res.data;
      if (data is Map && data["user_list"] is List) {
        final list = (data["user_list"] as List)
            .map((e) => FollowUserModel.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          if (refresh) {
            _users = list;
            _page = 1;
          } else {
            _users.addAll(list);
            _page = p;
          }
          _hasMore = list.isNotEmpty;
          _isLoading = false;
        });
      } else {
        setState(() {
          if (refresh) _users = [];
          _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmUnfollow(int index) async {
    if (index < 0 || index >= _users.length) return;
    final user = _users[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("取消关注", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text("确定取消关注“${user.displayName}”吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消"),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("取消关注"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = ref.read(authStateProvider);
    final tbs = auth.tbs;
    if (user.portrait.isEmpty) {
      AppToast.show(context, "无法获取用户头像特征码");
      return;
    }

    HapticFeedbackUtil.light();
    final repo = ref.read(profileRepositoryProvider);
    try {
      final success = await repo.unfollowUser(portrait: user.portrait, tbs: tbs);
      if (mounted) {
        if (success) {
          setState(() {
            _users.removeAt(index);
          });
          AppToast.show(context, "已取消关注");
        } else {
          AppToast.show(context, "取消关注失败，请稍后重试");
        }
      }
    } catch (e) {
      if (mounted) AppToast.show(context, "操作失败: $e");
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("关注的吧友", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: EasyRefresh(
        controller: _refreshController,
        onRefresh: () async {
          await _fetchUsers(refresh: true);
          _refreshController.finishRefresh();
        },
        onLoad: () async {
          await _fetchUsers(refresh: false);
          _refreshController.finishLoad(_hasMore ? IndicatorResult.success : IndicatorResult.noMore);
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 56, color: colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text("暂无关注的吧友", style: TextStyle(color: colorScheme.outline, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 0.8),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedbackUtil.light();
                            Navigator.push(
                              context,
                              SpringPageRoute(
                                page: UserProfilePage(
                                  user: TiebaAuthorModel(
                                    id: user.id,
                                    name: user.name,
                                    nameShow: user.nameShow,
                                    portrait: user.portrait,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                AppAvatar(portrait: user.portrait, size: 44, radius: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (user.intro.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          user.intro,
                                          style: TextStyle(color: colorScheme.outline, fontSize: 11.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // 取关操作按钮
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _confirmUnfollow(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_rounded, size: 13, color: colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 2),
                                        Text(
                                          "已关注",
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

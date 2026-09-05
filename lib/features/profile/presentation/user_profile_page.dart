import "package:easy_refresh/easy_refresh.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/auth/auth_provider.dart";
import "../../../core/utils/app_toast.dart";
import "../../../core/utils/haptic_feedback_util.dart";
import "../../../core/utils/spring_page_route.dart";
import "../../../core/widgets/app_avatar.dart";
import "../../auth/presentation/login_page.dart";
import "../../detail/presentation/widgets/image_gallery_page.dart";
import "../../feed/data/models/tieba_thread_model.dart";
import "../../feed/presentation/widgets/tieba_card.dart";
import "../data/models/tieba_profile_model.dart";
import "../data/profile_repository.dart";
import "widgets/follow_users_view.dart";

/// 用户个人主页视图
class UserProfilePage extends ConsumerStatefulWidget {
  final TiebaAuthorModel user;

  const UserProfilePage({super.key, required this.user});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  TiebaProfileModel? _profile;
  List<TiebaThreadModel> _posts = [];
  bool _isLoadingPosts = true;
  int _page = 1;
  bool _hasMore = true;

  bool _isFollowing = false;
  bool _isOperatingFollow = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPosts(refresh: true);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  String get _effectiveUid {
    if (_profile != null && _profile!.id.isNotEmpty && _profile!.id != "0") {
      return _profile!.id;
    }
    return widget.user.id;
  }

  Future<void> _loadProfile() async {
    final uid = _effectiveUid;
    if (uid.isEmpty || uid == "0") return;

    try {
      final repo = ref.read(profileRepositoryProvider);
      final p = await repo.getProfile(uid: uid);
      if (mounted &&
          p != null &&
          (p.name.isNotEmpty || p.nameShow.isNotEmpty)) {
        setState(() {
          _profile = p;
          _isFollowing = p.hasConcerned;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    final uid = _effectiveUid;
    if (uid.isEmpty || uid == "0") {
      setState(() => _isLoadingPosts = false);
      return;
    }

    final p = refresh ? 1 : _page + 1;
    try {
      final repo = ref.read(profileRepositoryProvider);
      final list = await repo.getUserPosts(uid: uid, page: p);
      if (mounted) {
        setState(() {
          if (refresh) {
            _posts = list;
            _page = 1;
          } else {
            _posts.addAll(list);
            _page = p;
          }
          _hasMore = list.isNotEmpty;
          _isLoadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _toggleFollow() async {
    HapticFeedbackUtil.light();
    final authState = ref.read(authStateProvider);
    if (!authState.isLoggedIn) {
      AppToast.show(context, "请先登录百度账号");
      Navigator.push(context, SpringPageRoute(page: const LoginPage()));
      return;
    }

    final tbs = authState.tbs;
    final portrait = (_profile != null && _profile!.portrait.isNotEmpty)
        ? _profile!.portrait
        : widget.user.portrait;

    if (portrait.isEmpty) {
      AppToast.show(context, "无法获取该用户头像标识");
      return;
    }

    setState(() => _isOperatingFollow = true);
    final repo = ref.read(profileRepositoryProvider);

    try {
      final bool success;
      if (_isFollowing) {
        success = await repo.unfollowUser(portrait: portrait, tbs: tbs);
        if (mounted) {
          if (success) {
            setState(() {
              _isFollowing = false;
              _isOperatingFollow = false;
            });
            AppToast.show(context, "已取消关注");
          } else {
            setState(() => _isOperatingFollow = false);
            AppToast.show(context, "取消关注失败，请稍后重试");
          }
        }
      } else {
        success = await repo.followUser(portrait: portrait, tbs: tbs);
        if (mounted) {
          if (success) {
            setState(() {
              _isFollowing = true;
              _isOperatingFollow = false;
            });
            AppToast.show(context, "关注成功");
          } else {
            setState(() => _isOperatingFollow = false);
            AppToast.show(context, "关注失败，请稍后重试");
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOperatingFollow = false);
        AppToast.show(context, "操作失败: $e");
      }
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "Lv.$level",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildFollowButton(ColorScheme colorScheme) {
    if (_isOperatingFollow) {
      return const SizedBox(
        width: 64,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _toggleFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _isFollowing
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          border: _isFollowing
              ? Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isFollowing ? Icons.check_rounded : Icons.add_rounded,
              size: 15,
              color: _isFollowing
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimary,
            ),
            const SizedBox(width: 3),
            Text(
              _isFollowing ? "已关注" : "关注",
              style: TextStyle(
                color: _isFollowing
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);

    // 综合模型兜底：优先使用 Profile，后备使用传入的 User
    final String displayName;
    if (_profile != null &&
        _profile!.displayName.isNotEmpty &&
        _profile!.displayName != "贴吧吧友") {
      displayName = _profile!.displayName;
    } else if (widget.user.displayName.isNotEmpty &&
        widget.user.displayName != "贴吧吧友") {
      displayName = widget.user.displayName;
    } else {
      displayName = _profile?.displayName.isNotEmpty == true
          ? _profile!.displayName
          : widget.user.displayName;
    }

    final String portrait = (_profile != null && _profile!.portrait.isNotEmpty)
        ? _profile!.portrait
        : widget.user.portrait;
    final level = widget.user.level;
    final ip = _profile?.ipAddress.isNotEmpty == true
        ? _profile!.ipAddress
        : widget.user.ipAddress;
    final accountName = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : widget.user.name;
    final uid = _effectiveUid;
    final intro = _profile?.intro ?? "";

    // 自身主页识别：本人不展示关注按钮
    final currentUid = authState.activeAccount?.uid ?? "";
    final isSelf =
        currentUid.isNotEmpty &&
        (uid == currentUid ||
            (accountName.isNotEmpty &&
                accountName == authState.activeAccount?.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: EasyRefresh(
        controller: _refreshController,
        onRefresh: () async {
          await Future.wait([_loadProfile(), _loadPosts(refresh: true)]);
          _refreshController.finishRefresh();
        },
        onLoad: () async {
          await _loadPosts(refresh: false);
          _refreshController.finishLoad(
            _hasMore ? IndicatorResult.success : IndicatorResult.noMore,
          );
        },
        child: CustomScrollView(
          slivers: [
            // 唯一用户主页头部卡片（消除原先的重复二重顶栏与二重简介）
            SliverToBoxAdapter(
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
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
                      // 1. 头像 + 核心信息 + 关注按钮
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (portrait.isNotEmpty) {
                                ImageGalleryPage.open(
                                  context,
                                  images: [portrait],
                                  folderName: displayName,
                                );
                              }
                            },
                            child: AppAvatar(
                              portrait: portrait,
                              size: 68,
                              radius: 34,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (level > 0) ...[
                                      const SizedBox(width: 8),
                                      _buildLevelBadge(level),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (ip.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      "IP 属地：$ip",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                if (accountName.isNotEmpty &&
                                    accountName != displayName)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      "贴吧账号：$accountName",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                if (uid.isNotEmpty && uid != "0")
                                  Text(
                                    "UID: $uid",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isSelf) _buildFollowButton(colorScheme),
                        ],
                      ),

                      // 2. 简介签名
                      if (intro.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          intro,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // 3. 数据统计栏 (关注、粉丝、发帖、吧龄)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              "关注",
                              "${_profile?.concernNum ?? 0}",
                              onTap: isSelf
                                  ? () => Navigator.push(
                                      context,
                                      SpringPageRoute(
                                        page: const FollowUsersView(),
                                      ),
                                    )
                                  : null,
                            ),
                            _buildStatItem("粉丝", "${_profile?.fansNum ?? 0}"),
                            _buildStatItem(
                              "发帖",
                              "${_profile?.postNum ?? _posts.length}",
                            ),
                            if ((_profile?.tiebaAge ?? 0) > 0)
                              _buildStatItem("吧龄", "${_profile!.tiebaAge}年"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 动态分组标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  isSelf ? "我的发帖与动态" : "TA 的发帖与动态",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            // 贴子流或空状态
            if (_posts.isEmpty && !_isLoadingPosts)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 52,
                        color: colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "暂无发帖记录",
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_posts.isEmpty && _isLoadingPosts)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final thread = _posts[index];
                  return TiebaCard(thread: thread);
                }, childCount: _posts.length),
              ),
          ],
        ),
      ),
    );
  }
}

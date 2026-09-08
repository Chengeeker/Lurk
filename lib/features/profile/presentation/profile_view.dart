import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../auth/presentation/login_page.dart';
import '../../settings/presentation/settings_view.dart';
import 'profile_controller.dart';
import 'widgets/bookmarks_view.dart';
import 'widgets/follow_users_view.dart';
import 'widgets/history_view.dart';
import 'widgets/user_posts_view.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});


  void _showFansDialog(BuildContext context, int count) {
    HapticFeedbackUtil.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 36),
        title: const Text('我的粉丝', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('您当前共有 $count 位粉丝关注。', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedbackUtil.light();
              Navigator.pop(context);
            },
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);
    final isLogin = authState.isLogin;
    final activeAccount = authState.activeAccount;
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;

    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (activeAccount?.nameShow.isNotEmpty == true ? activeAccount!.nameShow : (activeAccount?.name ?? ''));
    final portrait = profile?.portrait.isNotEmpty == true
        ? profile!.portrait
        : (activeAccount?.portrait ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: EasyRefresh(
        onRefresh: () async {
          if (isLogin) {
            await ref.read(profileControllerProvider.notifier).refresh();
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // User Header Card (MD3E Container)
            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 0.8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedbackUtil.light();
                  if (isLogin) {
                    Navigator.push(context, SpringPageRoute(page: const UserPostsView()));
                  } else {
                    Navigator.push(context, SpringPageRoute(page: const LoginPage()));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AppAvatar(portrait: portrait, size: 60, radius: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLogin ? (displayName.isNotEmpty ? displayName : '贴吧用户') : '点击登录百度账号',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLogin
                                  ? '吧龄: ${profile?.tiebaAge ?? 0} 年  •  UID: ${activeAccount?.uid ?? ""}'
                                  : '登录后同步关注、粉丝、收藏等数据',
                              style: TextStyle(color: colorScheme.outline, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isLogin ? Icons.chevron_right_rounded : Icons.login_rounded,
                        color: colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // (a) User Stats: 关注数量, 粉丝数量, 回帖数量, 获赞数量 (MD3E Card with Interactive Taps)
            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 0.8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    _buildStatItem(
                      context,
                      count: '${profile?.concernNum ?? 0}',
                      label: '关注',
                      onTap: () {
                        HapticFeedbackUtil.light();
                        if (isLogin) {
                          Navigator.push(context, SpringPageRoute(page: const FollowUsersView()));
                        } else {
                          Navigator.push(context, SpringPageRoute(page: const LoginPage()));
                        }
                      },
                    ),
                    Container(height: 28, width: 0.8, color: theme.dividerColor.withValues(alpha: 0.15)),
                    _buildStatItem(
                      context,
                      count: '${profile?.fansNum ?? 0}',
                      label: '粉丝',
                      onTap: () {
                        _showFansDialog(context, profile?.fansNum ?? 0);
                      },
                    ),
                    Container(height: 28, width: 0.8, color: theme.dividerColor.withValues(alpha: 0.15)),
                    _buildStatItem(
                      context,
                      count: '${profile?.postNum ?? 0}',
                      label: '回帖',
                      onTap: () {
                        HapticFeedbackUtil.light();
                        if (isLogin) {
                          Navigator.push(context, SpringPageRoute(page: const UserPostsView()));
                        } else {
                          Navigator.push(context, SpringPageRoute(page: const LoginPage()));
                        }
                      },
                    ),
                    Container(height: 28, width: 0.8, color: theme.dividerColor.withValues(alpha: 0.15)),
                    _buildStatItem(
                      context,
                      count: '${profile?.agreeNum ?? 0}',
                      label: '获赞',
                      onTap: () {
                        HapticFeedbackUtil.light();
                        AppToast.show(context, '累计获得 ${profile?.agreeNum ?? 0} 个吧友点赞');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // (b) Menu List: 我的收藏, 浏览记录, 设置, 关于 (MD3E Style)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '快捷功能',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ),

            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 0.8),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.bookmark_outline_rounded,
                    iconColor: colorScheme.primary,
                    title: '我的收藏',
                    subtitle: '本地保存与收藏贴子',
                    onTap: () {
                      HapticFeedbackUtil.light();
                      Navigator.push(context, SpringPageRoute(page: const BookmarksView()));
                    },
                  ),
                  Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                  _buildMenuItem(
                    context,
                    icon: Icons.history_rounded,
                    iconColor: colorScheme.primary,
                    title: '浏览记录',
                    subtitle: '查看最近阅读的贴子',
                    onTap: () {
                      HapticFeedbackUtil.light();
                      Navigator.push(context, SpringPageRoute(page: const HistoryView()));
                    },
                  ),
                  Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    iconColor: colorScheme.primary,
                    title: '设置',
                    subtitle: '主题模式、色彩方案、悬浮胶囊底栏与触感反馈',
                    onTap: () {
                      HapticFeedbackUtil.light();
                      Navigator.push(context, SpringPageRoute(page: const SettingsView()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                count,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12.5, color: colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12.5, color: colorScheme.outline)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

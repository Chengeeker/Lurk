import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/account_model.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_dialog.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../auth/presentation/login_page.dart';
import '../../profile/data/profile_repository.dart';
import 'block_settings_page.dart';
import 'habit_settings_page.dart';
import 'personalization_settings_page.dart';
import 'providers/habit_settings_provider.dart';
import 'storage_settings_page.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  Future<String> _appVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return '未知';
    }
  }

  Widget _buildVersionSubtitle(BuildContext context) {
    return FutureBuilder<String>(
      future: _appVersion(),
      builder: (context, snapshot) {
        return Text(
          snapshot.hasData ? '版本 ${snapshot.data}' : '版本读取中…',
          style: const TextStyle(fontSize: 12.5),
        );
      },
    );
  }

  Widget _buildVersionBadge(ColorScheme colorScheme) {
    return FutureBuilder<String>(
      future: _appVersion(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            snapshot.hasData ? 'v${snapshot.data}' : '版本读取中…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutItem(IconData icon, String text, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  void _showExportCredentialsDialog(
    BuildContext context,
    AccountModel account,
  ) {
    HapticFeedbackUtil.light();
    final colorScheme = Theme.of(context).colorScheme;
    final fullCookie =
        "BDUSS=${account.bduss}; ${account.stoken.isNotEmpty ? 'STOKEN=${account.stoken}; ' : ''}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.key_rounded, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "导出登录凭据 / Cookie",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCredentialTile(context, "UID", account.uid),
              const SizedBox(height: 10),
              _buildCredentialTile(context, "BDUSS", account.bduss),
              if (account.stoken.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildCredentialTile(context, "STOKEN", account.stoken),
              ],
              const SizedBox(height: 10),
              _buildCredentialTile(
                context,
                "完整 Cookie",
                fullCookie,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text("一键复制全部凭据"),
                  onPressed: () {
                    HapticFeedbackUtil.light();
                    final exportText =
                        "UID: ${account.uid}\nBDUSS: ${account.bduss}\nSTOKEN: ${account.stoken}\nCookie: $fullCookie";
                    Clipboard.setData(ClipboardData(text: exportText));
                    Navigator.pop(ctx);
                    AppToast.show(context, "全部凭据已复制到剪贴板");
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialTile(
    BuildContext context,
    String label,
    String value, {
    int maxLines = 1,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontFamily: "monospace"),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: "复制$label",
            onPressed: () {
              HapticFeedbackUtil.light();
              Clipboard.setData(ClipboardData(text: value));
              AppToast.show(context, "$label 已复制");
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkCredentialValidity(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    HapticFeedbackUtil.light();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 18),
                Text("正在检测凭据有效性...", style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.getProfile(uid: account.uid);
      if (context.mounted) Navigator.pop(context);

      final isValid =
          profile != null &&
          profile.id.isNotEmpty &&
          profile.id != "0" &&
          (profile.name.isNotEmpty || profile.nameShow.isNotEmpty);

      if (context.mounted) {
        if (isValid) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 48,
              ),
              title: const Text(
                "账号凭据有效",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                "检测通过！当前账号【${profile.displayName}】（账号：${profile.name}，UID：${profile.id}）的 Cookie 与令牌处于有效登录状态。",
                style: const TextStyle(fontSize: 13.5),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("确定"),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(
                Icons.error_outline_rounded,
                color: Colors.orange,
                size: 48,
              ),
              title: const Text(
                "账号凭据可能已失效",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                "未能获取到有效用户信息，当前 Cookie 或访问令牌可能已过期，请尝试重新登录授权。",
                style: TextStyle(fontSize: 13.5),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("我知道了"),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context);
        AppToast.show(context, "检测失败：网络异常或服务无响应");
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    HapticFeedbackUtil.light();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. App Icon
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Centered Title & Version Tag
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Lurk',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                _buildVersionBadge(colorScheme),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '纯原生 Material You 极简社区客户端',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // 3. Feature Highlights
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAboutItem(
                  Icons.palette_outlined,
                  '100% 纯原生 Flutter 与 MD3 动态主题配色',
                  colorScheme,
                ),
                const SizedBox(height: 8),
                _buildAboutItem(
                  Icons.sync_rounded,
                  '原生接口直连、动态板块与社区签到',
                  colorScheme,
                ),
                const SizedBox(height: 8),
                _buildAboutItem(
                  Icons.photo_library_outlined,
                  '自适应九宫格、全高清原图与丰富社区表情',
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // 4. GitHub Project Link
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final uri = Uri.parse('https://github.com/Chengeeker/Lurk');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GitHub 开源地址',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'github.com/Chengeeker/Lurk',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('我知道了'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);
    final habitState = ref.watch(habitSettingsProvider);
    final habitNotifier = ref.read(habitSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '偏好与功能',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '个性化',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '外观风格、主题色彩、字体、屏幕帧率等',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.of(context).push(
                      SpringPageRoute(
                        page: const PersonalizationSettingsPage(),
                      ),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                ListTile(
                  leading: Icon(
                    Icons.block_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '屏蔽设置',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '屏蔽词管理、视频贴过滤、推荐限制',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.of(context)
                        .push(SpringPageRoute(page: const BlockSettingsPage()));
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                ListTile(
                  leading: Icon(Icons.tune_rounded, color: colorScheme.primary),
                  title: const Text(
                    '使用习惯',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '自动加载、手势操作、看图画质偏好',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.of(context)
                        .push(SpringPageRoute(page: const HabitSettingsPage()));
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '存储设置',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '图片与视频存储路径、缓存自动与手动清理',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.of(
                      context,
                    ).push(SpringPageRoute(page: const StorageSettingsPage()));
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.language_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '使用内置浏览器',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '所有链接都将使用内置浏览器打开',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: habitState.useInternalBrowser,
                  onChanged: (val) {
                    habitNotifier.setUseInternalBrowser(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '账号设置',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                if (authState.isLogin) ...[
                  ListTile(
                    leading: Icon(
                      Icons.account_circle_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      authState.activeAccount!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'UID: ${authState.activeAccount!.uid}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        HapticFeedbackUtil.light();
                        final ok = await AppDialog.confirm(
                          context,
                          title: '退出登录',
                          content: '确定要退出当前账号吗？',
                          confirmText: '退出',
                          isDanger: true,
                        );
                        if (ok == true) {
                          ref.read(authStateProvider.notifier).logout();
                        }
                      },
                      child: const Text(
                        '退出登录',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.key_rounded,
                      color: colorScheme.primary,
                    ),
                    title: const Text(
                      '导出登录凭据 / Cookie',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      '查看并导出当前账号 BDUSS 与完整 Cookie',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showExportCredentialsDialog(
                      context,
                      authState.activeAccount!,
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.verified_user_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text(
                      '检测账号凭据有效性',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      '验证当前 Cookie 与访问令牌是否过期有效',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _checkCredentialValidity(
                      context,
                      ref,
                      authState.activeAccount!,
                    ),
                  ),
                ] else
                  ListTile(
                    leading: Icon(
                      Icons.login_rounded,
                      color: colorScheme.primary,
                    ),
                    title: const Text(
                      '登录百度账号',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      '网页快捷授权 / 导入 Cookie 凭据',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      HapticFeedbackUtil.light();
                      Navigator.push(
                        context,
                        SpringPageRoute(page: const LoginPage()),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '关于与支持',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '关于 Lurk',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: _buildVersionSubtitle(context),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

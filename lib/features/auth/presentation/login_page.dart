import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/spring_page_route.dart';
import 'web_login_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _cookieController = TextEditingController();

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  void _onCookieLogin() async {
    final text = _cookieController.text.trim();
    if (text.isEmpty) {
      AppToast.show(context, '请输入 Cookie 或 BDUSS', isError: true);
      return;
    }

    final success = await ref.read(authStateProvider.notifier).loginWithCookieString(text);
    if (!mounted) return;

    if (success) {
      AppToast.show(context, '登录成功！');
      Navigator.pop(context);
    } else {
      AppToast.show(context, '登录失败，请检查 Cookie 有效性', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录百度账号', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Option 1: Official Web Login (Recommended)
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.security_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '官方网页快捷登录',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '支持手机号验证码 / 账号密码 / 扫码登录',
                              style: TextStyle(fontSize: 12, color: colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '安全打开百度官方授权页面，登录成功后自动完成授权并同步账号，无需手动提取 Cookie。',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('打开百度官方登录页', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          SpringPageRoute(page: const WebLoginPage()),
                        );
                        if (res == true && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('或通过 Cookie 导入', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
              ),
              Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 20),

          // Option 2: Cookie Manual Input
          Text(
            'Cookie / BDUSS 导入',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '粘贴完整的百度 Cookie 字符串或单独的 BDUSS 即可完成登录。',
            style: TextStyle(color: colorScheme.outline, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cookieController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '粘贴 BAIDUID=...; BDUSS=...; STOKEN=...',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: authState.isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(authState.isLoading ? '正在验证导入...' : '确认导入并登录'),
            onPressed: authState.isLoading ? null : _onCookieLogin,
          ),
        ],
      ),
    );
  }
}

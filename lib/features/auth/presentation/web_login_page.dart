import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptic_feedback_util.dart';

class WebLoginPage extends ConsumerStatefulWidget {
  const WebLoginPage({super.key});

  @override
  ConsumerState<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends ConsumerState<WebLoginPage> {
  static const _cookieChannel = MethodChannel('com.lurk/cookie_manager');
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessingAuth = false;
  double _progress = 0;
  Timer? _cookiePollTimer;

  static const String _loginUrl =
      'https://wappass.baidu.com/passport?login&u=https%3A%2F%2Ftieba.baidu.com%2Findex%2Ftbwise%2Fmine';

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startCookiePolling();
  }

  @override
  void dispose() {
    _cookiePollTimer?.cancel();
    super.dispose();
  }

  void _startCookiePolling() {
    _cookiePollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkNativeCookies();
    });
  }

  void _initWebView() {
    try {
      _cookieChannel.invokeMethod('clearCookies');
    } catch (_) {}

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _checkNativeCookies();
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _checkNativeCookies();
          },
          onUrlChange: (change) {
            _checkNativeCookies();
          },
        ),
      )
      ..loadRequest(Uri.parse(_loginUrl));
  }

  Future<void> _checkNativeCookies({bool showToastOnFail = false}) async {
    if (_isProcessingAuth) return;

    try {
      String? cookieStr;
      try {
        cookieStr = await _cookieChannel.invokeMethod<String>('getCookies', {'url': 'https://tieba.baidu.com'});
      } catch (_) {}

      // Fallback to JS document.cookie if native channel fails
      if (cookieStr == null || cookieStr.isEmpty || !cookieStr.contains('BDUSS')) {
        try {
          final jsRes = await _controller.runJavaScriptReturningResult('document.cookie');
          final jsStr = jsRes.toString().replaceAll('"', '');
          if (jsStr.contains('BDUSS')) {
            cookieStr = '${cookieStr ?? ''}; $jsStr';
          }
        } catch (_) {}
      }

      if (cookieStr != null && (cookieStr.contains('BDUSS') || cookieStr.contains('BDUSS_BFESS'))) {
        setState(() => _isProcessingAuth = true);
        HapticFeedbackUtil.light();

        final ok = await ref.read(authStateProvider.notifier).loginWithCookieString(cookieStr);
        if (!mounted) return;

        if (ok) {
          _cookiePollTimer?.cancel();
          AppToast.show(context, '登录成功！');
          Navigator.pop(context, true);
        } else {
          setState(() => _isProcessingAuth = false);
          if (showToastOnFail && mounted) {
            AppToast.show(context, '获取到 Cookie 但登录校验未通过，请检查账号状态');
          }
        }
      } else if (showToastOnFail && mounted) {
        AppToast.show(context, '未检测到有效登录 Cookie，请在网页中完成登录');
      }
    } catch (_) {
      if (showToastOnFail && mounted) {
        AppToast.show(context, '读取登录凭据失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('百度账号网页授权', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新加载',
            onPressed: () {
              HapticFeedbackUtil.light();
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && _progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              minHeight: 3,
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('我已登录成功，立即同步授权', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () {
                _checkNativeCookies(showToastOnFail: true);
              },
            ),
          ),
          if (_isProcessingAuth)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          '正在同步账号信息...',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

import "../../features/detail/presentation/thread_detail_page.dart";
import "../../features/feed/data/models/tieba_thread_model.dart";
import "../../features/forum/presentation/forum_view.dart";
import "../storage/storage_service.dart";
import "../utils/app_toast.dart";
import "../utils/haptic_feedback_util.dart";
import "../utils/spring_page_route.dart";
import "../widgets/app_web_view_page.dart";

/// 统一贴吧链接智能路由与深层跳转分发中心
class LinkRoutingService {
  static const MethodChannel _channel = MethodChannel("com.lurk/app");
  static bool _hasInitializedListener = false;

  /// 判断该链接是否为贴吧支持的原生链接
  static bool canHandleNatively(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return false;
    final uri = Uri.tryParse(clean);
    if (uri == null || !_isTiebaHost(uri.host)) return false;

    if (RegExp(r"^/p/[0-9]+(?:/|$)").hasMatch(uri.path)) return true;
    return [uri.queryParameters['kz'], uri.queryParameters['tid']].any(
          (value) => value != null && RegExp(r"^[0-9]+$").hasMatch(value),
        ) ||
        (uri.queryParameters['kw']?.isNotEmpty ?? false);
  }

  static bool _isTiebaHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'tieba.baidu.com' ||
        normalized.endsWith('.tieba.baidu.com') ||
        normalized == 'tiebac.baidu.com' ||
        normalized.endsWith('.tiebac.baidu.com');
  }

  /// 智能解析并打开贴吧链接
  static Future<void> openUrl(
    BuildContext context,
    String rawUrl, {
    bool replaceCurrent = false,
  }) async {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return;
    HapticFeedbackUtil.light();
    final uri = Uri.tryParse(clean);

    // 1. 贴子链接匹配 (/p/{id})
    if (uri != null && _isTiebaHost(uri.host)) {
      final pathMatch = RegExp(r"^/p/([0-9]+)(?:/|$)").firstMatch(uri.path);
      if (pathMatch != null) {
        _openThread(context, pathMatch.group(1)!, replace: replaceCurrent);
        return;
      }

      // 2. 贴子短链/参数匹配 (?kz={id} 或 ?tid={id})
      final threadId = uri.queryParameters['kz'] ?? uri.queryParameters['tid'];
      if (threadId != null && RegExp(r"^[0-9]+$").hasMatch(threadId)) {
        _openThread(context, threadId, replace: replaceCurrent);
        return;
      }

      // 3. 进吧链接匹配 (/f?kw={name})
      final forumName = uri.queryParameters['kw'];
      if (forumName != null && forumName.isNotEmpty) {
        _openForum(context, forumName, replace: replaceCurrent);
        return;
      }
    }

    // 与设置页共用同一 StorageService，避免读取另一份平台偏好存储。
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        !context.mounted) {
      return;
    }
    final storage = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(storageServiceProvider);
    if (storage.getBool(
      StorageService.keyUseInternalBrowser,
      defaultValue: true,
    )) {
      _navigate(
        context,
        AppWebViewPage(url: uri.toString()),
        replace: replaceCurrent,
      );
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        AppToast.show(context, '无法打开链接');
      }
    } catch (_) {
      if (context.mounted) AppToast.show(context, '无法打开链接');
    }
  }

  static void _openThread(
    BuildContext context,
    String threadId, {
    bool replace = false,
  }) {
    final dummyThread = TiebaThreadModel(
      id: threadId,
      title: "贴子详情",
      fname: "",
      contentSnippet: "",
      replyNum: 0,
      agreeNum: 0,
      isAgreed: false,
      isTop: false,
      author: const TiebaAuthorModel(
        id: "0",
        name: "",
        nameShow: "贴吧吧友",
        portrait: "",
      ),
      mediaList: const [],
    );

    _navigate(context, ThreadDetailPage(thread: dummyThread), replace: replace);
  }

  static void _openForum(
    BuildContext context,
    String forumName, {
    bool replace = false,
  }) {
    _navigate(context, ForumView(forumName: forumName), replace: replace);
  }

  static void _navigate(
    BuildContext context,
    Widget targetPage, {
    bool replace = false,
  }) {
    if (!context.mounted) return;
    if (replace) {
      Navigator.of(context).pushReplacement(SpringPageRoute(page: targetPage));
    } else {
      Navigator.of(context).push(SpringPageRoute(page: targetPage));
    }
  }

  /// 全局监听外部 App Links / Intent 唤醒与冷启动
  static void initDeepLinkListener(GlobalKey<NavigatorState> navigatorKey) {
    if (_hasInitializedListener) return;
    _hasInitializedListener = true;

    // 1. 冷启动获取初始 Intent URL
    _channel
        .invokeMethod<String>("getInitialUrl")
        .then((initialUrl) {
          if (initialUrl != null && initialUrl.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navContext = navigatorKey.currentContext;
              if (navContext != null) {
                openUrl(navContext, initialUrl);
              }
            });
          }
        })
        .catchError((_) {});

    // 2. 运行时监听 onDeepLinkOpened 广播
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onDeepLinkOpened") {
        final url = call.arguments?.toString();
        if (url != null && url.isNotEmpty) {
          final navContext = navigatorKey.currentContext;
          if (navContext != null) {
            openUrl(navContext, url);
          }
        }
      }
    });
  }
}

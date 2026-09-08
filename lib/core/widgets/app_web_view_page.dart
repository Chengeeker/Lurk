import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "package:webview_flutter/webview_flutter.dart";
import "../utils/app_toast.dart";
import "../utils/haptic_feedback_util.dart";

class AppWebViewPage extends StatefulWidget {
  final String url;
  final String? title;

  const AppWebViewPage({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<AppWebViewPage> createState() => _AppWebViewPageState();
}

class _AppWebViewPageState extends State<AppWebViewPage> {
  late final WebViewController _controller;
  String _pageTitle = "";
  String _currentUrl = "";
  int _progress = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _pageTitle = widget.title ?? "加载中...";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            final t = await _controller.getTitle();
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = false;
                if (t != null && t.isNotEmpty) {
                  _pageTitle = t;
                }
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _copyCurrentUrl() {
    HapticFeedbackUtil.light();
    Clipboard.setData(ClipboardData(text: _currentUrl));
    AppToast.show(context, "链接已复制到剪贴板");
  }

  void _openInExternalBrowser() async {
    HapticFeedbackUtil.light();
    final uri = Uri.tryParse(_currentUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _pageTitle.isNotEmpty ? _pageTitle : "网页浏览",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _currentUrl,
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "刷新",
              onPressed: () {
                HapticFeedbackUtil.light();
                _controller.reload();
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == "copy") {
                  _copyCurrentUrl();
                } else if (val == "external") {
                  _openInExternalBrowser();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "copy",
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("复制链接"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "external",
                  child: Row(
                    children: [
                      Icon(Icons.open_in_browser_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("在浏览器中打开"),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2.5),
                  child: LinearProgressIndicator(
                    value: _progress / 100.0,
                    minHeight: 2.5,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}

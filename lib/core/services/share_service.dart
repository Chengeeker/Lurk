import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../utils/app_toast.dart";
import "../../features/feed/data/models/tieba_thread_model.dart";

class ShareService {
  ShareService._();

  static const _channel = MethodChannel("com.lurk/app");

  static Future<void> shareThread(BuildContext context, TiebaThreadModel thread) async {
    final title = thread.title.isNotEmpty
        ? thread.title
        : (thread.contentSnippet.isNotEmpty ? thread.contentSnippet : "贴吧贴子");
    final url = "https://tieba.baidu.com/p/${thread.id}";
    final shareText = "$title\n$url";

    try {
      await _channel.invokeMethod("shareText", {
        "text": shareText,
        "title": title,
      });
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (context.mounted) {
        AppToast.show(context, "贴子链接已复制到剪贴板");
      }
    }
  }
}

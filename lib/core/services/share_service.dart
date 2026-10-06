import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../utils/app_toast.dart";
import "../../features/feed/data/models/tieba_thread_model.dart";

class ShareService {
  ShareService._();

  static const _channel = MethodChannel("com.lurk/app");

  static Future<void> shareThread(
    BuildContext context,
    TiebaThreadModel thread,
  ) async {
    final title = thread.title.isNotEmpty
        ? thread.title
        : (thread.contentSnippet.isNotEmpty ? thread.contentSnippet : "贴吧贴子");
    final url = "https://tieba.baidu.com/p/${thread.id}";
    final shareText = "$title\n$url";

    await shareTextContent(
      context,
      text: shareText,
      title: title,
      fallbackMessage: "贴子链接已复制到剪贴板",
    );
  }

  static Future<void> shareTextContent(
    BuildContext context, {
    required String text,
    required String title,
    required String fallbackMessage,
  }) async {
    try {
      await _channel.invokeMethod("shareText", {"text": text, "title": title});
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        AppToast.show(context, fallbackMessage);
      }
    }
  }
}

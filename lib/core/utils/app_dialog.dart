import 'package:flutter/material.dart';

class AppDialog {
  AppDialog._();

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(content, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText, style: TextStyle(color: colorScheme.outline)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? colorScheme.error : colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText, style: TextStyle(color: isDanger ? colorScheme.onError : colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }
}

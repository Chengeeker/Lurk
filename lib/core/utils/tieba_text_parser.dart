import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tieba_emojis.dart';
import 'tieba_emoticon_util.dart';

class TiebaTextParser {
  TiebaTextParser._();

  static List<InlineSpan> parseRichText(
    BuildContext context,
    String rawText, {
    TextStyle? baseStyle,
    Color? linkColor,
    void Function(String userName)? onUserTap,
    void Function(String topic)? onTopicTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = linkColor ?? colorScheme.primary;

    final List<InlineSpan> spans = [];
    if (rawText.isEmpty) return spans;

    final regex = RegExp(
      r'(@[a-zA-Z0-9_\u4e00-\u9fa5]+)|(#[^#\n]+#)|(https?:\/\/[^\s]+)|(#\([a-zA-Z0-9_\u4e00-\u9fa5~,]+\))|(\[[a-zA-Z0-9_\u4e00-\u9fa5~]+\])|(image_emoticon\d*)|(image\s+emoticon\s*\d*)',
      caseSensitive: false,
    );

    int lastIndex = 0;
    for (final match in regex.allMatches(rawText)) {
      if (match.start > lastIndex) {
        final textChunk = rawText.substring(lastIndex, match.start);
        spans.add(TextSpan(text: textChunk, style: baseStyle));
      }

      final matchedStr = match.group(0)!;

      if (matchedStr.startsWith('@')) {
        final userName = matchedStr.substring(1);
        spans.add(
          TextSpan(
            text: matchedStr,
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onUserTap != null) onUserTap(userName);
              },
          ),
        );
      } else if (matchedStr.startsWith('#') && matchedStr.endsWith('#') && matchedStr.length > 2) {
        final topic = matchedStr.substring(1, matchedStr.length - 1);
        spans.add(
          TextSpan(
            text: matchedStr,
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onTopicTap != null) onTopicTap(topic);
              },
          ),
        );
      } else if (matchedStr.startsWith('http')) {
        spans.add(
          TextSpan(
            text: '网页链接 🔗',
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.tryParse(matchedStr);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
      } else if (TiebaEmoticonUtil.hasEmoticon(matchedStr)) {
        final fontSize = baseStyle?.fontSize ?? 15.0;
        spans.add(
          TiebaEmoticonUtil.buildEmoticonSpan(
            text: matchedStr,
            style: baseStyle,
            size: (fontSize * 1.35).clamp(18.0, 24.0),
          ),
        );
      } else if (matchedStr.startsWith('#(') && matchedStr.endsWith(')')) {
        final emojiSymbol = TiebaEmojis.emojiMap[matchedStr];
        spans.add(
          TextSpan(
            text: emojiSymbol ?? matchedStr,
            style: baseStyle,
          ),
        );
      } else if (matchedStr.toLowerCase().contains('emoticon')) {
        spans.add(
          TiebaEmoticonUtil.buildEmoticonSpan(
            text: matchedStr,
            style: baseStyle,
          ),
        );
      } else {
        spans.add(TextSpan(text: matchedStr, style: baseStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < rawText.length) {
      spans.add(TextSpan(text: rawText.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }
}

import 'tieba_emoticon_util.dart';

/// Converts the small HTML fragments returned by the official mobile APIs into
/// safe inline text tokens used by the Flutter rich-text renderer.
class TiebaHtmlParser {
  TiebaHtmlParser._();

  static final RegExp _imageTag = RegExp(r'<img\b[^>]*>', caseSensitive: false);
  static final RegExp _scriptOrStyle = RegExp(
    r'<(script|style)\b[^>]*>.*?</\1\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _lineBreakTag = RegExp(
    r'<\s*(br|/p|/div|/li|/tr|/h[1-6])\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _tag = RegExp(r'<[^>]+>', caseSensitive: false);
  static final RegExp _attribute = RegExp(
    r'''(?:src|data-src|data-original|alt|title|data-name)\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );

  static String toPlainText(String raw) {
    if (raw.isEmpty || !raw.contains('<')) {
      return _decodeEntities(raw).trim();
    }

    var text = raw.replaceAll(_scriptOrStyle, '');
    text = text.replaceAllMapped(_imageTag, (match) {
      return _imageToken(match.group(0)!);
    });
    text = text.replaceAll(_lineBreakTag, '\n');
    text = text.replaceAll(_tag, '');
    text = _decodeEntities(text);
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String _imageToken(String tag) {
    final attributes = _attribute
        .allMatches(tag)
        .map((match) {
          return match.group(1)?.trim() ?? '';
        })
        .where((value) => value.isNotEmpty)
        .toList();

    for (final value in attributes) {
      final emoticon = RegExp(
        r'image[_ ]emoticon\s*[-_ ]?(\d+)',
        caseSensitive: false,
      ).firstMatch(value);
      if (emoticon != null) {
        return TiebaEmoticonUtil.getEmoticonName(
          'image_emoticon${emoticon.group(1)}',
        );
      }
      if (TiebaEmoticonUtil.hasEmoticon(value)) {
        return TiebaEmoticonUtil.getEmoticonName(value);
      }
    }

    return '[图片]';
  }

  static String _decodeEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#x([0-9a-f]+);?', caseSensitive: false), (
          match,
        ) {
          final codePoint = int.tryParse(match.group(1)!, radix: 16);
          return codePoint == null
              ? match.group(0)!
              : String.fromCharCode(codePoint);
        })
        .replaceAllMapped(RegExp(r'&#(\d+);?'), (match) {
          final codePoint = int.tryParse(match.group(1)!);
          return codePoint == null
              ? match.group(0)!
              : String.fromCharCode(codePoint);
        });
  }
}

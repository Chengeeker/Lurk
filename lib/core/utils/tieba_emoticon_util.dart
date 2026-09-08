import "package:extended_image/extended_image.dart";
import "package:flutter/material.dart";
import "../constants/tieba_constants.dart";

class TiebaEmoticonUtil {
  TiebaEmoticonUtil._();

  static const Map<String, String> emoticonNames = {
    "image_emoticon1": "[呵呵]",
    "image_emoticon2": "[哈哈]",
    "image_emoticon3": "[吐舌]",
    "image_emoticon4": "[啊]",
    "image_emoticon5": "[酷]",
    "image_emoticon6": "[怒]",
    "image_emoticon7": "[开心]",
    "image_emoticon8": "[汗]",
    "image_emoticon9": "[泪]",
    "image_emoticon10": "[黑线]",
    "image_emoticon11": "[鄙视]",
    "image_emoticon12": "[不高兴]",
    "image_emoticon13": "[真棒]",
    "image_emoticon14": "[钱]",
    "image_emoticon15": "[疑问]",
    "image_emoticon16": "[阴险]",
    "image_emoticon17": "[吐]",
    "image_emoticon18": "[咦]",
    "image_emoticon19": "[委屈]",
    "image_emoticon20": "[花心]",
    "image_emoticon21": "[呼~]",
    "image_emoticon22": "[笑眼]",
    "image_emoticon23": "[冷]",
    "image_emoticon24": "[太开心]",
    "image_emoticon25": "[滑稽]",
    "image_emoticon26": "[勉强]",
    "image_emoticon27": "[狂汗]",
    "image_emoticon28": "[乖]",
    "image_emoticon29": "[睡觉]",
    "image_emoticon30": "[惊哭]",
    "image_emoticon31": "[生气]",
    "image_emoticon32": "[惊讶]",
    "image_emoticon33": "[喷]",
    "image_emoticon34": "[爱心]",
    "image_emoticon35": "[心碎]",
    "image_emoticon36": "[玫瑰]",
    "image_emoticon37": "[礼物]",
    "image_emoticon38": "[彩虹]",
    "image_emoticon39": "[星星月亮]",
    "image_emoticon40": "[太阳]",
    "image_emoticon41": "[钱币]",
    "image_emoticon42": "[灯泡]",
    "image_emoticon43": "[茶杯]",
    "image_emoticon44": "[蛋糕]",
    "image_emoticon45": "[音乐]",
    "image_emoticon46": "[haha]",
    "image_emoticon47": "[胜利]",
    "image_emoticon48": "[大拇指]",
    "image_emoticon49": "[弱]",
    "image_emoticon50": "[OK]",
    "image_emoticon61": "[生气]",
    "image_emoticon77": "[沙发]",
    "image_emoticon78": "[手纸]",
    "image_emoticon79": "[香蕉]",
    "image_emoticon80": "[便便]",
    "image_emoticon81": "[药丸]",
    "image_emoticon82": "[红领巾]",
    "image_emoticon83": "[蜡烛]",
    "image_emoticon84": "[三道杠]",
  };

  static final Map<String, int> nameToId = {
    "呵呵": 1,
    "哈哈": 2,
    "吐舌": 3,
    "啊": 4,
    "酷": 5,
    "怒": 6,
    "开心": 7,
    "汗": 8,
    "泪": 9,
    "黑线": 10,
    "鄙视": 11,
    "不高兴": 12,
    "真棒": 13,
    "钱": 14,
    "疑问": 15,
    "阴险": 16,
    "吐": 17,
    "咦": 18,
    "委屈": 19,
    "花心": 20,
    "呼~": 21,
    "笑眼": 22,
    "冷": 23,
    "太开心": 24,
    "滑稽": 25,
    "勉强": 26,
    "狂汗": 27,
    "乖": 28,
    "睡觉": 29,
    "惊哭": 30,
    "生气": 31,
    "惊讶": 32,
    "喷": 33,
    "爱心": 34,
    "心碎": 35,
    "玫瑰": 36,
    "礼物": 37,
    "彩虹": 38,
    "星星月亮": 39,
    "太阳": 40,
    "钱币": 41,
    "灯泡": 42,
    "茶杯": 43,
    "蛋糕": 44,
    "音乐": 45,
    "haha": 46,
    "胜利": 47,
    "大拇指": 48,
    "弱": 49,
    "OK": 50,
    "沙发": 77,
    "手纸": 78,
    "香蕉": 79,
    "便便": 80,
    "药丸": 81,
    "红领巾": 82,
    "蜡烛": 83,
    "三道杠": 84,
  };

  static final Map<String, int> codeToId = {
    "smile": 1,
    "laugh": 2,
    "tongue": 3,
    "cool": 5,
    "angry": 6,
    "happy": 7,
    "sweat": 8,
    "cry": 9,
    "question": 15,
    "huaji": 25,
    "sleep": 29,
    "heart": 34,
    "broken_heart": 35,
    "rose": 36,
    "gift": 37,
    "sun": 40,
    "thumbsup": 48,
    "thumbsdown": 49,
    "ok": 50,
  };

  static bool hasEmoticon(String raw) {
    var clean = raw.trim();
    if (clean.startsWith("[") && clean.endsWith("]")) {
      clean = clean.substring(1, clean.length - 1);
    } else if (clean.startsWith("#(") && clean.endsWith(")")) {
      clean = clean.substring(2, clean.length - 1);
    }
    return nameToId.containsKey(clean) ||
        codeToId.containsKey(clean.toLowerCase()) ||
        clean.toLowerCase().startsWith("image_emoticon");
  }

  static String getEmoticonName(String key) {
    var cleanKey = key.trim();
    if (cleanKey.startsWith("[") && cleanKey.endsWith("]")) {
      return cleanKey;
    }
    if (cleanKey.startsWith("#(") && cleanKey.endsWith(")")) {
      cleanKey = cleanKey.substring(2, cleanKey.length - 1);
    }
    final normalized = cleanKey.replaceAll(" ", "_").toLowerCase();
    if (emoticonNames.containsKey(normalized)) {
      return emoticonNames[normalized]!;
    }
    if (nameToId.containsKey(cleanKey)) {
      return "[$cleanKey]";
    }
    return "[表情]";
  }

  static String getEmoticonUrl([String? text, String? c, String? cdnUrl]) {
    if (cdnUrl != null && cdnUrl.isNotEmpty) {
      if (cdnUrl.startsWith("http://")) return "https://${cdnUrl.substring(7)}";
      return cdnUrl;
    }

    // 1. 优先根据 c 字段 (贴吧官方语义名称，如 "呵呵", "滑稽", "[呵呵]") 解析
    if (c != null && c.trim().isNotEmpty) {
      var name = c.trim();
      if (name.startsWith("[") && name.endsWith("]")) {
        name = name.substring(1, name.length - 1);
      } else if (name.startsWith("#(") && name.endsWith(")")) {
        name = name.substring(2, name.length - 1);
      }
      final id = nameToId[name] ?? codeToId[name.toLowerCase()];
      if (id != null) {
        return "https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon$id.png";
      }
    }

    // 2. 根据 text 字段提取数字 (如 "image_emoticon1", "image_emoticon25")
    final key = (text ?? "").trim();
    final reg = RegExp(r"\d+");
    final match = reg.firstMatch(key);
    if (match != null) {
      final num = match.group(0);
      return "https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon$num.png";
    }

    // 3. 根据 text 字段名称解析 (如 "#(呵呵)", "[滑稽]")
    var cleanKey = key;
    if (cleanKey.startsWith("[") && cleanKey.endsWith("]")) {
      cleanKey = cleanKey.substring(1, cleanKey.length - 1);
    } else if (cleanKey.startsWith("#(") && cleanKey.endsWith(")")) {
      cleanKey = cleanKey.substring(2, cleanKey.length - 1);
    }
    final id = nameToId[cleanKey] ?? codeToId[cleanKey.toLowerCase()];
    if (id != null) {
      return "https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon$id.png";
    }

    // 默认兜底为 1 号经典微笑 [呵呵]
    return "https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon1.png";
  }

  static InlineSpan buildEmoticonSpan({
    required String text,
    String? c,
    String? cdnUrl,
    TextStyle? style,
    double size = 20.0,
  }) {
    final url = getEmoticonUrl(text, c, cdnUrl);
    final name = getEmoticonName(c ?? text);

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: ExtendedImage.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cache: true,
          headers: {"User-Agent": TiebaConstants.defaultUserAgent},
          loadStateChanged: (state) {
            if (state.extendedImageLoadState == LoadState.failed) {
              return Text(name, style: style);
            }
            return null;
          },
        ),
      ),
    );
  }
}


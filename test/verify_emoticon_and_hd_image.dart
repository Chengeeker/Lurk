// ignore_for_file: avoid_print
import "package:flutter_test/flutter_test.dart";
import "package:lurk/core/utils/tieba_emoticon_util.dart";
import "package:lurk/core/widgets/app_network_image.dart";
import "package:lurk/features/feed/data/models/tieba_thread_model.dart";

void main() {
  group("Tieba Emoticon and HD Images", () {
    test("TiebaEmoticonUtil resolves image_emoticon25 to [滑稽] and proper cdn url", () {
      final name = TiebaEmoticonUtil.getEmoticonName("image_emoticon25");
      expect(name, "[滑稽]");

      final url = TiebaEmoticonUtil.getEmoticonUrl("image_emoticon25");
      expect(url, "https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon25.png");

      final fallbackName = TiebaEmoticonUtil.getEmoticonName("image emoticon");
      expect(fallbackName, "[表情]");
    });

    test("AppNetworkImage.safeUrl converts http to https and handles empty strings", () {
      expect(AppNetworkImage.safeUrl("http://imgsrc.baidu.com/1.jpg"), "https://imgsrc.baidu.com/1.jpg");
      expect(AppNetworkImage.safeUrl("https://tiebapic.baidu.com/2.jpg"), "https://tiebapic.baidu.com/2.jpg");
      expect(AppNetworkImage.safeUrl("   "), "");
    });

    test("TiebaMediaModel prioritizes origin_pic and big_pic for ultra HD display", () {
      final json = {
        "origin_pic": "http://tiebapic.baidu.com/forum/pic/item/original.jpg?tbpicau=123",
        "big_pic": "http://tiebapic.baidu.com/forum/w%3D960/big.jpg?tbpicau=123",
        "small_pic": "http://tiebapic.baidu.com/forum/w%3D200/small.jpg",
      };

      final media = TiebaMediaModel.fromJson(json);
      expect(media.originUrl, "http://tiebapic.baidu.com/forum/pic/item/original.jpg?tbpicau=123");
      expect(media.bigCdnUrl, "http://tiebapic.baidu.com/forum/w%3D960/big.jpg?tbpicau=123");
      expect(media.thumbUrl, "http://tiebapic.baidu.com/forum/w%3D200/small.jpg");
    });
  });
}

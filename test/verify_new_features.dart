import "package:flutter_test/flutter_test.dart";
import "package:lurk/features/my_forums/data/models/followed_forum_model.dart";
import "package:lurk/core/services/link_routing_service.dart";
import "package:lurk/features/detail/data/models/tieba_post_model.dart";
import "package:lurk/features/feed/data/models/tieba_thread_model.dart";

void main() {
  test("TiebaAuthorModel correctly parses level and ipAddress", () {
    final authorJson = {
      "id": "12345",
      "name": "念言温玉",
      "name_show": "念言温玉",
      "level_id": "11",
      "ip_address": "河北",
    };
    final author = TiebaAuthorModel.fromJson(authorJson);
    expect(author.displayName, "念言温玉");
    expect(author.level, 11);
    expect(author.ipAddress, "河北");
  });

  test("FollowedForumModel accurately parses is_sign_in status", () {
    final signedMap1 = {
      "id": "1",
      "name": "原神",
      "user_level": "11",
      "is_sign_in": 1,
    };
    final f1 = FollowedForumModel.fromJson(signedMap1);
    expect(f1.isSigned, true);
    expect(f1.userLevel, 11);

    final signedMap2 = {
      "id": "2",
      "name": "华南农业大学",
      "user_level": "11",
      "is_sign_in": "1",
    };
    final f2 = FollowedForumModel.fromJson(signedMap2);
    expect(f2.isSigned, true);

    final unsignedMap = {
      "id": "3",
      "name": "孙笑川",
      "user_level": "10",
      "is_sign_in": 0,
    };
    final f3 = FollowedForumModel.fromJson(unsignedMap);
    expect(f3.isSigned, false);

    final unsignedMap2 = {
      "id": "4",
      "name": "尘白禁区",
      "user_level": "10",
      "is_sign_in": "0",
    };
    final f4 = FollowedForumModel.fromJson(unsignedMap2);
    expect(f4.isSigned, false);
  });

  test(
    "LinkRoutingService correctly identifies and parses tieba.baidu.com links",
    () {
      expect(
        LinkRoutingService.canHandleNatively(
          "https://tieba.baidu.com/p/8971234567",
        ),
        true,
      );
      expect(
        LinkRoutingService.canHandleNatively(
          "http://c.tieba.baidu.com/p/8971234567",
        ),
        true,
      );
      expect(
        LinkRoutingService.canHandleNatively(
          "https://tiebac.baidu.com/p/8971234567",
        ),
        true,
      );
      expect(
        LinkRoutingService.canHandleNatively(
          "https://tieba.baidu.com/f?kw=%E5%8E%9F%E7%A5%9E",
        ),
        true,
      );
      expect(
        LinkRoutingService.canHandleNatively(
          "https://tieba.baidu.com/mo/q/m?kz=123456",
        ),
        true,
      );
      expect(LinkRoutingService.canHandleNatively("https://google.com"), false);
      expect(
        LinkRoutingService.canHandleNatively(
          "https://evil.example/?tid=123456",
        ),
        false,
      );
      expect(
        LinkRoutingService.canHandleNatively(
          "https://tieba.baidu.com.evil.example/p/123456",
        ),
        false,
      );
    },
  );

  test(
    "CommentSortType hot sorting ranks higher agree and subpost counts first",
    () {
      const author = TiebaAuthorModel(
        id: "1",
        name: "UserA",
        level: 2,
        ipAddress: "甘肃",
      );
      const f1 = TiebaFloorModel(
        id: "101",
        floor: 2,
        author: author,
        contentList: [],
        agreeNum: 5,
        subPostCount: 1,
      );
      const f2 = TiebaFloorModel(
        id: "102",
        floor: 3,
        author: author,
        contentList: [],
        agreeNum: 50,
        subPostCount: 10,
      );
      const f3 = TiebaFloorModel(
        id: "103",
        floor: 4,
        author: author,
        contentList: [],
        agreeNum: 1,
        subPostCount: 0,
      );

      final list = [f1, f2, f3];
      list.sort(
        (a, b) => (b.agreeNum + b.subPostCount * 2).compareTo(
          a.agreeNum + a.subPostCount * 2,
        ),
      );

      expect(list.first.id, "102");
      expect(list.last.id, "103");
    },
  );
}

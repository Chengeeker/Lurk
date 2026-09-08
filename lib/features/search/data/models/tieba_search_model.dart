import "../../../feed/data/models/tieba_thread_model.dart";

class TiebaSearchResultModel {
  final String id;
  final String postId;
  final String title;
  final String content;
  final String fname;
  final String authorId;
  final String authorName;
  final String authorNameShow;
  final String authorPortrait;
  final int replyNum;
  final int time;
  final bool isReply;
  final List<TiebaMediaModel> mediaList;

  const TiebaSearchResultModel({
    required this.id,
    this.postId = "",
    required this.title,
    this.content = "",
    this.fname = "",
    this.authorId = "0",
    this.authorName = "",
    this.authorNameShow = "",
    this.authorPortrait = "",
    this.replyNum = 0,
    this.time = 0,
    this.isReply = false,
    this.mediaList = const [],
  });

  TiebaSearchResultModel copyWith({
    String? id,
    String? postId,
    String? title,
    String? content,
    String? fname,
    String? authorId,
    String? authorName,
    String? authorNameShow,
    String? authorPortrait,
    int? replyNum,
    int? time,
    bool? isReply,
    List<TiebaMediaModel>? mediaList,
  }) {
    return TiebaSearchResultModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      title: title ?? this.title,
      content: content ?? this.content,
      fname: fname ?? this.fname,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorNameShow: authorNameShow ?? this.authorNameShow,
      authorPortrait: authorPortrait ?? this.authorPortrait,
      replyNum: replyNum ?? this.replyNum,
      time: time ?? this.time,
      isReply: isReply ?? this.isReply,
      mediaList: mediaList ?? this.mediaList,
    );
  }

  factory TiebaSearchResultModel.fromJson(Map<String, dynamic> json) {
    String aName = "";
    String aShow = "";
    String aPort = "";
    String aId = "0";

    final rawAuthor = json["author"];
    if (rawAuthor is Map) {
      aName = rawAuthor["name"]?.toString() ?? "";
      aShow = rawAuthor["name_show"]?.toString() ??
          rawAuthor["show_nickname"]?.toString() ??
          rawAuthor["nick_name"]?.toString() ??
          aName;
      aPort = rawAuthor["portrait"]?.toString() ??
          rawAuthor["portraith"]?.toString() ??
          rawAuthor["icon"]?.toString() ??
          rawAuthor["avatar"]?.toString() ??
          "";
      aId = rawAuthor["id"]?.toString() ??
          rawAuthor["user_id"]?.toString() ??
          "0";
    } else if (rawAuthor is String) {
      aName = rawAuthor;
      aShow = aName;
    }

    final rawContent = json["content"];
    String parsedContent = "";
    if (rawContent is String) {
      parsedContent = rawContent;
    } else if (rawContent is List) {
      parsedContent = rawContent
          .map((e) => e is Map ? (e["text"]?.toString() ?? "") : e.toString())
          .join("");
    }

    final List<TiebaMediaModel> mList = [];
    if (json["media"] is List) {
      for (var m in json["media"]) {
        if (m is Map) {
          mList.add(TiebaMediaModel.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }

    return TiebaSearchResultModel(
      id: json["tid"]?.toString() ?? json["id"]?.toString() ?? "",
      postId: json["pid"]?.toString() ?? "",
      title: json["title"]?.toString() ?? "",
      content: parsedContent,
      fname: json["fname"]?.toString() ?? json["forum_name"]?.toString() ?? "",
      authorId: aId,
      authorName: aName,
      authorNameShow: aShow,
      authorPortrait: aPort,
      replyNum: int.tryParse(json["reply_num"]?.toString() ?? "0") ?? 0,
      time: int.tryParse(json["time"]?.toString() ?? "0") ?? 0,
      isReply: json["is_replay"]?.toString() == "1" || json["is_floor"]?.toString() == "1",
      mediaList: mList,
    );
  }

  TiebaThreadModel toThreadModel() {
    return TiebaThreadModel(
      id: id,
      title: title.isNotEmpty ? title : (content.isNotEmpty ? content : "贴吧贴子"),
      contentSnippet: content,
      fname: fname,
      createTime: time,
      replyNum: replyNum,
      mediaList: mediaList,
      author: TiebaAuthorModel(
        id: authorId,
        name: authorName,
        nameShow: authorNameShow.isNotEmpty ? authorNameShow : authorName,
        portrait: authorPortrait,
      ),
    );
  }
}

/// 搜吧条目模型
class SearchForumItem {
  final String forumId;
  final String forumName;
  final String forumNameShow;
  final String avatar;
  final String slogan;
  final String postNum;
  final String concernNum;
  final bool hasConcerned;
  final bool isOfficial;

  const SearchForumItem({
    required this.forumId,
    required this.forumName,
    this.forumNameShow = "",
    this.avatar = "",
    this.slogan = "",
    this.postNum = "0",
    this.concernNum = "0",
    this.hasConcerned = false,
    this.isOfficial = false,
  });

  factory SearchForumItem.fromJson(Map<String, dynamic> json) {
    return SearchForumItem(
      forumId: json["forum_id"]?.toString() ?? json["id"]?.toString() ?? "",
      forumName: json["forum_name"]?.toString() ?? json["name"]?.toString() ?? "",
      forumNameShow: json["forum_name_show"]?.toString() ?? json["forum_name"]?.toString() ?? "",
      avatar: json["avatar"]?.toString() ?? "",
      slogan: json["slogan"]?.toString() ?? json["intro"]?.toString() ?? "",
      postNum: json["post_num"]?.toString() ?? "0",
      concernNum: json["concern_num"]?.toString() ?? "0",
      hasConcerned: json["has_concerned"] == 1 || json["has_concerned"] == "1",
      isOfficial: json["is_official_forum"] == 1 || json["is_official_forum"] == "1",
    );
  }
}

/// 搜吧结果全集
class SearchForumResultModel {
  final SearchForumItem? exactMatch;
  final List<SearchForumItem> fuzzyMatch;

  const SearchForumResultModel({
    this.exactMatch,
    this.fuzzyMatch = const [],
  });

  bool get isEmpty => exactMatch == null && fuzzyMatch.isEmpty;
}

/// 搜人条目模型
class SearchUserItem {
  final String id;
  final String name;
  final String showNickname;
  final String portrait;
  final String intro;
  final int fansNum;
  final bool hasConcerned;
  final bool isExact;

  const SearchUserItem({
    required this.id,
    required this.name,
    this.showNickname = "",
    this.portrait = "",
    this.intro = "",
    this.fansNum = 0,
    this.hasConcerned = false,
    this.isExact = false,
  });

  String get displayName => showNickname.isNotEmpty ? showNickname : (name.isNotEmpty ? name : "贴吧吧友");

  factory SearchUserItem.fromJson(Map<String, dynamic> json) {
    return SearchUserItem(
      id: json["id"]?.toString() ?? json["user_id"]?.toString() ?? "0",
      name: json["name"]?.toString() ?? json["user_name"]?.toString() ?? "",
      showNickname: json["show_nickname"]?.toString() ?? json["user_nickname"]?.toString() ?? json["name_show"]?.toString() ?? "",
      portrait: json["portrait"]?.toString() ?? json["portraith"]?.toString() ?? "",
      intro: json["intro"]?.toString() ?? "",
      fansNum: int.tryParse(json["fans_num"]?.toString() ?? "0") ?? 0,
      hasConcerned: json["has_concerned"] == 1 || json["has_concerned"] == "1",
      isExact: json["is_exact"] == 1 || json["is_exact"] == "1",
    );
  }

  TiebaAuthorModel toAuthorModel() {
    return TiebaAuthorModel(
      id: id,
      name: name,
      nameShow: showNickname.isNotEmpty ? showNickname : name,
      portrait: portrait,
    );
  }
}

/// 搜人结果全集
class SearchUserResultModel {
  final SearchUserItem? exactMatch;
  final List<SearchUserItem> fuzzyMatch;

  const SearchUserResultModel({
    this.exactMatch,
    this.fuzzyMatch = const [],
  });

  bool get isEmpty => exactMatch == null && fuzzyMatch.isEmpty;
}

import '../../../feed/data/models/tieba_thread_model.dart';

class PostContentSegment {
  final int type; // 0: text, 1: link, 2: emoji/sticker, 3: image, 4: at-user, 5: video
  final String text;
  final String? c; // emoticon name, e.g. "呵呵", "滑稽"
  final String? url;
  final String? cdnSrc;
  final String? bigCdnSrc;
  final String? originSrc;
  final String? uid;

  const PostContentSegment({
    required this.type,
    required this.text,
    this.c,
    this.url,
    this.cdnSrc,
    this.bigCdnSrc,
    this.originSrc,
    this.uid,
  });

  factory PostContentSegment.fromJson(Map<String, dynamic> json) {
    final type = int.tryParse(json['type']?.toString() ?? '0') ?? 0;
    final origin = json['origin_pic']?.toString() ??
        json['origin_src']?.toString() ??
        json['big_pic']?.toString() ??
        '';
    final big = json['big_pic']?.toString() ??
        json['big_cdn_src']?.toString() ??
        origin;
    final cdn = json['cdn_src']?.toString() ?? json['src']?.toString();
    final cVal = json['c']?.toString();
    final textVal = json['text']?.toString() ?? cVal ?? '';

    return PostContentSegment(
      type: type,
      text: textVal,
      c: cVal,
      url: json['link']?.toString() ?? json['url']?.toString(),
      cdnSrc: cdn,
      bigCdnSrc: big.isNotEmpty ? big : null,
      originSrc: origin.isNotEmpty ? origin : null,
      uid: json['uid']?.toString(),
    );
  }
}

class TiebaSubPostModel {
  final String id;
  final TiebaAuthorModel author;
  final List<PostContentSegment> contentList;
  final int time;

  const TiebaSubPostModel({
    required this.id,
    required this.author,
    required this.contentList,
    this.time = 0,
  });

  factory TiebaSubPostModel.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? userMap}) {
    final List<PostContentSegment> list = [];
    if (json['content'] is List) {
      for (var c in json['content']) {
        if (c is Map<String, dynamic>) list.add(PostContentSegment.fromJson(c));
      }
    }
    final authorId = json['author_id']?.toString() ?? json['authorId']?.toString();
    Map<String, dynamic>? authorJson;
    if (json['author'] is Map) {
      authorJson = Map<String, dynamic>.from(json['author'] as Map);
    } else if (json['user'] is Map) {
      authorJson = Map<String, dynamic>.from(json['user'] as Map);
    } else if (authorId != null && userMap != null && userMap.containsKey(authorId)) {
      final u = userMap[authorId];
      if (u is Map) authorJson = Map<String, dynamic>.from(u);
    }

    final author = TiebaAuthorModel.fromJson(
      authorJson,
      userMap: userMap,
      fallbackAuthorId: authorId,
    );
    return TiebaSubPostModel(
      id: json['id']?.toString() ?? '',
      author: author,
      contentList: list,
      time: int.tryParse(json['time']?.toString() ?? '0') ?? 0,
    );
  }
}

class TiebaFloorModel {
  final String id;
  final int floor;
  final TiebaAuthorModel author;
  final List<PostContentSegment> contentList;
  final int agreeNum;
  final bool isAgreed;
  final int subPostCount;
  final List<TiebaSubPostModel> subPosts;
  final int time;

  const TiebaFloorModel({
    required this.id,
    required this.floor,
    required this.author,
    required this.contentList,
    this.agreeNum = 0,
    this.isAgreed = false,
    this.subPostCount = 0,
    this.subPosts = const [],
    this.time = 0,
  });

  TiebaFloorModel copyWith({
    String? id,
    int? floor,
    TiebaAuthorModel? author,
    List<PostContentSegment>? contentList,
    int? agreeNum,
    bool? isAgreed,
    int? subPostCount,
    List<TiebaSubPostModel>? subPosts,
    int? time,
  }) {
    return TiebaFloorModel(
      id: id ?? this.id,
      floor: floor ?? this.floor,
      author: author ?? this.author,
      contentList: contentList ?? this.contentList,
      agreeNum: agreeNum ?? this.agreeNum,
      isAgreed: isAgreed ?? this.isAgreed,
      subPostCount: subPostCount ?? this.subPostCount,
      subPosts: subPosts ?? this.subPosts,
      time: time ?? this.time,
    );
  }

  factory TiebaFloorModel.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? userMap}) {
    final List<PostContentSegment> contents = [];
    if (json['content'] is List) {
      for (var c in json['content']) {
        if (c is Map<String, dynamic>) contents.add(PostContentSegment.fromJson(c));
      }
    }

    final List<TiebaSubPostModel> subList = [];
    int subCount = 0;
    if (json['sub_post_list'] is Map) {
      final subMap = json['sub_post_list'] as Map<String, dynamic>;
      subCount = int.tryParse(subMap['sub_post_number']?.toString() ?? '0') ?? 0;
      if (subMap['sub_post_list'] is List) {
        for (var s in subMap['sub_post_list']) {
          if (s is Map<String, dynamic>) subList.add(TiebaSubPostModel.fromJson(s, userMap: userMap));
        }
      }
    }

    final agree = json['agree'] as Map<String, dynamic>?;
    final agreeNum = int.tryParse(agree?['agree_num']?.toString() ?? json['agree_num']?.toString() ?? '0') ?? 0;
    final hasAgreed = agree?['has_agree'] == 1 || agree?['has_agree'] == '1';

    final authorId = json['author_id']?.toString() ?? json['authorId']?.toString();
    Map<String, dynamic>? authorJson;
    if (json['author'] is Map) {
      authorJson = Map<String, dynamic>.from(json['author'] as Map);
    } else if (json['user'] is Map) {
      authorJson = Map<String, dynamic>.from(json['user'] as Map);
    } else if (authorId != null && userMap != null && userMap.containsKey(authorId)) {
      final u = userMap[authorId];
      if (u is Map) authorJson = Map<String, dynamic>.from(u);
    }

    final author = TiebaAuthorModel.fromJson(
      authorJson,
      userMap: userMap,
      fallbackAuthorId: authorId,
    );

    return TiebaFloorModel(
      id: json['id']?.toString() ?? '',
      floor: int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      author: author,
      contentList: contents,
      agreeNum: agreeNum,
      isAgreed: hasAgreed,
      subPostCount: subCount,
      subPosts: subList,
      time: int.tryParse(json['time']?.toString() ?? '0') ?? 0,
    );
  }
}

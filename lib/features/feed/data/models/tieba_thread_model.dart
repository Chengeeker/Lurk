import '../../../../core/utils/tieba_emoticon_util.dart';

class TiebaAuthorModel {
  final String id;
  final String name;
  final String nameShow;
  final String portrait;
  final int level;
  final String ipAddress;

  const TiebaAuthorModel({
    required this.id,
    this.name = '',
    this.nameShow = '',
    this.portrait = '',
    this.level = 1,
    this.ipAddress = '',
  });

  String get displayName => nameShow.isNotEmpty ? nameShow : (name.isNotEmpty ? name : '贴吧吧友');

  factory TiebaAuthorModel.fromJson(
    dynamic rawJson, {
    Map<String, dynamic>? userMap,
    String? fallbackAuthorId,
  }) {
    final json = rawJson is Map ? Map<String, dynamic>.from(rawJson) : null;

    String id = json?['id']?.toString() ??
        json?['author_id']?.toString() ??
        json?['user_id']?.toString() ??
        json?['lz_uid']?.toString() ??
        '';

    if ((id.isEmpty || id == '0') && fallbackAuthorId != null && fallbackAuthorId.isNotEmpty && fallbackAuthorId != '0') {
      id = fallbackAuthorId;
    }
    if (id.isEmpty) id = '0';

    Map<String, dynamic>? userDetail;
    if (userMap != null && userMap.containsKey(id)) {
      userDetail = userMap[id] as Map<String, dynamic>?;
    }

    String name = json?['name']?.toString() ??
        json?['user_name']?.toString() ??
        json?['author_name']?.toString() ??
        userDetail?['name']?.toString() ??
        '';

    String nameShow = json?['name_show']?.toString() ??
        json?['show_nickname']?.toString() ??
        json?['nick_name']?.toString() ??
        userDetail?['name_show']?.toString() ??
        userDetail?['show_nickname']?.toString() ??
        '';

    String portrait = json?['portrait']?.toString() ??
        json?['user_portrait']?.toString() ??
        json?['portraith']?.toString() ??
        json?['icon']?.toString() ??
        json?['avatar']?.toString() ??
        userDetail?['portrait']?.toString() ??
        userDetail?['user_portrait']?.toString() ??
        userDetail?['portraith']?.toString() ??
        '';

    // Check user_show_info -> feed_head
    final rawShowInfo = json?['user_show_info'] ?? userDetail?['user_show_info'];
    final showInfo = rawShowInfo is Map ? (rawShowInfo is Map<String, dynamic> ? rawShowInfo : Map<String, dynamic>.from(rawShowInfo)) : null;
    if (showInfo != null) {
      final feedHead = showInfo['feed_head'] is Map ? (showInfo['feed_head'] as Map) : null;
      if (feedHead != null) {
        if (portrait.isEmpty && feedHead['image_data'] is Map) {
          portrait = feedHead['image_data']['img_url']?.toString() ?? '';
        }
        if (feedHead['main_data'] is List) {
          for (var item in feedHead['main_data']) {
            if (item is Map && item['type'] == 1 && item['text'] is Map) {
              final text = item['text']['text']?.toString();
              if (text != null && text.isNotEmpty) {
                if (nameShow.isEmpty || nameShow.startsWith('贴吧用户_')) {
                  nameShow = text;
                }
              }
            }
          }
        }
      }
    }

    // Check show_icon_list
    final rawIconList = json?['show_icon_list'] ?? userDetail?['show_icon_list'];
    final iconList = rawIconList is List ? rawIconList : null;
    if (iconList != null) {
      for (var icon in iconList) {
        if (icon is Map && icon['type'] == 'name_show' && icon['text'] != null) {
          final t = icon['text'].toString();
          if (t.isNotEmpty && (nameShow.isEmpty || nameShow.startsWith('贴吧用户_'))) {
            nameShow = t;
          }
        }
      }
    }

    if (nameShow.isEmpty) {
      nameShow = name.isNotEmpty ? name : '';
    }

    int level = int.tryParse(json?['level_id']?.toString() ??
            json?['user_level']?.toString() ??
            userDetail?['level_id']?.toString() ??
            userDetail?['user_level']?.toString() ??
            '1') ??
        1;

    String ipAddress = json?['ip_address']?.toString() ??
        json?['ip']?.toString() ??
        json?['location']?.toString() ??
        json?['user_location']?.toString() ??
        json?['province']?.toString() ??
        json?['ip_sync']?.toString() ??
        userDetail?['ip_address']?.toString() ??
        userDetail?['ip']?.toString() ??
        userDetail?['location']?.toString() ??
        userDetail?['user_location']?.toString() ??
        userDetail?['province']?.toString() ??
        userDetail?['ip_sync']?.toString() ??
        '';

    if (ipAddress.isEmpty && json?['ala_info'] is Map) {
      final ala = json!['ala_info'] as Map;
      ipAddress = ala['location']?.toString() ?? '';
    }
    if (ipAddress.isEmpty && userDetail?['ala_info'] is Map) {
      final ala = userDetail!['ala_info'] as Map;
      ipAddress = ala['location']?.toString() ?? '';
    }

    // 清理 "来自" 前缀与多余空格
    ipAddress = ipAddress.replaceAll('来自', '').trim();
    if (ipAddress == '0' || ipAddress.toLowerCase() == 'null') {
      ipAddress = '';
    }

    return TiebaAuthorModel(
      id: id,
      name: name,
      nameShow: nameShow,
      portrait: portrait,
      level: level,
      ipAddress: ipAddress,
    );
  }
}

class TiebaMediaModel {
  final String originUrl;
  final String bigCdnUrl;
  final String thumbUrl;
  final String type;
  final int width;
  final int height;
  final String videoUrl;
  final bool isLongPic;

  const TiebaMediaModel({
    required this.originUrl,
    required this.bigCdnUrl,
    required this.thumbUrl,
    this.videoUrl = '',
    this.type = 'pic',
    this.width = 0,
    this.height = 0,
    this.isLongPic = false,
  });

  factory TiebaMediaModel.fromJson(Map<String, dynamic> json) {
    // 1. 优先提取有效视频链接 (支持 vhsrc, vurl, video_url, link, play_url 等)
    final rawVurl = json['vhsrc']?.toString() ??
        json['vurl']?.toString() ??
        json['video_url']?.toString() ??
        json['link']?.toString() ??
        json['video_res_url']?.toString() ??
        json['play_url']?.toString() ??
        '';

    String vurl = '';
    if (rawVurl.isNotEmpty) {
      final lower = rawVurl.toLowerCase();
      if (lower.contains('.mp4') ||
          lower.contains('/video/') ||
          lower.contains('movideo') ||
          (!lower.endsWith('.jpg') &&
              !lower.endsWith('.jpeg') &&
              !lower.endsWith('.png') &&
              !lower.endsWith('.webp') &&
              !lower.endsWith('.gif'))) {
        vurl = rawVurl;
      }
    }

    // 2. 提取有效图片链接 (严格剔除 .swf 等非图片资源)
    bool isImage(String? u) {
      if (u == null || u.trim().isEmpty) return false;
      final lower = u.trim().toLowerCase();
      if (lower.endsWith('.swf') || lower.contains('.swf?') || lower.contains('/video.swf')) return false;
      return true;
    }

    String origin = '';
    for (var k in ['origin_pic', 'origin_src', 'vpic', 'big_pic', 'src_pic', 'src', 'thumbnail', 'thumbnail_url', 'first_frame_thumbnail']) {
      final val = json[k]?.toString();
      if (isImage(val)) {
        origin = val!;
        break;
      }
    }

    String big = '';
    for (var k in ['big_pic', 'big_cdn_src', 'src_pic', 'vpic', 'origin_pic', 'origin_src', 'src']) {
      final val = json[k]?.toString();
      if (isImage(val)) {
        big = val!;
        break;
      }
    }
    if (big.isEmpty) big = origin;

    String thumb = '';
    for (var k in ['cdn_src', 'src_pic', 'small_pic', 'small_thumbnail_url', 'vpic', 'big_pic', 'src']) {
      final val = json[k]?.toString();
      if (isImage(val)) {
        thumb = val!;
        break;
      }
    }
    if (thumb.isEmpty) thumb = big;

    final rawType = json['type']?.toString() ?? 'pic';
    String type = 'pic';
    if (rawType == 'video' || rawType == '5' || vurl.isNotEmpty) {
      type = 'video';
    }

    int w = 0, h = 0;
    if (json['bsize'] != null) {
      final parts = json['bsize'].toString().split(',');
      if (parts.length >= 2) {
        w = int.tryParse(parts[0]) ?? 0;
        h = int.tryParse(parts[1]) ?? 0;
      }
    } else {
      w = int.tryParse(json['width']?.toString() ?? '0') ?? 0;
      h = int.tryParse(json['height']?.toString() ?? '0') ?? 0;
    }

    return TiebaMediaModel(
      originUrl: origin,
      bigCdnUrl: big,
      thumbUrl: thumb,
      videoUrl: vurl,
      type: type,
      width: w,
      height: h,
      isLongPic: json['is_long_pic'] == 1 || json['is_long_pic'] == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origin_src': originUrl,
      'big_cdn_src': bigCdnUrl,
      'cdn_src': thumbUrl,
      'video_url': videoUrl,
      'type': type,
      'bsize': '$width,$height',
      'is_long_pic': isLongPic ? 1 : 0,
    };
  }
}

class TiebaVideoInfoModel {
  final String videoUrl;
  final String coverUrl;
  final int duration;
  final int width;
  final int height;

  const TiebaVideoInfoModel({
    required this.videoUrl,
    this.coverUrl = '',
    this.duration = 0,
    this.width = 0,
    this.height = 0,
  });

  factory TiebaVideoInfoModel.fromJson(Map<String, dynamic> json) {
    final url = json['video_url']?.toString() ??
        json['vurl']?.toString() ??
        json['video_res_url']?.toString() ??
        json['play_url']?.toString() ??
        json['url']?.toString() ??
        '';
    final cover = json['thumbnail_url']?.toString() ??
        json['cover_url']?.toString() ??
        json['vpic']?.toString() ??
        '';
    final dur = int.tryParse(json['video_duration']?.toString() ?? json['duration']?.toString() ?? '0') ?? 0;
    final w = int.tryParse(json['video_width']?.toString() ?? json['width']?.toString() ?? '0') ?? 0;
    final h = int.tryParse(json['video_height']?.toString() ?? json['height']?.toString() ?? '0') ?? 0;
    return TiebaVideoInfoModel(videoUrl: url, coverUrl: cover, duration: dur, width: w, height: h);
  }

  Map<String, dynamic> toJson() {
    return {
      'video_url': videoUrl,
      'thumbnail_url': coverUrl,
      'video_duration': duration,
      'video_width': width,
      'video_height': height,
    };
  }
}

class TiebaThreadModel {
  final String id;
  final String title;
  final String fname;
  final String fid;
  final String forumAvatar;
  final String contentSnippet;
  final int replyNum;
  final int agreeNum;
  final bool isAgreed;
  final bool isTop;
  final TiebaAuthorModel author;
  final List<TiebaMediaModel> mediaList;
  final int createTime;
  final TiebaVideoInfoModel? videoInfo;
  final String firstPostId;

  const TiebaThreadModel({
    required this.id,
    required this.title,
    this.fname = '',
    this.fid = '',
    this.forumAvatar = '',
    this.contentSnippet = '',
    this.replyNum = 0,
    this.agreeNum = 0,
    this.isAgreed = false,
    this.isTop = false,
    required this.author,
    this.mediaList = const [],
    this.createTime = 0,
    this.videoInfo,
    this.firstPostId = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fname': fname,
      'fid': fid,
      'content': [
        {'text': contentSnippet}
      ],
      'reply_num': replyNum,
      'agree_num': agreeNum,
      'agree': {'has_agree': isAgreed ? 1 : 0, 'agree_num': agreeNum},
      'is_top': isTop ? 1 : 0,
      'author': {
        'id': author.id,
        'name': author.name,
        'name_show': author.nameShow,
        'portrait': author.portrait,
      },
      'media': mediaList.map((e) => e.toJson()).toList(),
      'create_time': createTime,
      'first_post_id': firstPostId,
    };
  }

  TiebaThreadModel copyWith({
    String? id,
    String? title,
    String? fname,
    String? fid,
    String? contentSnippet,
    int? replyNum,
    int? agreeNum,
    bool? isAgreed,
    bool? isTop,
    TiebaAuthorModel? author,
    List<TiebaMediaModel>? mediaList,
    int? createTime,
    String? firstPostId,
  }) {
    return TiebaThreadModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fname: fname ?? this.fname,
      fid: fid ?? this.fid,
      contentSnippet: contentSnippet ?? this.contentSnippet,
      replyNum: replyNum ?? this.replyNum,
      agreeNum: agreeNum ?? this.agreeNum,
      isAgreed: isAgreed ?? this.isAgreed,
      isTop: isTop ?? this.isTop,
      author: author ?? this.author,
      mediaList: mediaList ?? this.mediaList,
      createTime: createTime ?? this.createTime,
      videoInfo: videoInfo,
      firstPostId: firstPostId ?? this.firstPostId,
    );
  }

  factory TiebaThreadModel.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? userMap}) {
    final id = json['id']?.toString() ??
        json['tid']?.toString() ??
        json['thread_id']?.toString() ??
        '';
    final title = json['title']?.toString() ??
        json['thread_title']?.toString() ??
        '';
    final fname = json['fname']?.toString() ?? json['forum_name']?.toString() ?? '';
    final fid = json['fid']?.toString() ?? json['forum_id']?.toString() ?? '';

    final List<TiebaMediaModel> media = [];
    if (json['media'] is List) {
      final Set<String> seenKeys = {};
      for (var item in json['media']) {
        if (item is Map<String, dynamic>) {
          final m = TiebaMediaModel.fromJson(item);
          final key = m.videoUrl.isNotEmpty
              ? m.videoUrl
              : (m.originUrl.isNotEmpty ? m.originUrl : m.bigCdnUrl);
          if (key.isNotEmpty && seenKeys.contains(key)) continue;
          if (key.isNotEmpty) seenKeys.add(key);
          media.add(m);
        }
      }
    }

    String extractSnippetFromList(List list) {
      final buffer = StringBuffer();
      for (var item in list) {
        if (item is Map) {
          final type = int.tryParse(item['type']?.toString() ?? '0') ?? 0;
          if (type == 2) {
            final c = item['c']?.toString() ?? '';
            if (c.isNotEmpty) {
              buffer.write(c.startsWith('[') && c.endsWith(']') ? c : '[$c]');
            } else {
              final text = item['text']?.toString() ?? '';
              if (text.isNotEmpty) {
                buffer.write(TiebaEmoticonUtil.getEmoticonName(text));
              }
            }
          } else if (type == 0 || type == 1 || type == 4) {
            buffer.write(item['text']?.toString() ?? '');
          }
        } else if (item is String) {
          buffer.write(item);
        }
      }
      return buffer.toString().trim();
    }

    String snippet = '';
    if (json['first_post_content'] is List && (json['first_post_content'] as List).isNotEmpty) {
      snippet = extractSnippetFromList(json['first_post_content'] as List);
    } else if (json['abstract'] is List && (json['abstract'] as List).isNotEmpty) {
      snippet = extractSnippetFromList(json['abstract'] as List);
    } else if (json['content'] is List && (json['content'] as List).isNotEmpty) {
      snippet = extractSnippetFromList(json['content'] as List);
    } else if (json['content'] is String && (json['content'] as String).isNotEmpty) {
      final rawHtml = json['content'] as String;
      snippet = rawHtml
          .replaceAll(RegExp(r'<img[^>]*image_emoticon(\d+)\.png[^>]*>'), '[表情]')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
    } else if (json['content_snippet'] != null) {
      snippet = json['content_snippet'].toString();
    }

    final agree = json['agree'] is Map ? (json['agree'] as Map) : null;
    final agreeNum = int.tryParse(agree?['agree_num']?.toString() ??
            agree?['diff_agree_num']?.toString() ??
            json['agree_num']?.toString() ??
            '0') ??
        0;
    final hasAgreed = agree?['has_agree'] == 1 ||
        agree?['has_agree'] == '1' ||
        json['has_agree'] == 1 ||
        json['has_agree'] == '1' ||
        json['is_agree'] == 1 ||
        json['is_agree'] == '1';

    final firstPostId = json['first_post_id']?.toString() ??
        json['post_id']?.toString() ??
        json['first_post']?['id']?.toString() ??
        '';

    Map<String, dynamic>? authorMap;
    if (json['author'] is Map) {
      authorMap = Map<String, dynamic>.from(json['author'] as Map);
    } else if (json['user'] is Map) {
      authorMap = Map<String, dynamic>.from(json['user'] as Map);
    }

    final authorId = json['author_id']?.toString() ??
        json['user_id']?.toString() ??
        authorMap?['id']?.toString() ??
        authorMap?['user_id']?.toString();

    TiebaAuthorModel author;
    if (authorMap != null) {
      author = TiebaAuthorModel.fromJson(
        authorMap,
        userMap: userMap,
        fallbackAuthorId: authorId,
      );
    } else {
      author = TiebaAuthorModel.fromJson(
        json,
        userMap: userMap,
        fallbackAuthorId: authorId,
      );
    }

    TiebaVideoInfoModel? videoInfo;
    if (json['video_info'] is Map) {
      final vModel = TiebaVideoInfoModel.fromJson(Map<String, dynamic>.from(json['video_info'] as Map));
      if (vModel.videoUrl.isNotEmpty && !vModel.videoUrl.toLowerCase().endsWith('.jpg')) {
        videoInfo = vModel;
      }
    } else if (json['video'] is Map) {
      final vModel = TiebaVideoInfoModel.fromJson(Map<String, dynamic>.from(json['video'] as Map));
      if (vModel.videoUrl.isNotEmpty && !vModel.videoUrl.toLowerCase().endsWith('.jpg')) {
        videoInfo = vModel;
      }
    }

    if (videoInfo != null && videoInfo.videoUrl.isNotEmpty && media.isEmpty) {
      media.add(TiebaMediaModel(
        originUrl: videoInfo.coverUrl,
        bigCdnUrl: videoInfo.coverUrl,
        thumbUrl: videoInfo.coverUrl,
        videoUrl: videoInfo.videoUrl,
        type: 'video',
        width: videoInfo.width,
        height: videoInfo.height,
      ));
    }

    return TiebaThreadModel(
      id: id,
      title: title,
      fname: fname,
      fid: fid,
      forumAvatar: json['forum_avatar']?.toString() ?? json['avatar']?.toString() ?? '',
      contentSnippet: snippet,
      replyNum: int.tryParse(json['reply_num']?.toString() ?? json['count']?.toString() ?? '0') ?? 0,
      agreeNum: agreeNum,
      isAgreed: hasAgreed,
      isTop: json['is_top'] == 1 || json['is_top'] == '1',
      author: author,
      mediaList: media,
      createTime: int.tryParse(json['create_time']?.toString() ?? json['time']?.toString() ?? json['last_time']?.toString() ?? '0') ?? 0,
      videoInfo: videoInfo,
      firstPostId: firstPostId,
    );
  }
}


class TiebaProfileModel {
  final String id;
  final String name;
  final String nameShow;
  final String portrait;
  final String intro;
  final int fansNum;
  final int concernNum;
  final int tiebaAge;
  final int postNum;
  final int threadNum;
  final int agreeNum;
  final int bookmarkNum;
  final int sex;
  final bool hasConcerned;
  final String ipAddress;

  const TiebaProfileModel({
    required this.id,
    required this.name,
    this.nameShow = '',
    this.portrait = '',
    this.intro = '',
    this.fansNum = 0,
    this.concernNum = 0,
    this.tiebaAge = 0,
    this.postNum = 0,
    this.threadNum = 0,
    this.agreeNum = 0,
    this.bookmarkNum = 0,
    this.sex = 0,
    this.hasConcerned = false,
    this.ipAddress = '',
  });

  String get displayName => nameShow.isNotEmpty ? nameShow : (name.isNotEmpty ? name : '贴吧吧友');

  factory TiebaProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    
    String nameShow = user['name_show']?.toString() ?? user['show_nickname']?.toString() ?? '';
    String portrait = user['portrait']?.toString() ?? user['portraith']?.toString() ?? '';

    if (user['show_icon_list'] is List) {
      for (var icon in user['show_icon_list']) {
        if (icon is Map && icon['type'] == 'name_show' && icon['text'] != null) {
          final t = icon['text'].toString();
          if (t.isNotEmpty) nameShow = t;
        }
      }
    }

    if (user['user_show_info'] is Map) {
      final feedHead = user['user_show_info']['feed_head'] as Map<String, dynamic>?;
      if (feedHead != null && feedHead['main_data'] is List) {
        for (var item in feedHead['main_data']) {
          if (item is Map && item['type'] == 1 && item['text'] is Map) {
            final text = item['text']['text']?.toString();
            if (text != null && text.isNotEmpty) nameShow = text;
          }
        }
      }
    }

    return TiebaProfileModel(
      id: user['id']?.toString() ?? '0',
      name: user['name']?.toString() ?? '',
      nameShow: nameShow,
      portrait: portrait,
      intro: user['intro']?.toString() ?? '',
      fansNum: int.tryParse(user['fans_num']?.toString() ?? '0') ?? 0,
      concernNum: int.tryParse(user['concern_num']?.toString() ?? '0') ?? 0,
      tiebaAge: int.tryParse(user['tb_age']?.toString() ?? '0') ?? 0,
      postNum: int.tryParse(user['post_num']?.toString() ?? '0') ?? 0,
      threadNum: int.tryParse(user['thread_num']?.toString() ?? '0') ?? 0,
      agreeNum: int.tryParse(user['total_agree_num']?.toString() ?? '0') ?? 0,
      bookmarkNum: int.tryParse(user['favorite_num']?.toString() ?? user['bookmark_count']?.toString() ?? '0') ?? 0,
      sex: int.tryParse(user['sex']?.toString() ?? '0') ?? 0,
      hasConcerned: user['has_concerned'] == 1 || user['has_concerned'] == '1',
      ipAddress: user['ip_address']?.toString() ?? '',
    );
  }
}


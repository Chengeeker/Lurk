class ForumTabModel {
  final int tabId;
  final String tabName;
  final int tabType;
  final bool isGood;

  const ForumTabModel({
    required this.tabId,
    required this.tabName,
    this.tabType = 0,
    this.isGood = false,
  });

  factory ForumTabModel.fromJson(Map<String, dynamic> json) {
    final name = json['tab_name']?.toString() ?? json['text']?.toString() ?? '';
    return ForumTabModel(
      tabId: int.tryParse(json['tab_id']?.toString() ?? '0') ?? 0,
      tabName: name,
      tabType: int.tryParse(json['tab_type']?.toString() ?? '0') ?? 0,
      isGood: json['is_good'] == 1 || name.contains('精华'),
    );
  }
}

class ForumRuleItemModel {
  final String title;
  final List<String> contents;

  const ForumRuleItemModel({required this.title, this.contents = const []});

  factory ForumRuleItemModel.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    final List<String> contents = [];

    void addText(String value) {
      final text = value.trim();
      if (text.isNotEmpty && !contents.contains(text)) contents.add(text);
    }

    void extract(dynamic value) {
      if (value is String) {
        addText(value);
        return;
      }
      if (value is List) {
        for (final item in value) {
          extract(item);
        }
        return;
      }
      if (value is Map) {
        if (value['text'] != null) addText(value['text'].toString());
        if (value['content'] != null) extract(value['content']);
        if (value['content_list'] != null) extract(value['content_list']);
        if (value['children'] != null) extract(value['children']);
        if (value['items'] != null) extract(value['items']);
      }
    }

    extract(json['content']);
    extract(json['content_list']);
    extract(json['children']);
    extract(json['items']);

    return ForumRuleItemModel(title: title, contents: contents);
  }
}

class ForumRuleDetailModel {
  final String title;
  final String preface;
  final String publishTime;
  final String bazhuName;
  final String bazhuPortrait;
  final List<ForumRuleItemModel> rules;

  const ForumRuleDetailModel({
    this.title = '',
    this.preface = '',
    this.publishTime = '',
    this.bazhuName = '',
    this.bazhuPortrait = '',
    this.rules = const [],
  });

  bool get isEmpty => rules.isEmpty && preface.isEmpty && title.isEmpty;

  factory ForumRuleDetailModel.fromJson(Map<String, dynamic> json) {
    final bazhu = json['bazhu'] is Map ? json['bazhu'] as Map : null;
    final List<ForumRuleItemModel> items = [];

    final rawRules =
        json['rules'] as List? ??
        json['new_rules'] as List? ??
        json['default_rules'] as List?;

    if (rawRules != null) {
      for (var r in rawRules) {
        if (r is Map<String, dynamic>) {
          items.add(ForumRuleItemModel.fromJson(r));
        } else if (r is Map) {
          items.add(ForumRuleItemModel.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    return ForumRuleDetailModel(
      title: json['title']?.toString() ?? '',
      preface: json['preface']?.toString() ?? '',
      publishTime: json['publish_time']?.toString() ?? '',
      bazhuName:
          bazhu?['name_show']?.toString() ?? bazhu?['name']?.toString() ?? '',
      bazhuPortrait: bazhu?['portrait']?.toString() ?? '',
      rules: items,
    );
  }
}

class ForumRuleModel {
  final String title;
  final bool hasForumRule;

  const ForumRuleModel({required this.title, this.hasForumRule = false});

  factory ForumRuleModel.fromJson(Map<String, dynamic> json) {
    return ForumRuleModel(
      title: json['title']?.toString() ?? '',
      hasForumRule:
          json['has_forum_rule'] == 1 || json['has_forum_rule'] == '1',
    );
  }
}

class ForumDetailModel {
  final String id;
  final String name;
  final String avatar;
  final String slogan;
  final int memberNum;
  final int postNum;
  final bool isLiked;
  final bool isSigned;
  final int userLevel;
  final int userExp;
  final List<ForumTabModel> tabs;
  final ForumRuleModel? rule;
  final String tbs;

  const ForumDetailModel({
    required this.id,
    required this.name,
    this.avatar = '',
    this.slogan = '',
    this.memberNum = 0,
    this.postNum = 0,
    this.isLiked = false,
    this.isSigned = false,
    this.userLevel = 0,
    this.userExp = 0,
    this.tabs = const [],
    this.rule,
    this.tbs = '',
  });

  ForumDetailModel copyWith({
    String? id,
    String? name,
    String? avatar,
    String? slogan,
    int? memberNum,
    int? postNum,
    bool? isLiked,
    bool? isSigned,
    int? userLevel,
    int? userExp,
    List<ForumTabModel>? tabs,
    ForumRuleModel? rule,
    String? tbs,
  }) {
    return ForumDetailModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      slogan: slogan ?? this.slogan,
      memberNum: memberNum ?? this.memberNum,
      postNum: postNum ?? this.postNum,
      isLiked: isLiked ?? this.isLiked,
      isSigned: isSigned ?? this.isSigned,
      userLevel: userLevel ?? this.userLevel,
      userExp: userExp ?? this.userExp,
      tabs: tabs ?? this.tabs,
      rule: rule ?? this.rule,
      tbs: tbs ?? this.tbs,
    );
  }

  factory ForumDetailModel.fromJson(
    Map<String, dynamic> json, {
    List<ForumTabModel>? tabs,
    ForumRuleModel? rule,
    String? tbs,
  }) {
    final signInInfo = json['sign_in_info'] as Map<String, dynamic>?;
    final userInfo = signInInfo?['user_info'] as Map<String, dynamic>?;
    final isSignIn = userInfo?['is_sign_in'];

    final bool isSigned =
        isSignIn == 1 ||
        isSignIn == '1' ||
        json['is_sign'] == 1 ||
        json['is_sign'] == '1' ||
        json['is_signed'] == 1 ||
        json['is_sign_in'] == 1 ||
        json['is_sign_in'] == '1';

    final bool isLiked =
        json['is_like'] == 1 ||
        json['is_like'] == '1' ||
        json['is_liked'] == 1 ||
        json['is_liked'] == '1' ||
        json['is_like_forum'] == 1;

    return ForumDetailModel(
      id: json['id']?.toString() ?? json['forum_id']?.toString() ?? '0',
      name: json['name']?.toString() ?? json['forum_name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      slogan: json['slogan']?.toString() ?? '',
      memberNum: int.tryParse(json['member_num']?.toString() ?? '0') ?? 0,
      postNum: int.tryParse(json['post_num']?.toString() ?? '0') ?? 0,
      isLiked: isLiked,
      isSigned: isSigned,
      userLevel: int.tryParse(json['user_level']?.toString() ?? '0') ?? 0,
      userExp: int.tryParse(json['user_exp']?.toString() ?? '0') ?? 0,
      tabs: tabs ?? [],
      rule: rule,
      tbs: tbs ?? '',
    );
  }
}

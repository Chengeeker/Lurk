class FollowedForumModel {
  final String id;
  final String name;
  final String avatar;
  final String slogan;
  final int userLevel;
  final int userExp;
  final bool isSigned;

  const FollowedForumModel({
    required this.id,
    required this.name,
    this.avatar = '',
    this.slogan = '',
    this.userLevel = 1,
    this.userExp = 0,
    this.isSigned = false,
  });

  FollowedForumModel copyWith({
    String? id,
    String? name,
    String? avatar,
    String? slogan,
    int? userLevel,
    int? userExp,
    bool? isSigned,
  }) {
    return FollowedForumModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      slogan: slogan ?? this.slogan,
      userLevel: userLevel ?? this.userLevel,
      userExp: userExp ?? this.userExp,
      isSigned: isSigned ?? this.isSigned,
    );
  }

  factory FollowedForumModel.fromJson(Map<String, dynamic> json) {
    return FollowedForumModel(
      id: json['id']?.toString() ?? json['forum_id']?.toString() ?? '0',
      name: json['name']?.toString() ?? json['forum_name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      slogan: json['slogan']?.toString() ?? '',
      userLevel: int.tryParse(json['user_level']?.toString() ?? json['level_id']?.toString() ?? '1') ?? 1,
      userExp: int.tryParse(json['user_exp']?.toString() ?? '0') ?? 0,
      isSigned: json['is_sign_in'] == 1 ||
          json['is_sign_in'] == '1' ||
          json['is_sign'] == 1 ||
          json['is_sign'] == '1' ||
          json['is_signed'] == 1 ||
          json['is_signed'] == '1',
    );
  }
}

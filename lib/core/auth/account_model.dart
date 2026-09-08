class AccountModel {
  final String uid;
  final String name;
  final String nameShow;
  final String portrait;
  final String bduss;
  final String stoken;
  final String baiduid;
  final String tbs;
  final bool isLogin;

  const AccountModel({
    required this.uid,
    this.name = '',
    this.nameShow = '',
    this.portrait = '',
    required this.bduss,
    this.stoken = '',
    this.baiduid = '',
    this.tbs = '',
    this.isLogin = true,
  });

  String get displayName => nameShow.isNotEmpty ? nameShow : (name.isNotEmpty ? name : '贴吧吧友');

  AccountModel copyWith({
    String? uid,
    String? name,
    String? nameShow,
    String? portrait,
    String? bduss,
    String? stoken,
    String? baiduid,
    String? tbs,
    bool? isLogin,
  }) {
    return AccountModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      nameShow: nameShow ?? this.nameShow,
      portrait: portrait ?? this.portrait,
      bduss: bduss ?? this.bduss,
      stoken: stoken ?? this.stoken,
      baiduid: baiduid ?? this.baiduid,
      tbs: tbs ?? this.tbs,
      isLogin: isLogin ?? this.isLogin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'nameShow': nameShow,
      'portrait': portrait,
      'bduss': bduss,
      'stoken': stoken,
      'baiduid': baiduid,
      'tbs': tbs,
      'isLogin': isLogin,
    };
  }

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameShow: json['nameShow']?.toString() ?? '',
      portrait: json['portrait']?.toString() ?? '',
      bduss: json['bduss']?.toString() ?? '',
      stoken: json['stoken']?.toString() ?? '',
      baiduid: json['baiduid']?.toString() ?? '',
      tbs: json['tbs']?.toString() ?? '',
      isLogin: json['isLogin'] ?? true,
    );
  }
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import '../../../../core/constants/tieba_constants.dart';

/// Protobuf representation of Tieba CommonRequest (V12 Post version)
class CommonRequest extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('CommonRequest', createEmptyInstance: create)
    ..a<int>(1, 'clientType', PbFieldType.O3)
    ..aOS(2, 'clientVersion')
    ..aOS(3, 'clientId')
    ..aOS(5, 'phoneImei')
    ..aOS(6, 'from')
    ..aOS(7, 'cuid')
    ..aInt64(8, 'timestamp')
    ..aOS(9, 'model')
    ..aOS(10, 'bduss', protoName: 'BDUSS')
    ..aOS(11, 'tbs')
    ..a<int>(12, 'netType', PbFieldType.O3)
    ..aOS(24, 'pversion')
    ..aOS(25, 'osVersion')
    ..aOS(26, 'brand')
    ..aOS(28, 'legoLibVersion')
    ..aOS(30, 'stoken')
    ..aOS(32, 'cuidGalaxy2')
    ..aOS(35, 'c3Aid')
    ..a<int>(37, 'scrW', PbFieldType.O3)
    ..a<int>(38, 'scrH', PbFieldType.O3)
    ..a<double>(39, 'scrDip', PbFieldType.OD)
    ..aOS(42, 'sdkVer')
    ..aOS(43, 'frameworkVer')
    ..aOS(44, 'swanGameVer')
    ..aInt64(49, 'activeTimestamp')
    ..aInt64(50, 'firstInstallTime')
    ..aInt64(51, 'lastUpdateTime')
    ..aOS(53, 'eventDay')
    ..aOS(54, 'androidId')
    ..a<int>(55, 'cmode', PbFieldType.O3)
    ..a<int>(57, 'startType', PbFieldType.O3)
    ..aOS(62, 'userAgent')
    ..a<int>(63, 'personalizedRecSwitch', PbFieldType.O3)
    ..aOS(70, 'deviceScore')
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;
  @override
  CommonRequest createEmptyInstance() => create();
  static CommonRequest create() => CommonRequest();

  CommonRequest() : super();
  @override
  CommonRequest clone() => create()..mergeFromMessage(this);

  int get clientType => $_getIZ(0);
  set clientType(int v) => $_setSignedInt32(0, v);

  String get clientVersion => $_getSZ(1);
  set clientVersion(String v) => $_setString(1, v);

  String get clientId => $_getSZ(2);
  set clientId(String v) => $_setString(2, v);

  String get from => $_getSZ(4);
  set from(String v) => $_setString(4, v);

  String get cuid => $_getSZ(5);
  set cuid(String v) => $_setString(5, v);

  Int64 get timestamp => $_getI64(6);
  set timestamp(Int64 v) => $_setInt64(6, v);

  String get model => $_getSZ(7);
  set model(String v) => $_setString(7, v);

  String get bduss => $_getSZ(8);
  set bduss(String v) => $_setString(8, v);

  String get tbs => $_getSZ(9);
  set tbs(String v) => $_setString(9, v);

  int get netType => $_getIZ(10);
  set netType(int v) => $_setSignedInt32(10, v);

  String get pversion => $_getSZ(11);
  set pversion(String v) => $_setString(11, v);

  String get osVersion => $_getSZ(12);
  set osVersion(String v) => $_setString(12, v);

  String get brand => $_getSZ(13);
  set brand(String v) => $_setString(13, v);

  String get legoLibVersion => $_getSZ(14);
  set legoLibVersion(String v) => $_setString(14, v);

  String get stoken => $_getSZ(15);
  set stoken(String v) => $_setString(15, v);

  String get cuidGalaxy2 => $_getSZ(16);
  set cuidGalaxy2(String v) => $_setString(16, v);

  String get c3Aid => $_getSZ(17);
  set c3Aid(String v) => $_setString(17, v);

  int get scrW => $_getIZ(18);
  set scrW(int v) => $_setSignedInt32(18, v);

  int get scrH => $_getIZ(19);
  set scrH(int v) => $_setSignedInt32(19, v);

  double get scrDip => $_getN(20);
  set scrDip(double v) => $_setDouble(20, v);

  String get sdkVer => $_getSZ(21);
  set sdkVer(String v) => $_setString(21, v);

  String get frameworkVer => $_getSZ(22);
  set frameworkVer(String v) => $_setString(22, v);

  String get swanGameVer => $_getSZ(23);
  set swanGameVer(String v) => $_setString(23, v);

  String get eventDay => $_getSZ(27);
  set eventDay(String v) => $_setString(27, v);

  String get androidId => $_getSZ(28);
  set androidId(String v) => $_setString(28, v);

  int get cmode => $_getIZ(29);
  set cmode(int v) => $_setSignedInt32(29, v);

  int get startType => $_getIZ(30);
  set startType(int v) => $_setSignedInt32(30, v);

  String get userAgent => $_getSZ(31);
  set userAgent(String v) => $_setString(31, v);

  int get personalizedRecSwitch => $_getIZ(32);
  set personalizedRecSwitch(int v) => $_setSignedInt32(32, v);

  String get deviceScore => $_getSZ(33);
  set deviceScore(String v) => $_setString(33, v);
}

/// Protobuf representation of Tieba AddPostRequestData
class AddPostRequestData extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AddPostRequestData', createEmptyInstance: create)
    ..a<CommonRequest>(1, 'common', PbFieldType.OM, defaultOrMaker: CommonRequest.create, subBuilder: CommonRequest.create)
    ..aOS(4, 'tbs')
    ..aOS(6, 'anonymous')
    ..aOS(7, 'canNoForum')
    ..aOS(8, 'isFeedback')
    ..aOS(9, 'takephotoNum')
    ..aOS(10, 'entranceType')
    ..aOS(16, 'vcodeTag')
    ..aOS(18, 'newVcode')
    ..aOS(19, 'content')
    ..aOS(20, 'replyUid')
    ..aOS(26, 'fid')
    ..aOS(28, 'vFid')
    ..aOS(29, 'vFname')
    ..aOS(30, 'kw')
    ..aOS(31, 'isBarrage')
    ..aOS(32, 'barrageTime')
    ..aOS(45, 'tid')
    ..aOS(46, 'quoteId')
    ..aOS(47, 'isTwzhiboThread')
    ..aOS(48, 'floorNum')
    ..aOS(49, 'repostid')
    ..aOS(50, 'subPostId')
    ..aOS(51, 'isAd')
    ..aOS(52, 'isAddition')
    ..aOS(53, 'isGiftpost')
    ..aOS(55, 'postFrom')
    ..aOS(58, 'nameShow')
    ..aOS(60, 'isPictxt')
    ..a<int>(64, 'showCustomFigure', PbFieldType.O3)
    ..a<int>(67, 'isShowBless', PbFieldType.O3)
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;
  @override
  AddPostRequestData createEmptyInstance() => create();
  static AddPostRequestData create() => AddPostRequestData();

  AddPostRequestData() : super();
  @override
  AddPostRequestData clone() => create()..mergeFromMessage(this);

  CommonRequest get common => $_getN(0);
  set common(CommonRequest v) => setField(1, v);

  String get tbs => $_getSZ(1);
  set tbs(String v) => setField(4, v);

  String get anonymous => $_getSZ(2);
  set anonymous(String v) => setField(6, v);

  String get canNoForum => $_getSZ(3);
  set canNoForum(String v) => setField(7, v);

  String get isFeedback => $_getSZ(4);
  set isFeedback(String v) => setField(8, v);

  String get takephotoNum => $_getSZ(5);
  set takephotoNum(String v) => setField(9, v);

  String get entranceType => $_getSZ(6);
  set entranceType(String v) => setField(10, v);

  String get vcodeTag => $_getSZ(7);
  set vcodeTag(String v) => setField(16, v);

  String get newVcode => $_getSZ(8);
  set newVcode(String v) => setField(18, v);

  String get content => $_getSZ(9);
  set content(String v) => setField(19, v);

  String get replyUid => $_getSZ(10);
  set replyUid(String v) => setField(20, v);

  String get fid => $_getSZ(11);
  set fid(String v) => setField(26, v);

  String get vFid => $_getSZ(12);
  set vFid(String v) => setField(28, v);

  String get vFname => $_getSZ(13);
  set vFname(String v) => setField(29, v);

  String get kw => $_getSZ(14);
  set kw(String v) => setField(30, v);

  String get isBarrage => $_getSZ(15);
  set isBarrage(String v) => setField(31, v);

  String get barrageTime => $_getSZ(16);
  set barrageTime(String v) => setField(32, v);

  String get tid => $_getSZ(17);
  set tid(String v) => setField(45, v);

  String get quoteId => $_getSZ(18);
  set quoteId(String v) => setField(46, v);

  String get isTwzhiboThread => $_getSZ(19);
  set isTwzhiboThread(String v) => setField(47, v);

  String get floorNum => $_getSZ(20);
  set floorNum(String v) => setField(48, v);

  String get repostid => $_getSZ(21);
  set repostid(String v) => setField(49, v);

  String get subPostId => $_getSZ(22);
  set subPostId(String v) => setField(50, v);

  String get isAd => $_getSZ(23);
  set isAd(String v) => setField(51, v);

  String get isAddition => $_getSZ(24);
  set isAddition(String v) => setField(52, v);

  String get isGiftpost => $_getSZ(25);
  set isGiftpost(String v) => setField(53, v);

  String get postFrom => $_getSZ(26);
  set postFrom(String v) => setField(55, v);

  String get nameShow => $_getSZ(27);
  set nameShow(String v) => setField(58, v);

  String get isPictxt => $_getSZ(28);
  set isPictxt(String v) => setField(60, v);

  int get showCustomFigure => $_getIZ(29);
  set showCustomFigure(int v) => setField(64, v);

  int get isShowBless => $_getIZ(30);
  set isShowBless(int v) => setField(67, v);
}

/// Protobuf root wrapper for AddPostRequest
class AddPostRequest extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AddPostRequest', createEmptyInstance: create)
    ..a<AddPostRequestData>(1, 'data', PbFieldType.OM, defaultOrMaker: AddPostRequestData.create, subBuilder: AddPostRequestData.create)
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;
  @override
  AddPostRequest createEmptyInstance() => create();
  static AddPostRequest create() => AddPostRequest();

  AddPostRequest() : super();
  @override
  AddPostRequest clone() => create()..mergeFromMessage(this);

  AddPostRequestData get data => $_getN(0);
  set data(AddPostRequestData v) => setField(1, v);
}

/// Protobuf Error definition returned by Tieba server
class ProtoError extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('ProtoError', createEmptyInstance: create)
    ..a<int>(1, 'errorCode', PbFieldType.O3)
    ..aOS(2, 'errorMsg')
    ..aOS(3, 'userMsg')
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;
  @override
  ProtoError createEmptyInstance() => create();
  static ProtoError create() => ProtoError();

  ProtoError() : super();
  @override
  ProtoError clone() => create()..mergeFromMessage(this);

  int get errorCode => $_getIZ(0);
  set errorCode(int v) => setField(1, v);

  String get errorMsg => $_getSZ(1);
  set errorMsg(String v) => setField(2, v);

  String get userMsg => $_getSZ(2);
  set userMsg(String v) => setField(3, v);
}

/// Protobuf AddPostResponseData
class AddPostResponseData extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AddPostResponseData', createEmptyInstance: create)
    ..aOS(1, 'opgroup')
    ..aOS(2, 'tid')
    ..aOS(3, 'pid')
    ..aOS(5, 'msg')
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;
  @override
  AddPostResponseData createEmptyInstance() => create();
  static AddPostResponseData create() => AddPostResponseData();

  AddPostResponseData() : super();
  @override
  AddPostResponseData clone() => create()..mergeFromMessage(this);

  String get opgroup => $_getSZ(0);
  set opgroup(String v) => setField(1, v);

  String get tid => $_getSZ(1);
  set tid(String v) => setField(2, v);

  String get pid => $_getSZ(2);
  set pid(String v) => setField(3, v);

  String get msg => $_getSZ(3);
  set msg(String v) => setField(5, v);
}

/// Protobuf AddPostResponse
class AddPostResponse extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AddPostResponse', createEmptyInstance: create)
    ..a<ProtoError>(1, 'error', PbFieldType.OM, defaultOrMaker: ProtoError.create, subBuilder: ProtoError.create)
    ..a<AddPostResponseData>(2, 'data', PbFieldType.OM, defaultOrMaker: AddPostResponseData.create, subBuilder: AddPostResponseData.create)
    ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;
  @override
  AddPostResponse createEmptyInstance() => create();
  static AddPostResponse create() => AddPostResponse();

  AddPostResponse() : super();
  @override
  AddPostResponse clone() => create()..mergeFromMessage(this);

  ProtoError get error => $_getN(0);
  set error(ProtoError v) => setField(1, v);

  AddPostResponseData get data => $_getN(1);
  set data(AddPostResponseData v) => setField(2, v);
}

/// Utility to calculate Tieba client MD5 sign for parameters
String calculateTiebaSign(Map<String, String> params) {
  final sortedKeys = params.keys.toList()..sort();
  final buffer = StringBuffer();
  for (var key in sortedKeys) {
    buffer.write('$key=${params[key]}');
  }
  buffer.write(TiebaConstants.appSecret);
  final bytes = utf8.encode(buffer.toString());
  return md5.convert(bytes).toString();
}

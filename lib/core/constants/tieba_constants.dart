class TiebaConstants {
  TiebaConstants._();

  static const String appSecret = 'tiebaclient!!!';
  static const String defaultClientVersion = '12.41.7.1';
  static const String defaultClientType = '2';

  static const String baseNativeUrl = 'https://c.tieba.baidu.com';
  static const String baseWebUrl = 'https://tieba.baidu.com';
  static const String baseProtobufUrl = 'https://tiebac.baidu.com';

  // Native Endpoints
  static const String pathLogin = '/c/s/login';
  static const String pathProfile = '/c/u/user/profile';
  static const String pathPersonalizedFeed = '/c/f/excellent/personalized';
  static const String pathForumPage = '/c/f/frs/page';
  static const String pathGeneralTabList = '/c/f/frs/generalTabList';
  static const String pathThreadDetail = '/c/f/pb/page';
  static const String pathFloor = '/c/f/pb/floor';
  static const String pathFollowedForums = '/c/f/forum/getforumlist';
  static const String pathSearchPost = '/c/s/searchpost';
  static const String pathSearchSug = '/c/s/searchsug';
  static const String pathAgree = '/c/c/agree/opAgree';
  static const String pathSign = '/c/c/forum/sign';
  static const String pathBatchSign = '/c/c/forum/msign';
  static const String pathAddPost = '/c/c/post/add';
  static const String pathDelPost = '/c/c/bawu/delpost';
  static const String pathDelThread = '/c/c/bawu/delthread';
  static const String pathReplyMe = '/c/u/feed/replyme';
  static const String pathAtMe = '/c/u/feed/atme';
  static const String pathUserPost = '/c/u/feed/userpost';
  static const String pathFollow = '/c/c/user/follow';
  static const String pathUnfollow = '/c/c/user/unfollow';
  static const String pathLikeForum = '/c/c/forum/like';
  static const String pathUnlikeForum = '/c/c/forum/unfavolike';
  static const String pathDislike = '/c/c/excellent/submitDislike';
  static const String pathForumRuleDetail = '/c/f/forum/forumRuleDetail';
  static const String pathThreadStore = '/c/f/post/threadstore';
  static const String pathAddStore = '/c/c/post/addstore';
  static const String pathRemoveStore = '/c/c/post/rmstore';

  // Common Headers & User Agent
  static String defaultUserAgent = 'bdtb for Android $defaultClientVersion';

  // Avatar / Portrait URL helper
  static String getPortraitUrl(String? portrait) {
    if (portrait == null || portrait.isEmpty) {
      return 'https://gss0.bdstatic.com/7Ls0a8Sm1A5BphGlnYG/sys/portrait/item/default.jpg';
    }
    if (portrait.startsWith('http://') || portrait.startsWith('https://')) {
      return portrait;
    }
    return 'https://gss0.bdstatic.com/7Ls0a8Sm1A5BphGlnYG/sys/portrait/item/$portrait';
  }

  // Forum Avatar URL helper
  static String getForumAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return 'https://tb1.bdstatic.com/tb/r/sys/portrait/item/default.jpg';
    }
    if (avatar.startsWith('http')) return avatar;
    return 'https://tb1.bdstatic.com/tb/cms/post/avatar/$avatar';
  }
}

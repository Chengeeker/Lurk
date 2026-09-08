import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/constants/tieba_constants.dart';
import 'package:lurk/core/network/sign_interceptor.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/core/providers/thread_agree_provider.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/utils/tieba_emoticon_util.dart';
import 'package:lurk/features/detail/data/models/tieba_post_model.dart';
import 'package:lurk/features/detail/data/protobuf/add_post_protobuf.dart';
import 'package:lurk/features/feed/data/models/hot_topic_model.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/forum/data/models/forum_model.dart';
import 'package:lurk/features/profile/data/bookmarks_repository.dart';
import 'package:lurk/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tieba sign calculation test', () {
    final params = {'kw': 'flutter', 'pn': '1'};
    final sign = SignInterceptor.calculateSign(params);
    expect(sign, isNotEmpty);
    expect(sign.length, equals(32));
  });

  test('Tieba avatar url helper', () {
    final url = TiebaConstants.getPortraitUrl('tb.1.1379aa5b');
    expect(url.contains('tb.1.1379aa5b'), isTrue);
  });

  test('TiebaThreadModel serialization roundtrip test', () {
    const thread = TiebaThreadModel(
      id: '123456',
      title: '测试贴子标题',
      fname: '原神内容讨论',
      contentSnippet: '这是一个测试贴子内容',
      replyNum: 42,
      agreeNum: 10,
      isTop: true,
      author: TiebaAuthorModel(id: '999', name: '测试用户', portrait: 'tb.1.test'),
    );

    final json = thread.toJson();
    expect(json['id'], equals('123456'));
    expect(json['title'], equals('测试贴子标题'));

    final restored = TiebaThreadModel.fromJson(json);
    expect(restored.id, equals('123456'));
    expect(restored.title, equals('测试贴子标题'));
    expect(restored.replyNum, equals(42));
    expect(restored.author.name, equals('测试用户'));
  });

  test('TiebaThreadModel userpost format parsing test', () {
    final userpostJson = {
      'thread_id': '10994476182',
      'post_id': '153899793967',
      'title': '用户自己发布的帖子标题',
      'first_post_content': [
        {'type': 0, 'text': '这是第一楼的内容摘要'},
        {'type': 2, 'text': 'image_emoticon', 'c': '呵呵'},
        {'type': 2, 'text': 'image_emoticon', 'c': '滑稽'},
      ],
      'fname': '抗压背锅吧',
      'reply_num': 15,
      'agree_num': 8,
    };

    final thread = TiebaThreadModel.fromJson(userpostJson);
    expect(thread.id, equals('10994476182'));
    expect(thread.title, equals('用户自己发布的帖子标题'));
    expect(thread.contentSnippet, equals('这是第一楼的内容摘要[呵呵][滑稽]'));
    expect(thread.fname, equals('抗压背锅吧'));
  });

  test('TiebaHotTopicModel parsing test', () {
    final hotJson = {
      'topic_id': '28362171',
      'topic_name': '测试热榜话题',
      'topic_desc': '热榜描述测试',
      'discuss_num': 1697486,
      'topic_url': 'https://tieba.baidu.com/hottopic/...',
    };

    final topic = TiebaHotTopicModel.fromJson(hotJson);
    expect(topic.topicId, equals('28362171'));
    expect(topic.topicName, equals('测试热榜话题'));
    expect(topic.formattedDiscussNum, equals('169.7万讨论'));
  });

  test('Tieba native emoticons resolution and PostContentSegment test', () {
    // 1. Emoticon resolution
    final smileUrl = TiebaEmoticonUtil.getEmoticonUrl('image_emoticon', '呵呵');
    expect(
      smileUrl,
      equals(
        'https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon1.png',
      ),
    );

    final huajiUrl = TiebaEmoticonUtil.getEmoticonUrl('image_emoticon', '滑稽');
    expect(
      huajiUrl,
      equals(
        'https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon25.png',
      ),
    );

    final bracketSmile = TiebaEmoticonUtil.getEmoticonUrl('#(smile)');
    expect(
      bracketSmile,
      equals(
        'https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon1.png',
      ),
    );

    // 2. PostContentSegment parses c
    final segJson = {'type': 2, 'text': 'image_emoticon', 'c': '呵呵'};
    final seg = PostContentSegment.fromJson(segJson);
    expect(seg.type, equals(2));
    expect(seg.text, equals('image_emoticon'));
    expect(seg.c, equals('呵呵'));
  });

  testWidgets('LurkApp widget smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      StorageService.keyHabitInitialTabIndex: 0,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: const LurkApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('我的关注'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  test('ThreadAgreeProvider global synchronization test', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state is empty
    expect(container.read(threadAgreeProvider).containsKey('12345'), isFalse);

    // Card/detail updates agree state
    container.read(threadAgreeProvider.notifier).setAgree('12345', true, 10);
    expect(container.read(threadAgreeProvider)['12345']?.isAgreed, isTrue);
    expect(container.read(threadAgreeProvider)['12345']?.agreeNum, equals(10));

    // Detail/card cancels agree state
    container.read(threadAgreeProvider.notifier).setAgree('12345', false, 9);
    expect(container.read(threadAgreeProvider)['12345']?.isAgreed, isFalse);
    expect(container.read(threadAgreeProvider)['12345']?.agreeNum, equals(9));
  });

  test('AddPostRequest and AddPostResponse protobuf serialization test', () {
    final common = CommonRequest()
      ..clientType = 2
      ..clientVersion = '12.35.1.0'
      ..clientId = 'test_client'
      ..cuid = 'test_cuid'
      ..bduss = 'test_bduss'
      ..tbs = 'test_tbs';

    final data = AddPostRequestData()
      ..common = common
      ..anonymous = '1'
      ..content = 'Hello Lurk'
      ..fid = '123'
      ..kw = 'test'
      ..tid = '456'
      ..postFrom = '13';

    final req = AddPostRequest()..data = data;
    final bytes = req.writeToBuffer();
    expect(bytes, isNotEmpty);

    final decodedReq = AddPostRequest.create()..mergeFromBuffer(bytes);
    expect(decodedReq.data.content, equals('Hello Lurk'));
    expect(decodedReq.data.anonymous, equals('1'));
    expect(decodedReq.data.fid, equals('123'));
    expect(decodedReq.data.common.clientVersion, equals('12.35.1.0'));

    // Response decode test
    final resp = AddPostResponse()
      ..error = (ProtoError()
        ..errorCode = 0
        ..errorMsg = '')
      ..data = (AddPostResponseData()
        ..tid = '456'
        ..pid = '789');

    final respBytes = resp.writeToBuffer();
    final decodedResp = AddPostResponse.create()..mergeFromBuffer(respBytes);
    expect(decodedResp.error.errorCode, equals(0));
    expect(decodedResp.data.pid, equals('789'));
  });

  test('ForumDetailModel isLiked parsing and copyWith test', () {
    final rawUnliked = {
      'id': 12345,
      'name': 'test_forum',
      'avatar': 'avatar.jpg',
      'slogan': 'slogan',
      'member_num': 100,
      'post_num': 200,
      'is_like': 0,
      'is_sign_in': 0,
      'tbs': 'test_tbs',
    };
    final unlikedModel = ForumDetailModel.fromJson(rawUnliked);
    expect(unlikedModel.isLiked, isFalse);
    expect(unlikedModel.isSigned, isFalse);

    final rawLiked = {
      'id': 12345,
      'name': 'test_forum',
      'avatar': 'avatar.jpg',
      'slogan': 'slogan',
      'member_num': 100,
      'post_num': 200,
      'is_like': 1,
      'is_sign_in': 1,
      'tbs': 'test_tbs',
    };
    final likedModel = ForumDetailModel.fromJson(rawLiked);
    expect(likedModel.isLiked, isTrue);
    expect(likedModel.isSigned, isTrue);

    // Test copyWith
    final toggled = unlikedModel.copyWith(isLiked: true, isSigned: true);
    expect(toggled.isLiked, isTrue);
    expect(toggled.isSigned, isTrue);

    final unfollowed = likedModel.copyWith(isLiked: false, isSigned: false);
    expect(unfollowed.isLiked, isFalse);
    expect(unfollowed.isSigned, isFalse);
  });

  test('TiebaConstants forum like/unlike endpoint paths test', () {
    expect(TiebaConstants.pathLikeForum, equals('/c/c/forum/like'));
    expect(TiebaConstants.pathUnlikeForum, equals('/c/c/forum/unfavolike'));
    expect(
      TiebaConstants.pathForumRuleDetail,
      equals('/c/f/forum/forumRuleDetail'),
    );
    expect(TiebaConstants.pathThreadStore, equals('/c/f/post/threadstore'));
    expect(TiebaConstants.pathAddStore, equals('/c/c/post/addstore'));
    expect(TiebaConstants.pathRemoveStore, equals('/c/c/post/rmstore'));
  });

  test('ForumRuleDetailModel parsing and empty state test', () {
    final emptyRuleJson = {'title': '', 'preface': '', 'rules': []};
    final emptyModel = ForumRuleDetailModel.fromJson(emptyRuleJson);
    expect(emptyModel.isEmpty, isTrue);

    final fullRuleJson = {
      'title': '测试吧规',
      'preface': '欢迎大家来到本吧，文明交流。',
      'publish_time': '2025.01.01',
      'bazhu': {'name_show': '测试吧主', 'portrait': 'portrait_xyz'},
      'rules': [
        {
          'title': '一、禁止广告',
          'content': [
            {'type': '0', 'text': '严禁发布任何广告、违禁品信息。'},
            {'type': '0', 'text': '违者直接封禁十天。'},
          ],
        },
        {
          'title': '二、禁止恶意攻击',
          'content_list': [
            {
              'content': [
                {'type': '0', 'text': '禁止对他人进行人身攻击与谩骂。'},
              ],
            },
          ],
        },
      ],
    };

    final ruleModel = ForumRuleDetailModel.fromJson(fullRuleJson);
    expect(ruleModel.isEmpty, isFalse);
    expect(ruleModel.title, equals('测试吧规'));
    expect(ruleModel.preface, contains('文明交流'));
    expect(ruleModel.bazhuName, equals('测试吧主'));
    expect(ruleModel.rules.length, equals(2));
    expect(ruleModel.rules[0].title, equals('一、禁止广告'));
    expect(ruleModel.rules[0].contents.length, equals(2));
    expect(ruleModel.rules[0].contents[0], contains('严禁发布任何广告'));
    expect(ruleModel.rules[1].title, equals('二、禁止恶意攻击'));
    expect(ruleModel.rules[1].contents[0], contains('禁止对他人进行人身攻击'));
  });

  test('ThreadStore json to TiebaThreadModel mapping test', () {
    final threadStoreJson = {
      'thread_id': '99887766',
      'title': '收藏贴标题测试',
      'forum_name': '抗压背锅',
      'author': {
        'lz_uid': '12345678',
        'name': 'author_name',
        'name_show': '楼主昵称',
        'user_portrait': 'user_portrait_123',
      },
      'media': [
        {
          'type': 'pic',
          'small_Pic': 'http://tb1.bdstatic.com/small.jpg',
          'big_pic': 'http://tb1.bdstatic.com/big.jpg',
        },
      ],
      'is_deleted': '0',
      'last_time': '1720000000',
      'count': '88',
    };

    final model = TiebaThreadModel.fromJson(threadStoreJson);
    expect(model.id, equals('99887766'));
    expect(model.title, equals('收藏贴标题测试'));
    expect(model.fname, equals('抗压背锅'));
    expect(model.author.displayName, equals('楼主昵称'));
    expect(model.author.id, equals('12345678'));
    expect(model.mediaList.isNotEmpty, isTrue);
    expect(model.replyNum, equals(88));
    expect(model.createTime, equals(1720000000));
  });

  test('account-scoped bookmark storage migrates legacy entries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    const thread = TiebaThreadModel(
      id: 'legacy-thread',
      title: '旧版收藏',
      author: TiebaAuthorModel(id: '1', name: 'author'),
    );
    await storage.setStringList(StorageService.keyBookmarks, [
      jsonEncode(thread.toJson()),
    ]);

    final repository = BookmarksRepository(TiebaDioClient(), storage);
    await repository.migrateLegacyBookmarksToAccount('account-1');

    expect(
      repository.getLocalBookmarks(userId: 'account-1').single.id,
      'legacy-thread',
    );
    expect(
      repository.getPendingLocalBookmarks('account-1').single.id,
      'legacy-thread',
    );
    expect(repository.getLocalBookmarks().isEmpty, isTrue);
  });

  test('bookmark caches are isolated between accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final repository = BookmarksRepository(TiebaDioClient(), storage);
    const thread = TiebaThreadModel(
      id: 'account-thread',
      title: '账号收藏',
      author: TiebaAuthorModel(id: '1', name: 'author'),
    );

    await repository.saveLocalBookmark(thread, userId: 'account-1');
    expect(
      repository.isLocallyBookmarked('account-thread', userId: 'account-1'),
      isTrue,
    );
    expect(
      repository.isLocallyBookmarked('account-thread', userId: 'account-2'),
      isFalse,
    );
  });
}

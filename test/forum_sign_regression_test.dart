import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/account_model.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/utils/app_toast.dart';
import 'package:lurk/features/forum/data/forum_repository.dart';
import 'package:lurk/features/forum/data/models/forum_model.dart';
import 'package:lurk/features/forum/presentation/forum_controller.dart';
import 'package:lurk/features/my_forums/data/my_forums_repository.dart';
import 'package:lurk/features/my_forums/data/models/followed_forum_model.dart';
import 'package:lurk/features/my_forums/presentation/my_forums_controller.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth()
    : super(
        const AuthState(
          activeAccount: AccountModel(uid: 'test', bduss: 'test', tbs: 'test'),
        ),
      );
  @override
  Future<String> getValidTbs({bool forceRefresh = false}) async => 'test';
  void changeAccount() => state = const AuthState(
    activeAccount: AccountModel(uid: 'other', bduss: 'other', tbs: 'other'),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Forums extends MyForumsRepository {
  _Forums() : super(TiebaDioClient());
  final signing = Completer<bool>();
  @override
  Future<bool> batchSignIn({required String tbs}) => signing.future;
  @override
  Future<List<FollowedForumModel>> getFollowedForums({
    required String uid,
  }) async => const [
    FollowedForumModel(id: '1', name: '测试', userLevel: 7),
    FollowedForumModel(id: '2', name: '低等级', userLevel: 6),
  ];
}

class _Forum extends ForumRepository {
  _Forum() : super(TiebaDioClient());
  @override
  Future<Map<String, dynamic>> getForumPage({
    required String forumName,
    String? forumId,
    required int page,
    int sortType = 0,
    int tabId = 0,
    int tabType = 0,
    String tabName = '',
    bool isGood = false,
  }) async => {
    'forum': const ForumDetailModel(id: '1', name: '测试', isLiked: true),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'batch completion updates an already-open forum and survives stale reads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final forums = _Forums();
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          authStateProvider.overrideWith((ref) => _Auth()),
          myForumsRepositoryProvider.overrideWithValue(forums),
          forumRepositoryProvider.overrideWithValue(_Forum()),
        ],
      );
      addTearDown(container.dispose);
      final list = container.read(myForumsControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final signing = list.batchSign();
      final detail = container.read(forumControllerFamily('测试').notifier);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(forumControllerFamily('测试')).forum!.isSigned,
        isFalse,
      );
      forums.signing.complete(true);
      expect(await signing, isTrue);
      expect(
        container.read(forumControllerFamily('测试')).forum!.isSigned,
        isTrue,
      );
      await detail.refresh();
      expect(
        container.read(forumControllerFamily('测试')).forum!.isSigned,
        isTrue,
      );
      expect(
        container.read(myForumsControllerProvider).forums.last.isSigned,
        isFalse,
      );
      expect(await detail.signIn(), isTrue);
    },
  );

  test(
    'explicit already-signed result succeeds but real failures remain failures',
    () {
      expect(isForumSignSuccess({'error_code': '0'}), isTrue);
      expect(
        isForumSignSuccess({'error_code': 1, 'error_msg': '您今天已经签到过了'}),
        isTrue,
      );
      expect(
        isForumSignSuccess({'error_code': 1, 'error_msg': '签到失败，请稍后重试'}),
        isFalse,
      );
      expect(
        isForumSignSuccess({'error_code': 1, 'error_msg': '未签到'}),
        isFalse,
      );
      expect(isForumSignSuccess(null), isFalse);
    },
  );

  test(
    'batch response cannot mark the replacement account as signed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final auth = _Auth();
      final forums = _Forums();
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          authStateProvider.overrideWith((ref) => auth),
          myForumsRepositoryProvider.overrideWithValue(forums),
        ],
      );
      addTearDown(container.dispose);
      final list = container.read(myForumsControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final signing = list.batchSign();
      await Future<void>.delayed(Duration.zero);
      auth.changeAccount();
      forums.signing.complete(true);
      expect(await signing, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(myForumsControllerProvider).forums.first.isSigned,
        isFalse,
      );
    },
  );

  testWidgets('completion toast stays at bottom while navigating', (
    tester,
  ) async {
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            source = context;
            return const Scaffold(body: Text('来源'));
          },
        ),
      ),
    );
    Navigator.of(source).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('贴吧'))),
    );
    AppToast.showBottom(source, '一键签到完成');
    await tester.pump();
    final before = tester.getRect(find.text('一键签到完成'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.getRect(find.text('一键签到完成')), before);
    expect(before.center.dy, greaterThan(500));
    await tester.pump(const Duration(seconds: 2));
  });
}

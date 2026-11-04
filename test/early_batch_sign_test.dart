import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/account_model.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/features/my_forums/data/models/followed_forum_model.dart';
import 'package:lurk/features/my_forums/data/my_forums_repository.dart';
import 'package:lurk/features/my_forums/presentation/my_forums_controller.dart';
import 'package:lurk/features/my_forums/presentation/my_forums_view.dart';
import 'package:lurk/features/profile/data/models/tieba_profile_model.dart';
import 'package:lurk/features/profile/data/profile_repository.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.data);
  final dynamic data;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(data),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth()
    : super(
        const AuthState(
          activeAccount: AccountModel(
            uid: 'test',
            bduss: 'synthetic',
            tbs: 'synthetic',
          ),
        ),
      );
  @override
  Future<String> getValidTbs({bool forceRefresh = false}) async {
    tbsCalls++;
    return 'synthetic';
  }

  int tbsCalls = 0;
  void changeAccount() => state = const AuthState(
    activeAccount: AccountModel(uid: 'other', bduss: 'synthetic-other'),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Forums extends MyForumsRepository {
  _Forums() : super(TiebaDioClient());
  int calls = 0;
  bool succeeds = true;
  Future<bool> Function()? signResponse;
  int listCalls = 0;
  Future<List<FollowedForumModel>> Function()? forumResponse;
  @override
  Future<bool> batchSignIn({required String tbs}) async {
    calls++;
    return signResponse == null ? succeeds : signResponse!();
  }

  @override
  Future<List<FollowedForumModel>> getFollowedForums({
    required String uid,
  }) async {
    listCalls++;
    return forumResponse == null
        ? const [
            FollowedForumModel(id: '1', name: '测试吧', userLevel: 7),
            FollowedForumModel(id: '2', name: '低等级吧', userLevel: 6),
          ]
        : forumResponse!();
  }
}

class _Profiles extends ProfileRepository {
  _Profiles() : super(TiebaDioClient());
  int calls = 0;
  Future<TiebaProfileModel?> Function(String)? response;
  @override
  Future<TiebaProfileModel?> getProfile({required String uid}) async {
    calls++;
    return response == null
        ? const TiebaProfileModel(id: 'test', name: 'fixture', isMember: false)
        : response!(uid);
  }
}

const _signedForums = [
  FollowedForumModel(id: '1', name: '测试吧', userLevel: 7, isSigned: true),
  FollowedForumModel(id: '2', name: '低等级吧', userLevel: 6),
];

Future<ProviderContainer> _container(
  _Forums forums,
  _Profiles profiles,
  _Auth auth,
  DateTime Function() clock,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      authStateProvider.overrideWith((ref) => auth),
      myForumsRepositoryProvider.overrideWithValue(forums),
      profileRepositoryProvider.overrideWithValue(profiles),
      batchSignNowProvider.overrideWithValue(clock),
    ],
  );
  container.read(myForumsControllerProvider);
  await Future<void>.value();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'batch repository accepts explicit completion but rejects actual errors',
    () async {
      for (final (data, expected) in <(dynamic, bool)>[
        ({'error_code': 0}, true),
        (
          {
            'error_code': '0',
            'error': {'errno': '0'},
          },
          true,
        ),
        (
          {
            'error_code': '0',
            'error': {
              'errno': '160002',
              'errmsg': 'synthetic permission denial',
            },
          },
          false,
        ),
        ({'error_code': 0, 'error': {}}, false),
        ({'error_code': 0, 'error': 'malformed'}, false),
        ({'error_code': 1}, false),
        ({'error_code': 1, 'error_msg': '您今天已经签到过了'}, true),
        ({'error_code': '1', 'error_msg': '您已完成今日签到'}, true),
        ({'error_code': 1, 'error_msg': '请勿重复一键签到'}, true),
        (
          {
            'error_code': 0,
            'error': {'errno': '160002', 'errmsg': '您今天已经签到过了'},
          },
          true,
        ),
        (
          {
            'error_code': 0,
            'error': {'errno': 1, 'errmsg': '今日已签到'},
          },
          true,
        ),
        (
          {
            'error_code': 0,
            'error': {'errno': 1, 'errmsg': '您已完成一键签到'},
          },
          true,
        ),
        (
          {
            'error_code': 1,
            'error_msg': '您今天已经签到过了',
            'error': {'errno': 2, 'errmsg': '权限不足'},
          },
          false,
        ),
        (
          {
            'error_code': 1,
            'error_msg': '登录失效',
            'error': {'errno': 1, 'errmsg': '今日已签到'},
          },
          false,
        ),
        ({'error_code': 1, 'error_msg': '部分贴吧已签到，仍有未签到的吧'}, false),
        ({'error_code': 1, 'error_msg': '一键签到未完成，请稍后重试'}, false),
        ({'error_code': 1, 'error_msg': '当前时段不支持一键签到'}, false),
        ({'error_code': 1, 'error_msg': '您已签到部分贴吧'}, false),
        ({'error_code': 1, 'error_msg': '今日已签到3个吧'}, false),
        ({'error_code': 1, 'error_msg': '您已签到，还有贴吧没签到'}, false),
        ({'error_code': 'bad', 'error_msg': '今日已签到'}, false),
        (
          {
            'error_code': 0,
            'error': {'errmsg': '今日已签到'},
          },
          false,
        ),
        (null, false),
      ]) {
        final client = TiebaDioClient();
        client.dio.httpClientAdapter = _ResponseAdapter(data);
        expect(
          await MyForumsRepository(client).batchSignIn(tbs: 'synthetic'),
          expected,
        );
        client.dio.close();
      }
    },
  );
  for (final nested in [false, true]) {
    testWidgets(
      'already-signed response ($nested) shows completion and keeps signs',
      (tester) async {
        final client = TiebaDioClient();
        client.dio.httpClientAdapter = _ResponseAdapter(
          nested
              ? {
                  'error_code': 0,
                  'error': {'errno': 1, 'errmsg': '您今天已经签到过了'},
                }
              : {'error_code': 1, 'error_msg': '您已完成今日签到'},
        );
        addTearDown(client.dio.close);
        final repository = MyForumsRepository(client);
        final forums = _Forums()
          ..signResponse = () => repository.batchSignIn(tbs: 'synthetic');
        final profiles = _Profiles();
        final container = await _container(
          forums,
          profiles,
          _Auth(),
          () => DateTime.utc(2026, 11, 4, 4),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MyForumsView()),
          ),
        );
        await tester.pumpAndSettle();
        for (var tap = 0; tap < 2; tap++) {
          await tester.tap(find.text('一键签到'));
          await tester.pumpAndSettle();
          expect(find.text('已完成签到（≥7级吧）'), findsOneWidget);
          expect(find.text('签到遇到问题，请重试'), findsNothing);
          final state = container.read(myForumsControllerProvider);
          expect(state.forums.first.isSigned, isTrue);
          expect(state.forums.last.isSigned, isFalse);
          expect(state.isSigning, isFalse);
          expect(forums.calls, 1);
          expect(profiles.calls, 0);
          await tester.pump(const Duration(seconds: 3));
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final hour in [4, 16]) {
    testWidgets(
      'one-click button with signed list at UTC $hour completes without a write',
      (tester) async {
        final forums = _Forums()..forumResponse = () async => _signedForums;
        final auth = _Auth();
        final profiles = _Profiles();
        final container = await _container(
          forums,
          profiles,
          auth,
          () => DateTime.utc(2026, 11, 4, hour),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MyForumsView()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('已签到'), findsOneWidget);
        for (var tap = 0; tap < 2; tap++) {
          await tester.tap(find.text('一键签到'));
          await tester.pumpAndSettle();
          expect(find.text('已完成签到（≥7级吧）'), findsOneWidget);
          expect(find.text('签到遇到问题，请重试'), findsNothing);
          expect(find.text(earlyBatchSignMessage), findsNothing);
          expect(forums.calls, 0);
          expect(forums.listCalls, 1);
          expect(auth.tbsCalls, 0);
          expect(profiles.calls, 0);
          await tester.pump(const Duration(seconds: 3));
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final lostResponse in [false, true]) {
    testWidgets(
      'one-click result is confirmed from fresh signs after unknown/lost response ($lostResponse)',
      (tester) async {
        final client = TiebaDioClient();
        client.dio.httpClientAdapter = _ResponseAdapter({
          'error_code': 0,
          'error': {'errno': 123456, 'errmsg': '当前操作不能重复执行'},
        });
        addTearDown(client.dio.close);
        final repository = MyForumsRepository(client);
        final forums = _Forums();
        forums.signResponse = () {
          if (lostResponse) throw StateError('synthetic lost response');
          return repository.batchSignIn(tbs: 'synthetic');
        };
        forums.forumResponse = () async => forums.listCalls == 1
            ? [
                for (final forum in _signedForums)
                  forum.copyWith(isSigned: false),
              ]
            : _signedForums;
        final container = await _container(
          forums,
          _Profiles(),
          _Auth(),
          () => DateTime.utc(2026, 11, 4, 4),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MyForumsView()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('一键签到'));
        await tester.pumpAndSettle();
        expect(find.text('已完成签到（≥7级吧）'), findsOneWidget);
        expect(find.text('签到遇到问题，请重试'), findsNothing);
        expect(forums.calls, 1);
        expect(forums.listCalls, 2);
        expect(
          container.read(myForumsControllerProvider).forums.first.isSigned,
          isTrue,
        );
        expect(
          container.read(myForumsControllerProvider).forums.last.isSigned,
          isFalse,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final failure in ['unsigned', 'missing-forum', 'empty', 'read-error']) {
    test('failed sign is not complete when verification is $failure', () async {
      final forums = _Forums()..succeeds = false;
      forums.forumResponse = () async {
        if (forums.listCalls == 1 || failure == 'unsigned') {
          return [
            const FollowedForumModel(id: '3', name: '另一个吧', userLevel: 8),
            for (final forum in _signedForums) forum.copyWith(isSigned: false),
          ];
        }
        if (failure == 'read-error') throw StateError('synthetic read failure');
        return failure == 'empty' ? [] : _signedForums;
      };
      final container = await _container(
        forums,
        _Profiles(),
        _Auth(),
        () => DateTime.utc(2026, 11, 4, 4),
      );
      addTearDown(container.dispose);
      expect(
        await container.read(myForumsControllerProvider.notifier).batchSign(),
        isFalse,
      );
      expect(forums.calls, 1);
      expect(forums.listCalls, 2);
      expect(container.read(myForumsControllerProvider).isSigning, isFalse);
      expect(container.read(myForumsControllerProvider).forums.length, 3);
      expect(container.read(myForumsControllerProvider).errorMessage, isNull);
    });
  }
  test(
    'yesterday signed list is not accepted after Beijing midnight',
    () async {
      var now = DateTime.utc(2026, 11, 4, 4);
      final forums = _Forums()..succeeds = false;
      forums.forumResponse = () async => forums.listCalls == 1
          ? _signedForums
          : [
              for (final forum in _signedForums)
                forum.copyWith(isSigned: false),
            ];
      final container = await _container(
        forums,
        _Profiles(),
        _Auth(),
        () => now,
      );
      addTearDown(container.dispose);
      now = now.add(const Duration(days: 1));
      expect(
        await container.read(myForumsControllerProvider.notifier).batchSign(),
        isFalse,
      );
      expect(forums.calls, 1);
      expect(forums.listCalls, 2);
    },
  );
  test(
    'list response started yesterday cannot enable completion fast path',
    () async {
      var now = DateTime.utc(2026, 11, 4, 15, 59);
      final pending = Completer<List<FollowedForumModel>>();
      final forums = _Forums()..succeeds = false;
      forums.forumResponse = () async => forums.listCalls == 1
          ? pending.future
          : [
              for (final forum in _signedForums)
                forum.copyWith(isSigned: false),
            ];
      final profiles = _Profiles()
        ..response = (_) async => const TiebaProfileModel(
          id: 'test',
          name: 'fixture',
          isMember: true,
        );
      final container = await _container(forums, profiles, _Auth(), () => now);
      addTearDown(container.dispose);
      now = now.add(const Duration(minutes: 2));
      pending.complete(_signedForums);
      await Future<void>.delayed(Duration.zero);
      expect(
        await container.read(myForumsControllerProvider.notifier).batchSign(),
        isFalse,
      );
      expect(forums.calls, 1);
      expect(forums.listCalls, 2);
    },
  );
  test(
    'verification discards old-account response and repeated taps do not queue',
    () async {
      final pending = Completer<List<FollowedForumModel>>();
      final forums = _Forums()..succeeds = false;
      forums.forumResponse = () async => forums.listCalls == 2
          ? pending.future
          : [
              for (final forum in _signedForums)
                forum.copyWith(isSigned: false),
            ];
      final auth = _Auth();
      final container = await _container(
        forums,
        _Profiles(),
        auth,
        () => DateTime.utc(2026, 11, 4, 4),
      );
      addTearDown(container.dispose);
      final controller = container.read(myForumsControllerProvider.notifier);
      final signing = controller.batchSign();
      await Future<void>.delayed(Duration.zero);
      expect(await controller.batchSign(), isFalse);
      expect(forums.calls, 1);
      auth.changeAccount();
      pending.complete(_signedForums);
      expect(await signing, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(myForumsControllerProvider).forums.first.isSigned,
        isFalse,
      );
    },
  );
  for (final signed in [false, true]) {
    test(
      'only low-level forums do not yield empty-set completion ($signed)',
      () async {
        final forums = _Forums()
          ..succeeds = false
          ..forumResponse = () async => [
            FollowedForumModel(
              id: '2',
              name: '低等级吧',
              userLevel: 6,
              isSigned: signed,
            ),
          ];
        final container = await _container(
          forums,
          _Profiles(),
          _Auth(),
          () => DateTime.utc(2026, 11, 4, 4),
        );
        addTearDown(container.dispose);
        expect(
          await container.read(myForumsControllerProvider.notifier).batchSign(),
          signed,
        );
        expect(forums.calls, signed ? 0 : 1);
      },
    );
  }
  test(
    'successful response across midnight requires current-day status',
    () async {
      var now = DateTime.utc(2026, 11, 4, 15, 59);
      final pending = Completer<bool>();
      final forums = _Forums()..signResponse = () => pending.future;
      final container = await _container(
        forums,
        _Profiles(),
        _Auth(),
        () => now,
      );
      addTearDown(container.dispose);
      final signing = container
          .read(myForumsControllerProvider.notifier)
          .batchSign();
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 2));
      pending.complete(true);
      expect(await signing, isFalse);
      expect(forums.calls, 1);
      expect(forums.listCalls, 2);
      expect(
        container.read(myForumsControllerProvider).forums.first.isSigned,
        isFalse,
      );
    },
  );
  test('Beijing window is inclusive at midnight and exclusive at 01:00', () {
    for (final (iso, early) in [
      ('2026-11-03T15:59:59Z', false),
      ('2026-11-03T16:00:00Z', true),
      ('2026-11-03T16:59:59.999Z', true),
      ('2026-11-03T17:00:00Z', false),
      ('2026-11-04T00:30:00+08:00', true),
      ('2026-11-03T11:30:00-05:00', true),
    ]) {
      expect(isEarlyBatchSignTime(DateTime.parse(iso)), early, reason: iso);
    }
  });
  test(
    'current membership is parsed without inferring from badges or level',
    () {
      for (final (value, expected) in [
        (0, false),
        ('0', false),
        (1, true),
        ('2', true),
        (null, null),
        ('bad', null),
        (-1, null),
      ]) {
        final profile = TiebaProfileModel.fromJson({
          'user': {
            'id': 'test',
            'name': 'fixture',
            'is_mem': value,
            'vip_level': 8,
          },
        });
        expect(profile.isMember, expected);
      }
    },
  );
  test(
    'ordinary user is blocked without sending sign request or mutating forums',
    () async {
      final forums = _Forums(), profiles = _Profiles();
      final container = await _container(
        forums,
        profiles,
        _Auth(),
        () => DateTime.utc(2026, 11, 3, 16, 30),
      );
      addTearDown(container.dispose);
      expect(
        await container.read(myForumsControllerProvider.notifier).batchSign(),
        isFalse,
      );
      final state = container.read(myForumsControllerProvider);
      expect(state.signMessage, earlyBatchSignMessage);
      expect(state.isSigning, isFalse);
      expect(state.forums.every((f) => !f.isSigned), isTrue);
      expect(profiles.calls, 1);
      expect(forums.calls, 0);
    },
  );
  test(
    'member can sign once at midnight with existing result handling',
    () async {
      final forums = _Forums();
      final profiles = _Profiles()
        ..response = (_) async => const TiebaProfileModel(
          id: 'test',
          name: 'fixture',
          isMember: true,
        );
      final container = await _container(
        forums,
        profiles,
        _Auth(),
        () => DateTime.utc(2026, 11, 3, 16, 30),
      );
      addTearDown(container.dispose);
      expect(
        await container.read(myForumsControllerProvider.notifier).batchSign(),
        isTrue,
      );
      expect(forums.calls, 1);
      final state = container.read(myForumsControllerProvider);
      expect(state.signMessage, isNull);
      expect(state.forums.first.isSigned, isTrue);
      expect(state.forums.last.isSigned, isFalse);
    },
  );
  for (final hour in [15, 17]) {
    test(
      'outside restricted window at UTC $hour adds no membership request',
      () async {
        final forums = _Forums(), profiles = _Profiles();
        final container = await _container(
          forums,
          profiles,
          _Auth(),
          () => DateTime.utc(2026, 11, 3, hour),
        );
        addTearDown(container.dispose);
        expect(
          await container.read(myForumsControllerProvider.notifier).batchSign(),
          isTrue,
        );
        expect(profiles.calls, 0);
        expect(forums.calls, 1);
      },
    );
  }
  for (final fallback in ['missing', 'failed', 'wrong-user']) {
    for (final succeeds in [true, false]) {
      test(
        'unknown status ($fallback) leaves final permission to server ($succeeds)',
        () async {
          final forums = _Forums()..succeeds = succeeds;
          final profiles = _Profiles()
            ..response = (_) async {
              if (fallback == 'failed') {
                throw StateError('synthetic read failure');
              }
              return TiebaProfileModel(
                id: fallback == 'wrong-user' ? 'other' : 'test',
                name: 'fixture',
                isMember: fallback == 'wrong-user' ? false : null,
              );
            };
          final container = await _container(
            forums,
            profiles,
            _Auth(),
            () => DateTime.utc(2026, 11, 3, 16, 30),
          );
          addTearDown(container.dispose);
          expect(
            await container
                .read(myForumsControllerProvider.notifier)
                .batchSign(),
            succeeds,
          );
          expect(forums.calls, 1);
          final state = container.read(myForumsControllerProvider);
          expect(state.isSigning, isFalse);
          expect(state.signMessage, succeeds ? isNull : contains('一键签到未完成'));
        },
      );
    }
  }
  test(
    'account change during membership request discards old response',
    () async {
      final pending = Completer<TiebaProfileModel?>();
      final forums = _Forums();
      final profiles = _Profiles()..response = (_) => pending.future;
      final auth = _Auth();
      final container = await _container(
        forums,
        profiles,
        auth,
        () => DateTime.utc(2026, 11, 3, 16, 30),
      );
      addTearDown(container.dispose);
      final sign = container
          .read(myForumsControllerProvider.notifier)
          .batchSign();
      await Future<void>.delayed(Duration.zero);
      auth.changeAccount();
      pending.complete(
        const TiebaProfileModel(id: 'test', name: 'fixture', isMember: false),
      );
      expect(await sign, isFalse);
      expect(forums.calls, 0);
      expect(container.read(myForumsControllerProvider).signMessage, isNull);
    },
  );
  test('01:00 rollover while lookup is pending allows sign and repeated taps do not queue', () async {
    final pending = Completer<TiebaProfileModel?>();
    final forums = _Forums();
    final profiles = _Profiles()..response = (_) => pending.future;
    var now = DateTime.utc(2026, 11, 3, 16, 59, 59);
    final container = await _container(forums, profiles, _Auth(), () => now);
    addTearDown(container.dispose);
    final controller = container.read(myForumsControllerProvider.notifier);
    final sign = controller.batchSign();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.batchSign(), isFalse);
    expect(profiles.calls, 1);
    now = DateTime.utc(2026, 11, 3, 17);
    pending.complete(
      const TiebaProfileModel(id: 'test', name: 'fixture', isMember: false),
    );
    expect(await sign, isTrue);
    expect(forums.calls, 1);
    expect(container.read(myForumsControllerProvider).signMessage, isNull);
  });
  test('previous restriction clears on retry after 01:00', () async {
    final forums = _Forums(), profiles = _Profiles();
    var now = DateTime.utc(2026, 11, 3, 16, 30);
    final container = await _container(forums, profiles, _Auth(), () => now);
    addTearDown(container.dispose);
    final controller = container.read(myForumsControllerProvider.notifier);
    expect(await controller.batchSign(), isFalse);
    expect(
      container.read(myForumsControllerProvider).signMessage,
      earlyBatchSignMessage,
    );
    now = DateTime.utc(2026, 11, 3, 17);
    expect(await controller.batchSign(), isTrue);
    expect(profiles.calls, 1);
    expect(forums.calls, 1);
    expect(container.read(myForumsControllerProvider).signMessage, isNull);
  });
  testWidgets(
    'actual action displays time restriction at bottom and retains list',
    (tester) async {
      final forums = _Forums(), profiles = _Profiles();
      final container = await _container(
        forums,
        profiles,
        _Auth(),
        () => DateTime.utc(2026, 11, 3, 16, 30),
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MyForumsView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('一键签到'));
      await tester.pumpAndSettle();
      expect(find.text(earlyBatchSignMessage), findsOneWidget);
      expect(find.text('签到遇到问题，请重试'), findsNothing);
      expect(find.text('测试吧'), findsOneWidget);
      expect(forums.calls, 0);
      expect(
        tester.getRect(find.text(earlyBatchSignMessage)).bottom,
        greaterThan(800),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}

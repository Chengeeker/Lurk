import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/account_model.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/services/webdav_service.dart';
import 'package:lurk/features/settings/presentation/webdav_backup_page.dart';

class _Secure extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  int reads = 0, writes = 0;
  bool fail = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      reads++;
      return fail
          ? Future<String?>.error(StateError('unavailable'))
          : Future<String?>.value(values[invocation.namedArguments[#key]]);
    }
    if (invocation.memberName == #write) {
      writes++;
      if (fail) return Future<void>.error(StateError('unavailable'));
      values[invocation.namedArguments[#key] as String] =
          invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

const _account = AccountModel(
  uid: 'fake-user',
  bduss: 'fake-cookie',
  stoken: 'fake-token',
  tbs: 'fake-tbs',
  baiduid: 'fake-baiduid',
);
Future<StorageService> _storage(_Secure secure) async {
  SharedPreferences.setMockInitialValues({
    StorageService.keyThemeMode: 2,
    StorageService.keyWebDavUrl: 'https://example.com/dav',
    StorageService.keyWebDavUsername: 'fake-user',
    StorageService.keyWebDavPassword: 'fake-webdav-password',
    StorageService.keyWebDavDirectory: 'Lurk',
    StorageService.keyActiveAccountUid: _account.uid,
    StorageService.keyAccounts: [jsonEncode(_account.toJson())],
    StorageService.keyBrowsingHistory: ['history'],
    StorageService.bookmarksKeyForAccount(_account.uid): ['bookmark'],
    'unknown_secret': 'not-allowed',
  });
  secure.values[StorageService.secureAccountsKey] = jsonEncode([
    jsonEncode(_account.toJson()),
  ]);
  return StorageService(
    await SharedPreferences.getInstance(),
    secureStorage: secure,
  );
}

class _Dav extends WebDavService {
  final uploads = <Map<String, dynamic>>[];
  Map<String, dynamic>? download;
  @override
  Future<Map<String, dynamic>?> downloadLatestBackup({
    required String serverUrl,
    required String username,
    required String password,
    required String directoryName,
  }) async => download;
  @override
  Future<bool> uploadBackup({
    required String serverUrl,
    required String username,
    required String password,
    required String directoryName,
    required Map<String, dynamic> data,
  }) async {
    uploads.add(data);
    return true;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (stream != null) {
      bodies.add(utf8.decode(await stream.expand((bytes) => bytes).toList()));
    }
    return ResponseBody.fromString(
      options.method == 'GET' ? '{"app":"Lurk"}' : '',
      options.method == 'PROPFIND'
          ? 207
          : options.method == 'GET'
          ? 200
          : options.method == 'MKCOL'
          ? 201
          : 204,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('full export includes legacy accounts when secure list is empty and rejects conflicting copies', () async {
    final secure = _Secure();
    final storage = await _storage(secure);
    secure.values[StorageService.secureAccountsKey] = '[]';
    final full = await storage.exportAllData(includeCredentials: true);
    expect(
      (full['preferences'] as Map)[StorageService.keyAccounts],
      hasLength(1),
    );
    secure.values[StorageService.secureAccountsKey] = jsonEncode([
      jsonEncode(_account.copyWith(bduss: 'different').toJson()),
    ]);
    await expectLater(
      storage.exportAllData(includeCredentials: true),
      throwsStateError,
    );
  });
  testWidgets(
    'restore confirmation applies the downloaded full backup independent of upload selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final secure = _Secure();
      final storage = await _storage(secure);
      final full = await storage.exportAllData(includeCredentials: true);
      await storage.setWebDavPassword('current-password');
      final dav = _Dav()..download = full;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            webDavServiceProvider.overrideWithValue(dav),
          ],
          child: const MaterialApp(home: WebDavBackupPage()),
        ),
      );
      await tester.tap(find.text('从云端恢复备份'));
      await tester.pumpAndSettle();
      expect(find.textContaining('还会替换贴吧登录凭据及 WebDAV 密码'), findsOneWidget);
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();
      expect(storage.getWebDavPassword(), 'fake-webdav-password');
      expect(secure.writes, 1);
    },
  );
  test(
    'safe backup excludes credentials without reading secure storage',
    () async {
      final secure = _Secure();
      final storage = await _storage(secure);
      final data = await storage.exportAllData();
      expect(secure.reads, 0);
      expect(data['backup_mode'], 'safe');
      final prefs = data['preferences'] as Map;
      expect(prefs[StorageService.keyBrowsingHistory], ['history']);
      expect(prefs[StorageService.bookmarksKeyForAccount(_account.uid)], [
        'bookmark',
      ]);
      for (final key in [
        StorageService.keyAccounts,
        StorageService.keyActiveAccountUid,
        StorageService.keyWebDavPassword,
        'unknown_secret',
      ]) {
        expect(prefs.containsKey(key), isFalse);
      }
      expect(jsonEncode(data), isNot(contains('fake-cookie')));
      expect(jsonEncode(data), isNot(contains('fake-webdav-password')));
    },
  );
  test('full backup restores credentials as one secure group', () async {
    final secure = _Secure();
    final storage = await _storage(secure);
    final full = await storage.exportAllData(includeCredentials: true);
    final prefs = full['preferences'] as Map;
    expect(
      (jsonDecode((prefs[StorageService.keyAccounts] as List).single)
          as Map)['stoken'],
      'fake-token',
    );
    expect(prefs[StorageService.keyWebDavPassword], 'fake-webdav-password');
    await storage.setWebDavPassword('replacement');
    secure.values[StorageService.secureAccountsKey] = '[]';
    await storage.restoreAllData(full);
    expect(storage.getWebDavPassword(), 'fake-webdav-password');
    expect(storage.getStringList(StorageService.keyAccounts), isEmpty);
    final restored =
        jsonDecode(secure.values[StorageService.secureAccountsKey]!) as List;
    expect(jsonDecode(restored.single)['bduss'], 'fake-cookie');
  });
  test(
    'safe restore ignores injected credentials and keeps local login/password',
    () async {
      final secure = _Secure();
      final storage = await _storage(secure);
      final data = await storage.exportAllData();
      (data['preferences'] as Map).addAll(<String, dynamic>{
        StorageService.keyWebDavPassword: 'injected',
        StorageService.keyAccounts: ['bad'],
      });
      final before = secure.values[StorageService.secureAccountsKey];
      await storage.restoreAllData(data);
      expect(storage.getWebDavPassword(), 'fake-webdav-password');
      expect(secure.values[StorageService.secureAccountsKey], before);
      expect(secure.writes, 0);
    },
  );
  test(
    'invalid full backup fails before any settings or credentials are written',
    () async {
      final secure = _Secure();
      final storage = await _storage(secure);
      final data = await storage.exportAllData(includeCredentials: true);
      (data['preferences'] as Map)[StorageService.keyThemeMode] = 'bad';
      await expectLater(storage.restoreAllData(data), throwsFormatException);
      expect(storage.getInt(StorageService.keyThemeMode), 2);
      expect(secure.writes, 0);
      (data['preferences'] as Map)[StorageService.keyThemeMode] = 1;
      (data['preferences'] as Map)[StorageService.keyActiveAccountUid] =
          'wrong';
      await expectLater(storage.restoreAllData(data), throwsFormatException);
      expect(storage.getInt(StorageService.keyThemeMode), 2);
      expect(secure.writes, 0);
    },
  );
  test('failed secure access never creates an incomplete full backup or restores settings', () async {
    final secure = _Secure();
    final storage = await _storage(secure);
    final full = await storage.exportAllData(includeCredentials: true);
    secure.fail = true;
    await expectLater(
      storage.exportAllData(includeCredentials: true),
      throwsStateError,
    );
    (full['preferences'] as Map)[StorageService.keyThemeMode] = 1;
    await expectLater(storage.restoreAllData(full), throwsStateError);
    expect(storage.getInt(StorageService.keyThemeMode), 2);
  });
  test(
    'WebDAV uses Lurk filenames and matching JSON for latest and history',
    () async {
      final dio = Dio();
      final adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      final service = WebDavService(dio);
      expect(
        await service.testConnection(
          serverUrl: 'https://example.com/dav',
          username: 'fake',
          password: 'fake',
        ),
        isTrue,
      );
      expect(
        await service.uploadBackup(
          serverUrl: 'https://example.com/dav',
          username: 'fake',
          password: 'fake',
          directoryName: '自定义',
          data: {'backup_mode': 'safe'},
        ),
        isTrue,
      );
      final puts = adapter.requests.where((r) => r.method == 'PUT').toList();
      expect(puts.length, 2);
      expect(puts.first.uri.pathSegments.last, 'backup_lurk_latest.json');
      expect(
        adapter.bodies.map(jsonDecode).every((d) => d['backup_mode'] == 'safe'),
        isTrue,
      );
      expect(
        WebDavService.isSecureUrl('http://localhost.evil.example'),
        isFalse,
      );
      expect(WebDavService.isSecureUrl('http://127.0.0.1:8080/dav'), isTrue);
      expect(WebDavService.isSecureUrl('https://example.com/dav'), isTrue);
    },
  );
  testWidgets(
    'Review-aligned page defaults to safe and full is an explicit selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final secure = _Secure();
      final storage = await _storage(secure);
      final dav = _Dav();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            webDavServiceProvider.overrideWithValue(dav),
          ],
          child: const MaterialApp(home: WebDavBackupPage()),
        ),
      );
      expect(find.text('全量安全备份'), findsOneWidget);
      expect(find.text('全量备份'), findsOneWidget);
      await tester.tap(find.text('立即备份到云端'));
      await tester.pumpAndSettle();
      expect(dav.uploads.single['backup_mode'], 'safe');
      expect(secure.reads, 0);
      await tester.tap(find.text('全量备份'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('立即备份到云端'));
      await tester.pumpAndSettle();
      expect(dav.uploads.last['backup_mode'], 'full');
      expect(
        (dav.uploads.last['preferences']
            as Map)[StorageService.keyWebDavPassword],
        'fake-webdav-password',
      );
    },
  );
}

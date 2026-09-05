import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/tieba_constants.dart';
import '../network/sign_interceptor.dart';
import '../storage/storage_service.dart';
import 'account_model.dart';

class AuthState {
  final List<AccountModel> accounts;
  final AccountModel? activeAccount;
  final bool isLoading;

  const AuthState({
    this.accounts = const [],
    this.activeAccount,
    this.isLoading = false,
  });

  bool get isLogin => activeAccount != null && activeAccount!.isLogin;
  bool get isLoggedIn => isLogin;
  String get tbs => activeAccount?.tbs ?? '';

  AuthState copyWith({
    List<AccountModel>? accounts,
    AccountModel? activeAccount,
    bool clearActiveAccount = false,
    bool? isLoading,
  }) {
    return AuthState(
      accounts: accounts ?? this.accounts,
      activeAccount: clearActiveAccount
          ? null
          : (activeAccount ?? this.activeAccount),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const _secureAccountsKey = 'lurk_auth_accounts_v1';
  final StorageService _storage;
  final FlutterSecureStorage _secureStorage;

  AuthNotifier(this._storage)
    : _secureStorage = const FlutterSecureStorage(),
      super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    var list = <String>[];
    try {
      final secureJson = await _secureStorage.read(key: _secureAccountsKey);
      if (secureJson != null && secureJson.isNotEmpty) {
        final decoded = jsonDecode(secureJson);
        if (decoded is List) {
          list = decoded.whereType<String>().toList();
        }
      }
    } catch (_) {}

    if (list.isEmpty) {
      list = _storage.getStringList(StorageService.keyAccounts);
      if (list.isNotEmpty) {
        try {
          await _secureStorage.write(
            key: _secureAccountsKey,
            value: jsonEncode(list),
          );
          await _storage.remove(StorageService.keyAccounts);
        } catch (_) {
          // Keep the legacy copy if secure storage is unavailable.
        }
      }
    }

    final activeUid = _storage.getString(StorageService.keyActiveAccountUid);

    final accounts = list
        .map((e) {
          try {
            return AccountModel.fromJson(jsonDecode(e));
          } catch (_) {
            return null;
          }
        })
        .whereType<AccountModel>()
        .toList();

    AccountModel? active;
    if (accounts.isNotEmpty) {
      active = accounts.firstWhere(
        (a) => a.uid == activeUid,
        orElse: () => accounts.first,
      );
    }

    await _storage.setString(
      StorageService.keyActiveAccountName,
      active?.displayName ?? '',
    );
    state = state.copyWith(accounts: accounts, activeAccount: active);
  }

  Future<void> _saveToStorage() async {
    final list = state.accounts.map((e) => jsonEncode(e.toJson())).toList();
    try {
      await _secureStorage.write(
        key: _secureAccountsKey,
        value: jsonEncode(list),
      );
      await _storage.remove(StorageService.keyAccounts);
    } catch (_) {
      // Preserve compatibility on platforms without a secure-storage backend.
      await _storage.setStringList(StorageService.keyAccounts, list);
    }
    if (state.activeAccount != null) {
      await _storage.setString(
        StorageService.keyActiveAccountUid,
        state.activeAccount!.uid,
      );
      await _storage.setString(
        StorageService.keyActiveAccountName,
        state.activeAccount!.displayName,
      );
    } else {
      await _storage.setString(StorageService.keyActiveAccountUid, '');
      await _storage.setString(StorageService.keyActiveAccountName, '');
    }
  }

  Future<bool> loginWithCookieString(String cookieStr) async {
    state = state.copyWith(isLoading: true);
    try {
      String bduss = '';
      String stoken = '';
      String baiduid = '';

      final parts = cookieStr.split(';');
      for (var part in parts) {
        final pair = part.trim().split('=');
        if (pair.length >= 2) {
          final key = pair[0].trim();
          final val = pair.sublist(1).join('=').trim();
          if (key == 'BDUSS' || key == 'BDUSS_BFESS') {
            if (bduss.isEmpty) bduss = val;
          } else if (key == 'STOKEN') {
            if (stoken.isEmpty) stoken = val;
          } else if (key == 'BAIDUID' || key == 'BAIDUID_BFESS') {
            if (baiduid.isEmpty) baiduid = val;
          }
        }
      }

      if (bduss.isEmpty) {
        bduss = cookieStr.trim();
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: TiebaConstants.baseNativeUrl,
          headers: {
            'User-Agent': TiebaConstants.defaultUserAgent,
            'Host': 'c.tieba.baidu.com',
            'Cookie': 'ka=open; BDUSS=$bduss; STOKEN=$stoken; BAIDUID=$baiduid',
            'client_logid': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dio.interceptors.add(SignInterceptor());

      final res = await dio.post(
        TiebaConstants.pathLogin,
        data: {'bdusstoken': bduss, 'BDUSS': bduss, 'stoken': stoken},
      );

      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map &&
          (data['error_code'] == 0 || data['error_code'] == '0')) {
        final user = data['user'] as Map<String, dynamic>?;
        final anti = data['anti'] as Map<String, dynamic>?;

        final uid =
            user?['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        String name = user?['name']?.toString() ?? '';
        final portrait = user?['portrait']?.toString() ?? '';
        final tbs = anti?['tbs']?.toString() ?? '';

        // If name is empty, fetch user profile to retrieve accurate display name
        if (name.isEmpty && uid.isNotEmpty) {
          try {
            final profRes = await dio.post(
              TiebaConstants.pathProfile,
              data: {'uid': uid, 'need_post_count': '1'},
            );
            dynamic profData = profRes.data;
            if (profData is String) {
              try {
                profData = jsonDecode(profData);
              } catch (_) {}
            }
            if (profData is Map) {
              final profUser = profData['user'] as Map<String, dynamic>?;
              name =
                  profUser?['name_show']?.toString() ??
                  profUser?['name']?.toString() ??
                  '';
            }
          } catch (_) {}
        }

        final newAccount = AccountModel(
          uid: uid,
          name: name,
          nameShow: name,
          portrait: portrait,
          bduss: bduss,
          stoken: stoken,
          baiduid: baiduid,
          tbs: tbs,
          isLogin: true,
        );

        final updatedList = List<AccountModel>.from(
          state.accounts.where((a) => a.uid != uid),
        )..add(newAccount);
        state = state.copyWith(
          accounts: updatedList,
          activeAccount: newAccount,
          isLoading: false,
        );
        await _saveToStorage();
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> switchAccount(AccountModel account) async {
    state = state.copyWith(activeAccount: account);
    await _saveToStorage();
  }

  Future<void> logout() async {
    if (state.activeAccount == null) return;
    final updatedList = state.accounts
        .where((a) => a.uid != state.activeAccount!.uid)
        .toList();
    AccountModel? nextActive = updatedList.isNotEmpty
        ? updatedList.first
        : null;
    state = state.copyWith(
      accounts: updatedList,
      activeAccount: nextActive,
      clearActiveAccount: nextActive == null,
    );
    await _saveToStorage();
  }

  Future<String> getValidTbs({bool forceRefresh = false}) async {
    final account = state.activeAccount;
    if (account == null || !account.isLogin) return '';

    if (!forceRefresh && account.tbs.isNotEmpty) {
      return account.tbs;
    }

    // 1. 优先通过客户端原生 /c/s/login 接口刷新，获取移动端权威 anti.tbs
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: TiebaConstants.baseNativeUrl,
          headers: {
            'User-Agent': TiebaConstants.defaultUserAgent,
            'Host': 'c.tieba.baidu.com',
            'Cookie':
                'ka=open; BDUSS=${account.bduss}; STOKEN=${account.stoken}; BAIDUID=${account.baiduid}',
          },
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      dio.interceptors.add(SignInterceptor());

      final res = await dio.post(
        TiebaConstants.pathLogin,
        data: {
          'bdusstoken': account.bduss,
          'BDUSS': account.bduss,
          'stoken': account.stoken,
        },
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map &&
          (data['error_code'] == 0 || data['error_code'] == '0')) {
        final anti = data['anti'] as Map<String, dynamic>?;
        final newTbs = anti?['tbs']?.toString() ?? '';
        if (newTbs.isNotEmpty) {
          final updated = account.copyWith(tbs: newTbs);
          final updatedList = state.accounts
              .map((a) => a.uid == account.uid ? updated : a)
              .toList();
          state = state.copyWith(accounts: updatedList, activeAccount: updated);
          await _saveToStorage();
          return newTbs;
        }
      }
    } catch (_) {}

    // 2. 兜底通过 Web 接口刷新，但必须校验 is_login == 1，严禁使用未登录的匿名 TBS
    try {
      final dio = Dio(
        BaseOptions(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://tieba.baidu.com/',
            'Cookie':
                'BDUSS=${account.bduss}; STOKEN=${account.stoken}; BAIDUID=${account.baiduid}',
          },
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final res = await dio.get('https://tieba.baidu.com/dc/common/tbs');
      final data = res.data is String ? jsonDecode(res.data) : res.data;
      if (data is Map && (data['is_login'] == 1 || data['is_login'] == '1')) {
        final newTbs = data['tbs']?.toString() ?? '';
        if (newTbs.isNotEmpty) {
          final updated = account.copyWith(tbs: newTbs);
          final updatedList = state.accounts
              .map((a) => a.uid == account.uid ? updated : a)
              .toList();
          state = state.copyWith(accounts: updatedList, activeAccount: updated);
          await _saveToStorage();
          return newTbs;
        }
      }
    } catch (_) {}

    return account.tbs;
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(storage);
});

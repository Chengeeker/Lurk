import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/account_model.dart';

class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const secureAccountsKey = 'lurk_auth_accounts_v1';
  static const keyWebDavUrl = 'key_webdav_url';
  static const keyWebDavUsername = 'key_webdav_username';
  static const keyWebDavPassword = 'key_webdav_password';
  static const keyWebDavDirectory = 'key_webdav_directory';
  String getWebDavUrl() => getString(keyWebDavUrl);
  String getWebDavUsername() => getString(keyWebDavUsername);
  String getWebDavPassword() => getString(keyWebDavPassword);
  String getWebDavDirectory() =>
      getString(keyWebDavDirectory, defaultValue: 'Lurk');
  Future<bool> setWebDavUrl(String value) => setString(keyWebDavUrl, value);
  Future<bool> setWebDavUsername(String value) =>
      setString(keyWebDavUsername, value);
  Future<bool> setWebDavPassword(String value) =>
      setString(keyWebDavPassword, value);
  Future<bool> setWebDavDirectory(String value) =>
      setString(keyWebDavDirectory, value);

  static const _backupBools = {
    keyUseDynamicColor,
    keyIsPureBlackDark,
    keyEnableHaptics,
    keyUseFloatingNavBar,
    keyUseLiquidGlass,
    keyShowFps,
    keyHideBlockedCompletely,
    keyBlockVideoThreads,
    keyRecommendFollowedOnly,
    keyUseInternalBrowser,
    keyHabitAutoLoadMore,
    keyHabitDoubleTapTop,
    keyHabitShowOriginalImg,
    keyHabitDoubleTapFeedRefresh,
    keyHabitDoNotSaveHistory,
    keyMyForumsSingleColumn,
    keyAutoClearCacheOnExit,
    keyBookmarkSortOrder,
  };
  static const _backupInts = {
    keyThemeMode,
    keyThemeColorIndex,
    keyFontWeightIndex,
    keyFontSizePercent,
    keyRefreshRateIndex,
    keyHabitInitialTabIndex,
    keyHabitImageLoadMode,
    keyHabitForumDefaultSort,
    keyImageSavePathType,
    keyVideoSavePathType,
    keyAutoClearCacheThresholdMb,
  };
  static const _backupLists = {
    keyBookmarks,
    keyBookmarkPendingAdds,
    keyBookmarkPendingRemoves,
    keyBrowsingHistory,
    keyForumBrowsingHistory,
    keyBlockWords,
    keyWhiteWords,
  };
  static const _backupStrings = {
    keyWebDavUrl,
    keyWebDavUsername,
    keyWebDavDirectory,
  };
  static const _credentials = {
    keyAccounts,
    keyActiveAccountUid,
    keyActiveAccountName,
    keyWebDavPassword,
  };

  static bool _isBackupList(String key) =>
      _backupLists.contains(key) ||
      [keyBookmarks, keyBookmarkPendingAdds, keyBookmarkPendingRemoves].any(
        (prefix) =>
            key.startsWith('${prefix}_') &&
            RegExp(r'^[a-zA-Z0-9_-]+$')
                .hasMatch(key.substring(prefix.length + 1)),
      );
  static bool _allowedBackupKey(String key) =>
      _backupBools.contains(key) ||
      _backupInts.contains(key) ||
      _backupStrings.contains(key) ||
      _isBackupList(key);

  static List<AccountModel> _validateAccounts(dynamic raw, dynamic activeUid) {
    if (raw is! List ||
        raw.any((item) => item is! String) ||
        activeUid is! String) {
      throw const FormatException('无效的备份账号');
    }
    final accounts = <AccountModel>[];
    final ids = <String>{};
    for (final item in raw) {
      final map = jsonDecode(item as String);
      if (map is! Map<String, dynamic> ||
          map['uid'] is! String ||
          (map['uid'] as String).isEmpty ||
          map['bduss'] is! String ||
          !ids.add(map['uid'] as String)) {
        throw const FormatException('无效的备份账号');
      }
      for (final key in [
        'name',
        'nameShow',
        'portrait',
        'stoken',
        'baiduid',
        'tbs',
      ]) {
        if (map[key] != null && map[key] is! String) {
          throw const FormatException('无效的账号字段');
        }
      }
      if (map['isLogin'] != null && map['isLogin'] is! bool) {
        throw const FormatException('无效的登录状态');
      }
      accounts.add(AccountModel.fromJson(map));
    }
    if ((accounts.isEmpty && activeUid.isNotEmpty) ||
        (accounts.isNotEmpty && !ids.contains(activeUid))) {
      throw const FormatException('备份的当前账号不匹配');
    }
    return accounts;
  }

  Future<Map<String, dynamic>> exportAllData({
    bool includeCredentials = false,
  }) async {
    final preferences = <String, dynamic>{
      for (final key in _prefs.getKeys())
        if (_allowedBackupKey(key)) key: _prefs.get(key),
    };
    if (includeCredentials) {
      // A failed secure read must not produce an apparently complete backup.
      final secure = await _secureStorage.read(key: secureAccountsKey);
      final legacy = getStringList(keyAccounts);
      var raw = secure == null ? legacy : jsonDecode(secure);
      if (raw is List && raw.isEmpty && legacy.isNotEmpty) {
        raw = legacy;
      } else if (secure != null &&
          legacy.isNotEmpty &&
          jsonEncode(raw) != jsonEncode(legacy)) {
        throw StateError('账号存储不一致，无法生成完整备份');
      }
      var active = getString(keyActiveAccountUid);
      if (raw is List && raw.isEmpty) active = '';
      if (active.isEmpty &&
          raw is List &&
          raw.isNotEmpty &&
          raw.first is String) {
        final first = jsonDecode(raw.first as String);
        if (first is Map && first['uid'] is String) {
          active = first['uid'] as String;
        }
      }
      final accounts = _validateAccounts(raw, active);
      preferences.addAll({
        keyAccounts: accounts.map((a) => jsonEncode(a.toJson())).toList(),
        keyActiveAccountUid: active,
        keyActiveAccountName: accounts.isEmpty
            ? ''
            : accounts.firstWhere((a) => a.uid == active).displayName,
        keyWebDavPassword: getWebDavPassword(),
      });
    }
    return {
      'app': 'Lurk',
      'version': '2.0',
      'backup_mode': includeCredentials ? 'full' : 'safe',
      'exported_at': DateTime.now().toIso8601String(),
      'preferences': preferences,
    };
  }

  Map<String, dynamic> _validatedPreferences(Map<String, dynamic> data) {
    if (data['app'] != 'Lurk' ||
        data['version'] != '2.0' ||
        !['safe', 'full'].contains(data['backup_mode']) ||
        data['preferences'] is! Map<String, dynamic>) {
      throw const FormatException('无效的 Lurk 备份');
    }
    final full = data['backup_mode'] == 'full';
    final prefs = Map<String, dynamic>.from(data['preferences'] as Map);
    for (final entry in prefs.entries) {
      final key = entry.key;
      if (!_allowedBackupKey(key) && !(full && _credentials.contains(key))) {
        continue;
      }
      final v = entry.value;
      final valid = _backupBools.contains(key)
          ? v is bool
          : _backupInts.contains(key)
          ? v is int
          : (_isBackupList(key) || key == keyAccounts)
          ? v is List && v.every((x) => x is String)
          : v is String;
      if (!valid) throw const FormatException('无效的备份设置');
    }
    if (full) {
      if (!_credentials.every(prefs.containsKey)) {
        throw const FormatException('全量备份缺少凭据组');
      }
      _validateAccounts(prefs[keyAccounts], prefs[keyActiveAccountUid]);
    }
    return prefs;
  }

  Future<void> restoreAllData(Map<String, dynamic> data) async {
    // Validate the entire document before replacing any local data.
    final prefs = _validatedPreferences(data);
    final full = data['backup_mode'] == 'full';
    if (full) {
      await _secureStorage.write(
        key: secureAccountsKey,
        value: jsonEncode(prefs[keyAccounts]),
      );
      if (!await _prefs.remove(keyAccounts)) throw StateError('旧凭据清理失败');
    }
    for (final entry in prefs.entries) {
      if (entry.key == keyAccounts ||
          (!_allowedBackupKey(entry.key) &&
              !(full && _credentials.contains(entry.key)))) {
        continue;
      }
      final v = entry.value;
      final saved = v is bool
          ? await _prefs.setBool(entry.key, v)
          : v is int
          ? await _prefs.setInt(entry.key, v)
          : v is String
          ? await _prefs.setString(entry.key, v)
          : await _prefs.setStringList(entry.key, List<String>.from(v as List));
      if (!saved) throw StateError('备份数据写入失败');
    }
  }

  static const String keyThemeMode = 'key_theme_mode';
  static const String keyUseDynamicColor = 'key_use_dynamic_color';
  static const String keyThemeColorIndex = 'key_theme_color_index';
  static const String keyIsPureBlackDark = 'key_is_pure_black_dark';
  static const String keyEnableHaptics = 'key_enable_haptics';
  static const String keyUseFloatingNavBar = 'key_use_floating_nav_bar';
  static const String keyUseLiquidGlass = 'key_use_liquid_glass_effect';
  static const String keyFontWeightIndex = 'key_font_weight_index';
  static const String keyFontSizePercent = 'key_font_size_percent';
  static const String keyShowFps = 'key_show_fps';

  static const String keyAccounts = 'key_accounts_list';
  static const String keyActiveAccountUid = 'key_active_account_uid';
  static const String keyActiveAccountName = 'key_active_account_name';
  static const String keyBookmarks = 'key_bookmarks_list';
  static const String keyBookmarkPendingAdds = 'key_bookmark_pending_adds';
  static const String keyBookmarkPendingRemoves =
      'key_bookmark_pending_removes';
  static const String keyBrowsingHistory = 'key_browsing_history_list';
  static const String keyForumBrowsingHistory =
      'key_forum_browsing_history_list';

  static const String keyBlockWords = 'key_block_words_list';
  static const String keyWhiteWords = 'key_white_words_list';
  static const String keyHideBlockedCompletely = 'key_hide_blocked_completely';
  static const String keyBlockVideoThreads = 'key_block_video_threads';
  static const String keyRecommendFollowedOnly = 'key_recommend_followed_only';

  static const String keyUseInternalBrowser = 'key_use_internal_browser';

  static const String keyHabitAutoLoadMore = 'key_habit_auto_load_more';
  static const String keyHabitDoubleTapTop = 'key_habit_double_tap_top';
  static const String keyHabitShowOriginalImg = 'key_habit_show_original_img';
  static const String keyHabitDoubleTapFeedRefresh =
      'key_habit_double_tap_feed_refresh';
  static const String keyHabitInitialTabIndex = 'key_habit_initial_tab_index';
  static const String keyHabitImageLoadMode = 'key_habit_image_load_mode';
  static const String keyHabitForumDefaultSort = 'key_habit_forum_default_sort';
  static const String keyHabitDoNotSaveHistory =
      'key_habit_do_not_save_history';
  static const String keyBookmarkSortOrder = 'key_bookmark_sort_order';
  static const String keyMyForumsSingleColumn = 'key_my_forums_single_column';

  static String bookmarksKeyForAccount(String uid) {
    final normalized = uid.trim();
    return normalized.isEmpty ? keyBookmarks : '${keyBookmarks}_$normalized';
  }

  static String bookmarkPendingAddsKeyForAccount(String uid) {
    final normalized = uid.trim();
    return normalized.isEmpty
        ? keyBookmarkPendingAdds
        : '${keyBookmarkPendingAdds}_$normalized';
  }

  static String bookmarkPendingRemovesKeyForAccount(String uid) {
    final normalized = uid.trim();
    return normalized.isEmpty
        ? keyBookmarkPendingRemoves
        : '${keyBookmarkPendingRemoves}_$normalized';
  }

  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  int getInt(String key, {int defaultValue = 0}) =>
      _prefs.getInt(key) ?? defaultValue;
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  String getString(String key, {String defaultValue = ''}) =>
      _prefs.getString(key) ?? defaultValue;
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  bool getEnableHaptics() => getBool(keyEnableHaptics, defaultValue: true);
  Future<bool> setEnableHaptics(bool val) => setBool(keyEnableHaptics, val);

  bool getUseFloatingNavBar() =>
      getBool(keyUseFloatingNavBar, defaultValue: true);
  Future<bool> setUseFloatingNavBar(bool val) =>
      setBool(keyUseFloatingNavBar, val);

  bool getUseLiquidGlass() => getBool(keyUseLiquidGlass, defaultValue: false);
  Future<bool> setUseLiquidGlass(bool val) => setBool(keyUseLiquidGlass, val);

  int getFontWeightIndex() => getInt(
    keyFontWeightIndex,
    defaultValue: 1,
  ); // 0: 偏细, 1: 默认, 2: 中等, 3: 偏粗, 4: 加粗
  Future<bool> setFontWeightIndex(int val) => setInt(keyFontWeightIndex, val);

  int getFontSizePercent() =>
      getInt(keyFontSizePercent, defaultValue: 100).clamp(80, 140).toInt();
  Future<bool> setFontSizePercent(int val) =>
      setInt(keyFontSizePercent, val.clamp(80, 140).toInt());

  static const String keyRefreshRateIndex = 'key_display_refresh_rate';

  int getRefreshRateIndex() => getInt(
    keyRefreshRateIndex,
    defaultValue: 0,
  ); // 0: 默认, 1: 极速高刷, 2: 60Hz, 3: 90Hz, 4: 120Hz
  Future<bool> setRefreshRateIndex(int val) => setInt(keyRefreshRateIndex, val);

  static const String keyImageSavePathType = 'key_image_save_path_type';
  static const String keyVideoSavePathType = 'key_video_save_path_type';
  static const String keyAutoClearCacheOnExit = 'key_auto_clear_cache_on_exit';
  static const String keyAutoClearCacheThresholdMb =
      'key_auto_clear_cache_threshold_mb';

  int getImageSavePathType() => getInt(keyImageSavePathType, defaultValue: 0);
  Future<bool> setImageSavePathType(int val) =>
      setInt(keyImageSavePathType, val);

  int getVideoSavePathType() => getInt(keyVideoSavePathType, defaultValue: 0);
  Future<bool> setVideoSavePathType(int val) =>
      setInt(keyVideoSavePathType, val);

  bool getAutoClearCacheOnExit() =>
      getBool(keyAutoClearCacheOnExit, defaultValue: false);
  Future<bool> setAutoClearCacheOnExit(bool val) =>
      setBool(keyAutoClearCacheOnExit, val);

  int getAutoClearCacheThresholdMb() =>
      getInt(keyAutoClearCacheThresholdMb, defaultValue: 200);
  Future<bool> setAutoClearCacheThresholdMb(int val) =>
      setInt(keyAutoClearCacheThresholdMb, val < 0 ? 0 : val);

  bool getMyForumsSingleColumn() =>
      getBool(keyMyForumsSingleColumn, defaultValue: false);
  Future<bool> setMyForumsSingleColumn(bool val) =>
      setBool(keyMyForumsSingleColumn, val);

  String exportSafeBackup() {
    final Map<String, dynamic> safeMap = {
      'version': 1,
      'app': 'Lurk',
      'theme_mode': getInt(keyThemeMode),
      'use_dynamic_color': getBool(keyUseDynamicColor),
      'theme_color_index': getInt(keyThemeColorIndex),
      'is_pure_black_dark': getBool(keyIsPureBlackDark),
      'enable_haptics': getEnableHaptics(),
      'use_floating_nav_bar': getUseFloatingNavBar(),
      'use_liquid_glass_effect': getUseLiquidGlass(),
      'auto_clear_cache_threshold_mb': getAutoClearCacheThresholdMb(),
      'font_weight_index': getFontWeightIndex(),
      'font_size_percent': getFontSizePercent(),
      'refresh_rate_index': getRefreshRateIndex(),
      'my_forums_single_column': getMyForumsSingleColumn(),
      'bookmarks': getStringList(keyBookmarks),
      'history': getStringList(keyBrowsingHistory),
    };
    return jsonEncode(safeMap);
  }

  Future<void> importSafeBackup(String jsonStr) async {
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      if (map['theme_mode'] != null) {
        await setInt(keyThemeMode, map['theme_mode']);
      }
      if (map['use_dynamic_color'] != null) {
        await setBool(keyUseDynamicColor, map['use_dynamic_color']);
      }
      if (map['theme_color_index'] != null) {
        await setInt(keyThemeColorIndex, map['theme_color_index']);
      }
      if (map['is_pure_black_dark'] != null) {
        await setBool(keyIsPureBlackDark, map['is_pure_black_dark']);
      }
      if (map['enable_haptics'] != null) {
        await setEnableHaptics(map['enable_haptics']);
      }
      if (map['use_floating_nav_bar'] != null) {
        await setUseFloatingNavBar(map['use_floating_nav_bar']);
      }
      if (map['use_liquid_glass_effect'] != null) {
        await setUseLiquidGlass(map['use_liquid_glass_effect']);
      }
      final cacheThreshold = map['auto_clear_cache_threshold_mb'];
      if (cacheThreshold is int && cacheThreshold >= 0) {
        await setAutoClearCacheThresholdMb(cacheThreshold);
      }
      if (map['font_weight_index'] != null) {
        await setFontWeightIndex(map['font_weight_index']);
      }
      if (map['font_size_percent'] is num) {
        await setFontSizePercent((map['font_size_percent'] as num).round());
      }
      if (map['refresh_rate_index'] != null) {
        await setRefreshRateIndex(map['refresh_rate_index']);
      }
      if (map['my_forums_single_column'] != null) {
        await setMyForumsSingleColumn(map['my_forums_single_column']);
      }
      if (map['bookmarks'] != null) {
        await setStringList(keyBookmarks, List<String>.from(map['bookmarks']));
      }
    } catch (_) {}
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be initialized in main()',
  );
});

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String keyThemeMode = 'key_theme_mode';
  static const String keyUseDynamicColor = 'key_use_dynamic_color';
  static const String keyThemeColorIndex = 'key_theme_color_index';
  static const String keyIsPureBlackDark = 'key_is_pure_black_dark';
  static const String keyEnableHaptics = 'key_enable_haptics';
  static const String keyUseFloatingNavBar = 'key_use_floating_nav_bar';
  static const String keyFontWeightIndex = 'key_font_weight_index';
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

  int getFontWeightIndex() => getInt(
    keyFontWeightIndex,
    defaultValue: 1,
  ); // 0: 偏细, 1: 默认, 2: 中等, 3: 偏粗, 4: 加粗
  Future<bool> setFontWeightIndex(int val) => setInt(keyFontWeightIndex, val);

  static const String keyRefreshRateIndex = 'key_display_refresh_rate';

  int getRefreshRateIndex() => getInt(
    keyRefreshRateIndex,
    defaultValue: 0,
  ); // 0: 默认, 1: 极速高刷, 2: 60Hz, 3: 90Hz, 4: 120Hz
  Future<bool> setRefreshRateIndex(int val) => setInt(keyRefreshRateIndex, val);

  static const String keyImageSavePathType = 'key_image_save_path_type';
  static const String keyVideoSavePathType = 'key_video_save_path_type';
  static const String keyAutoClearCacheOnExit = 'key_auto_clear_cache_on_exit';

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
      'font_weight_index': getFontWeightIndex(),
      'refresh_rate_index': getRefreshRateIndex(),
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
      if (map['font_weight_index'] != null) {
        await setFontWeightIndex(map['font_weight_index']);
      }
      if (map['refresh_rate_index'] != null) {
        await setRefreshRateIndex(map['refresh_rate_index']);
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

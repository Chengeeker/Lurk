import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/storage/storage_service.dart";

class HabitSettingsState {
  final bool autoLoadMore;
  final bool doubleTapTop;
  final bool showOriginalImg;
  final bool doubleTapFeedRefresh;
  final int initialTabIndex; // 0: 进吧, 1: 推荐, 2: 消息, 3: 我的
  final int imageLoadMode; // 0: 智能省流量, 1: 智能无图, 2: 始终高质量, 3: 始终无图
  final int forumDefaultSort; // 0: 回复时间排序, 1: 发帖时间排序
  final bool doNotSaveHistory;
  final bool useInternalBrowser;

  const HabitSettingsState({
    this.autoLoadMore = true,
    this.doubleTapTop = true,
    this.showOriginalImg = false,
    this.doubleTapFeedRefresh = true,
    this.initialTabIndex = 1,
    this.imageLoadMode = 0,
    this.forumDefaultSort = 0,
    this.doNotSaveHistory = false,
    this.useInternalBrowser = true,
  });

  HabitSettingsState copyWith({
    bool? autoLoadMore,
    bool? doubleTapTop,
    bool? showOriginalImg,
    bool? doubleTapFeedRefresh,
    int? initialTabIndex,
    int? imageLoadMode,
    int? forumDefaultSort,
    bool? doNotSaveHistory,
    bool? useInternalBrowser,
  }) {
    return HabitSettingsState(
      autoLoadMore: autoLoadMore ?? this.autoLoadMore,
      doubleTapTop: doubleTapTop ?? this.doubleTapTop,
      showOriginalImg: showOriginalImg ?? this.showOriginalImg,
      doubleTapFeedRefresh: doubleTapFeedRefresh ?? this.doubleTapFeedRefresh,
      initialTabIndex: initialTabIndex ?? this.initialTabIndex,
      imageLoadMode: imageLoadMode ?? this.imageLoadMode,
      forumDefaultSort: forumDefaultSort ?? this.forumDefaultSort,
      doNotSaveHistory: doNotSaveHistory ?? this.doNotSaveHistory,
      useInternalBrowser: useInternalBrowser ?? this.useInternalBrowser,
    );
  }
}

class HabitSettingsNotifier extends StateNotifier<HabitSettingsState> {
  final StorageService _storage;

  HabitSettingsNotifier(this._storage)
      : super(HabitSettingsState(
          autoLoadMore: _storage.getBool(StorageService.keyHabitAutoLoadMore, defaultValue: true),
          doubleTapTop: _storage.getBool(StorageService.keyHabitDoubleTapTop, defaultValue: true),
          showOriginalImg: _storage.getBool(StorageService.keyHabitShowOriginalImg, defaultValue: false),
          doubleTapFeedRefresh: _storage.getBool(StorageService.keyHabitDoubleTapFeedRefresh, defaultValue: true),
          initialTabIndex: _storage.getInt(StorageService.keyHabitInitialTabIndex, defaultValue: 1),
          imageLoadMode: _storage.getInt(StorageService.keyHabitImageLoadMode, defaultValue: 0),
          forumDefaultSort: _storage.getInt(StorageService.keyHabitForumDefaultSort, defaultValue: 0),
          doNotSaveHistory: _storage.getBool(StorageService.keyHabitDoNotSaveHistory, defaultValue: false),
          useInternalBrowser: _storage.getBool(StorageService.keyUseInternalBrowser, defaultValue: true),
        ));

  Future<void> setAutoLoadMore(bool val) async {
    await _storage.setBool(StorageService.keyHabitAutoLoadMore, val);
    state = state.copyWith(autoLoadMore: val);
  }

  Future<void> setDoubleTapTop(bool val) async {
    await _storage.setBool(StorageService.keyHabitDoubleTapTop, val);
    state = state.copyWith(doubleTapTop: val);
  }

  Future<void> setShowOriginalImg(bool val) async {
    await _storage.setBool(StorageService.keyHabitShowOriginalImg, val);
    state = state.copyWith(showOriginalImg: val);
  }

  Future<void> setDoubleTapFeedRefresh(bool val) async {
    await _storage.setBool(StorageService.keyHabitDoubleTapFeedRefresh, val);
    state = state.copyWith(doubleTapFeedRefresh: val);
  }

  Future<void> setInitialTabIndex(int val) async {
    await _storage.setInt(StorageService.keyHabitInitialTabIndex, val);
    state = state.copyWith(initialTabIndex: val);
  }

  Future<void> setImageLoadMode(int val) async {
    await _storage.setInt(StorageService.keyHabitImageLoadMode, val);
    state = state.copyWith(imageLoadMode: val);
  }

  Future<void> setForumDefaultSort(int val) async {
    await _storage.setInt(StorageService.keyHabitForumDefaultSort, val);
    state = state.copyWith(forumDefaultSort: val);
  }

  Future<void> setDoNotSaveHistory(bool val) async {
    await _storage.setBool(StorageService.keyHabitDoNotSaveHistory, val);
    state = state.copyWith(doNotSaveHistory: val);
  }

  Future<void> setUseInternalBrowser(bool val) async {
    await _storage.setBool(StorageService.keyUseInternalBrowser, val);
    state = state.copyWith(useInternalBrowser: val);
  }
}

final habitSettingsProvider =
    StateNotifierProvider<HabitSettingsNotifier, HabitSettingsState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return HabitSettingsNotifier(storage);
});

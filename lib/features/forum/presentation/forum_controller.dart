import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../feed/data/models/tieba_thread_model.dart';
import '../../my_forums/presentation/my_forums_controller.dart';
import '../../settings/presentation/providers/habit_settings_provider.dart';
import '../data/forum_repository.dart';
import '../data/models/forum_model.dart';

class ForumState {
  final ForumDetailModel? forum;
  final List<TiebaThreadModel> pinnedThreads;
  final List<TiebaThreadModel> threads;
  final bool isLoading;
  final bool isRefreshing;
  final int page;
  final bool hasMore;
  final int sortType;
  final int currentTabIndex;
  final int currentTabId;
  final int currentTabType;
  final String currentTabName;
  final bool isGood;
  final bool isSigningIn;
  final bool isFollowing;
  final String? errorMessage;

  const ForumState({
    this.forum,
    this.pinnedThreads = const [],
    this.threads = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSigningIn = false,
    this.isFollowing = false,
    this.page = 1,
    this.hasMore = true,
    this.sortType = 0,
    this.currentTabIndex = 0,
    this.currentTabId = 0,
    this.currentTabType = 0,
    this.currentTabName = '',
    this.isGood = false,
    this.errorMessage,
  });

  ForumState copyWith({
    ForumDetailModel? forum,
    List<TiebaThreadModel>? pinnedThreads,
    List<TiebaThreadModel>? threads,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSigningIn,
    bool? isFollowing,
    int? page,
    bool? hasMore,
    int? sortType,
    int? currentTabIndex,
    int? currentTabId,
    int? currentTabType,
    String? currentTabName,
    bool? isGood,
    String? errorMessage,
  }) {
    return ForumState(
      forum: forum ?? this.forum,
      pinnedThreads: pinnedThreads ?? this.pinnedThreads,
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSigningIn: isSigningIn ?? this.isSigningIn,
      isFollowing: isFollowing ?? this.isFollowing,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      sortType: sortType ?? this.sortType,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      currentTabId: currentTabId ?? this.currentTabId,
      currentTabType: currentTabType ?? this.currentTabType,
      currentTabName: currentTabName ?? this.currentTabName,
      isGood: isGood ?? this.isGood,
      errorMessage: errorMessage,
    );
  }
}

class ForumController extends StateNotifier<ForumState> {
  final ForumRepository _repository;
  final Ref _ref;
  final String forumName;

  ForumController(this._repository, this._ref, this.forumName, {int initialSortType = 0})
      : super(ForumState(sortType: initialSortType)) {
    refresh();
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, errorMessage: null);

    try {
      final res = await _repository.getForumPage(
        forumName: forumName,
        forumId: state.forum?.id,
        page: 1,
        sortType: state.sortType,
        tabId: state.currentTabId,
        tabType: state.currentTabType,
        tabName: state.currentTabName,
        isGood: state.isGood,
      );

      var forum = res['forum'] as ForumDetailModel? ?? state.forum;
      if (forum != null) {
        // 双重校验：结合本地已关注贴吧缓存保证关注与签到状态实时可靠
        final myForums = _ref.read(myForumsControllerProvider).forums;
        final matched = myForums.where((f) => f.name == forumName || (forum!.id.isNotEmpty && f.id == forum.id));
        if (matched.isNotEmpty) {
          final cached = matched.first;
          forum = forum.copyWith(
            isLiked: true,
            isSigned: forum.isSigned || cached.isSigned,
          );
        }
      }

      state = state.copyWith(
        forum: forum,
        pinnedThreads: (res['pinned_threads'] as List?)?.cast<TiebaThreadModel>() ?? [],
        threads: (res['threads'] as List?)?.cast<TiebaThreadModel>() ?? [],
        page: 1,
        hasMore: res['has_more'] as bool? ?? false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(isRefreshing: false, errorMessage: '加载吧数据失败');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.isRefreshing) return;
    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.page + 1;
      final res = await _repository.getForumPage(
        forumName: forumName,
        forumId: state.forum?.id,
        page: nextPage,
        sortType: state.sortType,
        tabId: state.currentTabId,
        tabType: state.currentTabType,
        tabName: state.currentTabName,
        isGood: state.isGood,
      );
      state = state.copyWith(
        threads: [...state.threads, ...(res['threads'] as List?)?.cast<TiebaThreadModel>() ?? []],
        page: nextPage,
        hasMore: res['has_more'] as bool? ?? false,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectTab(int index, ForumTabModel tab) {
    if (state.currentTabIndex == index &&
        state.currentTabId == tab.tabId &&
        state.currentTabName == tab.tabName &&
        state.isGood == tab.isGood) {
      return;
    }

    state = state.copyWith(
      currentTabIndex: index,
      currentTabId: tab.tabId,
      currentTabType: tab.tabType,
      currentTabName: tab.tabName,
      isGood: tab.isGood,
      threads: [],
    );
    refresh();
  }

  void setSortType(int type) {
    if (state.sortType == type) return;
    state = state.copyWith(sortType: type);
    refresh();
  }

  Future<bool> signIn() async {
    final currentForum = state.forum;
    if (currentForum == null || currentForum.isSigned || state.isSigningIn) return false;

    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) return false;

    state = state.copyWith(isSigningIn: true);
    try {
      var tbs = await _ref.read(authStateProvider.notifier).getValidTbs();
      if (tbs.isEmpty) {
        tbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
      }

      var success = await _repository.signForum(
        forumName: forumName,
        forumId: currentForum.id,
        tbs: tbs,
      );
      if (!success) {
        final freshTbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
        if (freshTbs.isNotEmpty && freshTbs != tbs) {
          success = await _repository.signForum(
            forumName: forumName,
            forumId: currentForum.id,
            tbs: freshTbs,
          );
        }
      }
      if (success) {
        state = state.copyWith(
          isSigningIn: false,
          forum: currentForum.copyWith(isSigned: true),
        );
        _ref.read(myForumsControllerProvider.notifier).refresh();
        return true;
      }
    } catch (_) {}
    state = state.copyWith(isSigningIn: false);
    return false;
  }

  Future<({bool success, String errorMsg})> followForum() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      return (success: false, errorMsg: '请先登录百度账号');
    }

    var currentForum = state.forum;
    if (currentForum == null) {
      final fid = _repository.getCachedForumId(forumName) ?? '';
      currentForum = ForumDetailModel(id: fid, name: forumName);
    }
    if (state.isFollowing) return (success: false, errorMsg: '正在处理中');

    state = state.copyWith(isFollowing: true);
    try {
      var tbs = await _ref.read(authStateProvider.notifier).getValidTbs();
      if (tbs.isEmpty) {
        tbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
      }

      String targetFid = currentForum.id;
      if (targetFid.isEmpty || targetFid == '0') {
        final myForums = _ref.read(myForumsControllerProvider).forums;
        final matched = myForums.where((f) => f.name == forumName);
        if (matched.isNotEmpty) {
          targetFid = matched.first.id;
        } else {
          targetFid = _repository.getCachedForumId(forumName) ?? '';
        }
      }

      var result = await _repository.likeForum(
        forumName: forumName,
        forumId: targetFid,
        tbs: tbs,
      );

      // 若提示未登录或 TBS 异常，强制刷新一次用户 TBS 并重试
      if (!result.success && (result.errorMsg.contains('登录') || result.errorMsg.contains('tbs') || result.errorMsg.contains('TBS'))) {
        final freshTbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
        if (freshTbs.isNotEmpty && freshTbs != tbs) {
          result = await _repository.likeForum(
            forumName: forumName,
            forumId: targetFid,
            tbs: freshTbs,
          );
        }
      }

      if (result.success) {
        state = state.copyWith(
          isFollowing: false,
          forum: (state.forum ?? currentForum).copyWith(isLiked: true),
        );
        _ref.read(myForumsControllerProvider.notifier).refresh();
        return (success: true, errorMsg: '');
      } else {
        state = state.copyWith(isFollowing: false);
        return result;
      }
    } catch (e) {
      state = state.copyWith(isFollowing: false);
      return (success: false, errorMsg: '关注失败: $e');
    }
  }

  Future<({bool success, String errorMsg})> unfollowForum() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      return (success: false, errorMsg: '请先登录百度账号');
    }

    var currentForum = state.forum;
    if (currentForum == null) {
      final myForums = _ref.read(myForumsControllerProvider).forums;
      final matched = myForums.where((f) => f.name == forumName);
      final fid = matched.isNotEmpty ? matched.first.id : (_repository.getCachedForumId(forumName) ?? '');
      currentForum = ForumDetailModel(id: fid, name: forumName);
    }
    if (state.isFollowing) return (success: false, errorMsg: '正在处理中');

    state = state.copyWith(isFollowing: true);
    try {
      var tbs = await _ref.read(authStateProvider.notifier).getValidTbs();
      if (tbs.isEmpty) {
        tbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
      }

      String targetFid = currentForum.id;
      if (targetFid.isEmpty || targetFid == '0') {
        final myForums = _ref.read(myForumsControllerProvider).forums;
        final matched = myForums.where((f) => f.name == forumName);
        if (matched.isNotEmpty) {
          targetFid = matched.first.id;
        } else {
          targetFid = _repository.getCachedForumId(forumName) ?? '';
        }
      }

      var result = await _repository.unlikeForum(
        forumName: forumName,
        forumId: targetFid,
        tbs: tbs,
      );

      // 若提示未登录或 TBS 异常，强制刷新一次用户 TBS 并重试
      if (!result.success && (result.errorMsg.contains('登录') || result.errorMsg.contains('tbs') || result.errorMsg.contains('TBS'))) {
        final freshTbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
        if (freshTbs.isNotEmpty && freshTbs != tbs) {
          result = await _repository.unlikeForum(
            forumName: forumName,
            forumId: targetFid,
            tbs: freshTbs,
          );
        }
      }

      if (result.success) {
        state = state.copyWith(
          isFollowing: false,
          forum: (state.forum ?? currentForum).copyWith(isLiked: false, isSigned: false),
        );
        _ref.read(myForumsControllerProvider.notifier).refresh();
        return (success: true, errorMsg: '');
      } else {
        state = state.copyWith(isFollowing: false);
        return result;
      }
    } catch (e) {
      state = state.copyWith(isFollowing: false);
      return (success: false, errorMsg: '取消关注失败: $e');
    }
  }
}

final forumControllerFamily =
    StateNotifierProvider.family<ForumController, ForumState, String>((ref, forumName) {
  final repo = ref.watch(forumRepositoryProvider);
  final habitState = ref.watch(habitSettingsProvider);
  return ForumController(repo, ref, forumName, initialSortType: habitState.forumDefaultSort);
});


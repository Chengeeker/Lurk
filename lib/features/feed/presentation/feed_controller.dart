import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../my_forums/presentation/my_forums_controller.dart';
import '../../settings/presentation/providers/block_settings_provider.dart';
import '../data/feed_repository.dart';
import '../data/models/hot_topic_model.dart';
import '../data/models/tieba_thread_model.dart';

class FeedState {
  final List<TiebaThreadModel> threads;
  final bool isLoading;
  final bool isRefreshing;
  final int page;
  final bool hasMore;
  final String? errorMessage;

  const FeedState({
    this.threads = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
  });

  FeedState copyWith({
    List<TiebaThreadModel>? threads,
    bool? isLoading,
    bool? isRefreshing,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return FeedState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  final FeedRepository _repository;
  final Ref _ref;
  List<TiebaThreadModel> _allRawThreads = [];

  FeedController(this._repository, this._ref) : super(const FeedState()) {
    refresh();
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.activeAccount?.uid != next.activeAccount?.uid) {
        refresh();
      }
    });
    _ref.listen<BlockSettingsState>(blockSettingsProvider, (previous, next) {
      if (previous != next) {
        state = state.copyWith(threads: _applyBlockFilters(_allRawThreads));
      }
    });
  }

  List<TiebaThreadModel> _applyBlockFilters(List<TiebaThreadModel> raw) {
    final blockSettings = _ref.read(blockSettingsProvider);
    final myForums = _ref.read(myForumsControllerProvider);
    final followedForums = myForums.forums.map((f) => f.name).toSet();
    return raw.where((t) => !blockSettings.isThreadBlocked(t, followedForums: followedForums)).toList();
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, errorMessage: null);

    try {
      final list = await _repository.getPersonalizedFeed(page: 1, loadType: 1);
      _allRawThreads = list;
      final filtered = _applyBlockFilters(_allRawThreads);
      state = state.copyWith(
        threads: filtered,
        page: 1,
        hasMore: list.isNotEmpty,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: '加载失败，请检查网络或登录状态',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.isRefreshing) return;
    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.page + 1;
      final list = await _repository.getPersonalizedFeed(page: nextPage, loadType: 2);
      _allRawThreads = [..._allRawThreads, ...list];
      final filtered = _applyBlockFilters(_allRawThreads);
      state = state.copyWith(
        threads: filtered,
        page: nextPage,
        hasMore: list.isNotEmpty,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleAgree(TiebaThreadModel thread) async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再点赞');
      return;
    }

    final newStatus = !thread.isAgreed;
    final newCount = (thread.agreeNum + (newStatus ? 1 : -1)).clamp(0, 999999);

    final updatedList = state.threads.map((t) {
      if (t.id == thread.id) {
        return t.copyWith(isAgreed: newStatus, agreeNum: newCount);
      }
      return t;
    }).toList();
    state = state.copyWith(threads: updatedList);

    final tbs = await _ref.read(authStateProvider.notifier).getValidTbs();

    try {
      var res = await _repository.opAgree(
        threadId: thread.id,
        postId: '0',
        isAgree: newStatus,
        tbs: tbs.isNotEmpty ? tbs : account.tbs,
      );

      // 若返回 TBS 校验失败，通过原生客户端重新刷新并重试一次
      if (!res.success && (res.errorMsg.contains('TBS') || res.errorMsg.contains('tbs'))) {
        final freshTbs = await _ref.read(authStateProvider.notifier).getValidTbs(forceRefresh: true);
        if (freshTbs.isNotEmpty && freshTbs != tbs) {
          res = await _repository.opAgree(
            threadId: thread.id,
            postId: '0',
            isAgree: newStatus,
            tbs: freshTbs,
          );
        }
      }

      if (!res.success) {
        final rollbackList = state.threads.map((t) {
          if (t.id == thread.id) return thread;
          return t;
        }).toList();
        state = state.copyWith(threads: rollbackList);
        AppToast.showToast(res.errorMsg.isNotEmpty ? res.errorMsg : '点赞失败，请重试');
      }
    } catch (_) {
      final rollbackList = state.threads.map((t) {
        if (t.id == thread.id) return thread;
        return t;
      }).toList();
      state = state.copyWith(threads: rollbackList);
      AppToast.showToast('网络异常，点赞失败');
    }
  }

  void syncThreadAgree(String threadId, bool isAgreed, int agreeNum) {
    final idx = state.threads.indexWhere((t) => t.id == threadId);
    if (idx != -1) {
      final updatedList = List<TiebaThreadModel>.from(state.threads);
      updatedList[idx] = updatedList[idx].copyWith(isAgreed: isAgreed, agreeNum: agreeNum);
      state = state.copyWith(threads: updatedList);
    }
  }
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return FeedController(repo, ref);
});

class TimelineScrollNotifier extends StateNotifier<double> {
  TimelineScrollNotifier() : super(0.0);

  double _lastSavedOffset = 0.0;
  void Function(double offset)? animateToCallback;
  void Function()? refreshCallback;

  void handleSingleTap() {
    if (state > 50.0) {
      _lastSavedOffset = state;
      animateToCallback?.call(0.0);
    } else if (_lastSavedOffset > 50.0) {
      animateToCallback?.call(_lastSavedOffset);
    }
  }

  void handleDoubleTap() {
    animateToCallback?.call(0.0);
    refreshCallback?.call();
  }

  void updateOffset(double offset) {
    state = offset;
  }
}

final timelineScrollProvider = StateNotifierProvider<TimelineScrollNotifier, double>((ref) {
  return TimelineScrollNotifier();
});

class FollowFeedState {
  final List<TiebaThreadModel> threads;
  final bool isLoading;
  final bool isRefreshing;
  final int page;
  final bool hasMore;
  final String? errorMessage;

  const FollowFeedState({
    this.threads = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
  });

  FollowFeedState copyWith({
    List<TiebaThreadModel>? threads,
    bool? isLoading,
    bool? isRefreshing,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return FollowFeedState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }
}

class FollowFeedController extends StateNotifier<FollowFeedState> {
  final FeedRepository _repository;
  final Ref _ref;

  FollowFeedController(this._repository, this._ref) : super(const FollowFeedState()) {
    refresh();
  }

  Future<void> refresh() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      state = state.copyWith(
        threads: [],
        isRefreshing: false,
        isLoading: false,
        errorMessage: '登录后查看关注的人动态',
      );
      return;
    }

    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, errorMessage: null);

    try {
      final list = await _repository.getFollowedUsersFeed(uid: account.uid, page: 1);
      state = state.copyWith(
        threads: list,
        page: 1,
        hasMore: list.isNotEmpty,
        isRefreshing: false,
        errorMessage: list.isEmpty ? '关注的用户暂未发布新内容' : null,
      );
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: '加载失败，请下拉重试',
      );
    }
  }

  Future<void> loadMore() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) return;
    if (state.isLoading || !state.hasMore || state.isRefreshing) return;

    state = state.copyWith(isLoading: true);
    try {
      final nextPage = state.page + 1;
      final list = await _repository.getFollowedUsersFeed(uid: account.uid, page: nextPage);
      state = state.copyWith(
        threads: [...state.threads, ...list],
        page: nextPage,
        hasMore: list.isNotEmpty,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void syncThreadAgree(String threadId, bool isAgreed, int agreeNum) {
    final idx = state.threads.indexWhere((t) => t.id == threadId);
    if (idx != -1) {
      final updatedList = List<TiebaThreadModel>.from(state.threads);
      updatedList[idx] = updatedList[idx].copyWith(isAgreed: isAgreed, agreeNum: agreeNum);
      state = state.copyWith(threads: updatedList);
    }
  }
}

final followFeedControllerProvider =
    StateNotifierProvider<FollowFeedController, FollowFeedState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return FollowFeedController(repo, ref);
});

class HotTopicState {
  final List<TiebaHotTopicModel> topics;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  const HotTopicState({
    this.topics = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  HotTopicState copyWith({
    List<TiebaHotTopicModel>? topics,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
  }) {
    return HotTopicState(
      topics: topics ?? this.topics,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
    );
  }
}

class HotTopicController extends StateNotifier<HotTopicState> {
  final FeedRepository _repository;

  HotTopicController(this._repository) : super(const HotTopicState()) {
    refresh();
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, errorMessage: null);

    try {
      final list = await _repository.getHotTopicList();
      state = state.copyWith(
        topics: list,
        isRefreshing: false,
        errorMessage: list.isEmpty ? '暂无热榜数据' : null,
      );
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: '加载热榜失败，请下拉重试',
      );
    }
  }
}

final hotTopicControllerProvider =
    StateNotifierProvider<HotTopicController, HotTopicState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return HotTopicController(repo);
});

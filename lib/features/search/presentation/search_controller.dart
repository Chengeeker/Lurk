import "package:flutter_riverpod/flutter_riverpod.dart";
import "../data/models/tieba_search_model.dart";
import "../data/search_repository.dart";

class SearchState {
  final List<TiebaSearchResultModel> results;
  final SearchForumResultModel forumResult;
  final SearchUserResultModel userResult;
  final bool isLoading;
  final bool isLoadingForums;
  final bool isLoadingUsers;
  final String keyword;
  final int sortMode; // 0: 相关度, 1: 新贴在前, 2: 旧贴在前
  final int onlyThread; // 0: 全部, 1: 只看主题贴
  final String? forumName;

  const SearchState({
    this.results = const [],
    this.forumResult = const SearchForumResultModel(),
    this.userResult = const SearchUserResultModel(),
    this.isLoading = false,
    this.isLoadingForums = false,
    this.isLoadingUsers = false,
    this.keyword = "",
    this.sortMode = 0,
    this.onlyThread = 1,
    this.forumName,
  });

  SearchState copyWith({
    List<TiebaSearchResultModel>? results,
    SearchForumResultModel? forumResult,
    SearchUserResultModel? userResult,
    bool? isLoading,
    bool? isLoadingForums,
    bool? isLoadingUsers,
    String? keyword,
    int? sortMode,
    int? onlyThread,
    String? forumName,
  }) {
    return SearchState(
      results: results ?? this.results,
      forumResult: forumResult ?? this.forumResult,
      userResult: userResult ?? this.userResult,
      isLoading: isLoading ?? this.isLoading,
      isLoadingForums: isLoadingForums ?? this.isLoadingForums,
      isLoadingUsers: isLoadingUsers ?? this.isLoadingUsers,
      keyword: keyword ?? this.keyword,
      sortMode: sortMode ?? this.sortMode,
      onlyThread: onlyThread ?? this.onlyThread,
      forumName: forumName ?? this.forumName,
    );
  }
}

class SearchController extends StateNotifier<SearchState> {
  final SearchRepository _repository;

  SearchController(this._repository) : super(const SearchState());

  void reset() {
    state = const SearchState();
  }

  Future<void> search({
    String? keyword,
    int? sortMode,
    int? onlyThread,
    String? forumName,
  }) async {
    final effectiveKeyword = (keyword ?? state.keyword).trim();
    final effectiveSortMode = sortMode ?? state.sortMode;
    final effectiveOnlyThread = onlyThread ?? state.onlyThread;
    final effectiveForumName = forumName ?? state.forumName;

    if (effectiveKeyword.isEmpty) {
      state = state.copyWith(
        keyword: "",
        results: [],
        forumResult: const SearchForumResultModel(),
        userResult: const SearchUserResultModel(),
        isLoading: false,
        isLoadingForums: false,
        isLoadingUsers: false,
        sortMode: effectiveSortMode,
        onlyThread: effectiveOnlyThread,
        forumName: effectiveForumName,
      );
      return;
    }

    final isForumSearch = effectiveForumName != null && effectiveForumName.isNotEmpty;

    state = state.copyWith(
      keyword: effectiveKeyword,
      sortMode: effectiveSortMode,
      onlyThread: effectiveOnlyThread,
      forumName: effectiveForumName,
      isLoading: true,
      isLoadingForums: !isForumSearch,
      isLoadingUsers: !isForumSearch,
    );

    if (isForumSearch) {
      try {
        final list = await _repository.searchPosts(
          keyword: effectiveKeyword,
          page: 1,
          sortMode: effectiveSortMode,
          onlyThread: effectiveOnlyThread,
          forumName: effectiveForumName,
        );
        state = state.copyWith(results: list, isLoading: false);
      } catch (_) {
        state = state.copyWith(isLoading: false);
      }
    } else {
      _repository.searchPosts(
        keyword: effectiveKeyword,
        page: 1,
        sortMode: effectiveSortMode,
        onlyThread: 0,
      ).then((list) {
        state = state.copyWith(results: list, isLoading: false);
      }).catchError((_) {
        state = state.copyWith(isLoading: false);
      });

      _repository.searchForums(keyword: effectiveKeyword).then((forumRes) {
        state = state.copyWith(forumResult: forumRes, isLoadingForums: false);
      }).catchError((_) {
        state = state.copyWith(isLoadingForums: false);
      });

      _repository.searchUsers(keyword: effectiveKeyword).then((userRes) {
        state = state.copyWith(userResult: userRes, isLoadingUsers: false);
      }).catchError((_) {
        state = state.copyWith(isLoadingUsers: false);
      });
    }
  }

  Future<void> changePostSort(int newSort) async {
    if (state.keyword.isEmpty || state.sortMode == newSort) return;
    state = state.copyWith(sortMode: newSort, isLoading: true);
    try {
      final list = await _repository.searchPosts(
        keyword: state.keyword,
        page: 1,
        sortMode: newSort,
        onlyThread: state.forumName != null && state.forumName!.isNotEmpty ? state.onlyThread : 0,
        forumName: state.forumName,
      );
      state = state.copyWith(results: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchController(repo);
});

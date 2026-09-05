import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/models/followed_forum_model.dart';
import '../data/my_forums_repository.dart';

class MyForumsState {
  final List<FollowedForumModel> forums;
  final bool isLoading;
  final bool isSigning;
  final String? errorMessage;

  const MyForumsState({
    this.forums = const [],
    this.isLoading = false,
    this.isSigning = false,
    this.errorMessage,
  });

  MyForumsState copyWith({
    List<FollowedForumModel>? forums,
    bool? isLoading,
    bool? isSigning,
    String? errorMessage,
  }) {
    return MyForumsState(
      forums: forums ?? this.forums,
      isLoading: isLoading ?? this.isLoading,
      isSigning: isSigning ?? this.isSigning,
      errorMessage: errorMessage,
    );
  }
}

class MyForumsController extends StateNotifier<MyForumsState> {
  final MyForumsRepository _repository;
  final Ref _ref;

  MyForumsController(this._repository, this._ref) : super(const MyForumsState()) {
    refresh();
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.activeAccount?.uid != next.activeAccount?.uid) {
        refresh();
      }
    });
  }

  Future<void> refresh() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      state = state.copyWith(forums: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getFollowedForums(uid: account.uid);
      state = state.copyWith(forums: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '获取关注贴吧失败');
    }
  }

  Future<bool> batchSign() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null) return false;

    state = state.copyWith(isSigning: true);
    try {
      final tbs = await _ref.read(authStateProvider.notifier).getValidTbs();
      final ok = await _repository.batchSignIn(tbs: tbs.isNotEmpty ? tbs : account.tbs);
      if (ok) {
        // 百度贴吧一键签到官方限制：仅支持签到用户等级大于等于 7 级的吧
        // 未满 7 级的吧保持原本状态，不盲目显示为已签到
        final updated = state.forums.map((f) {
          if (f.userLevel >= 7) {
            return f.copyWith(isSigned: true);
          }
          return f;
        }).toList();
        state = state.copyWith(forums: updated, isSigning: false);
      } else {
        state = state.copyWith(isSigning: false);
      }
      return ok;
    } catch (_) {
      state = state.copyWith(isSigning: false);
      return false;
    }
  }
}

final myForumsControllerProvider =
    StateNotifierProvider<MyForumsController, MyForumsState>((ref) {
  final repo = ref.watch(myForumsRepositoryProvider);
  return MyForumsController(repo, ref);
});

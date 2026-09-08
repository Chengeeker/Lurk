import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../feed/data/models/tieba_thread_model.dart';
import '../data/models/tieba_profile_model.dart';
import '../data/profile_repository.dart';

class ProfileState {
  final TiebaProfileModel? profile;
  final List<TiebaThreadModel> userPosts;
  final bool isLoading;

  const ProfileState({
    this.profile,
    this.userPosts = const [],
    this.isLoading = false,
  });

  ProfileState copyWith({
    TiebaProfileModel? profile,
    List<TiebaThreadModel>? userPosts,
    bool? isLoading,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      userPosts: userPosts ?? this.userPosts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileController(this._repository, this._ref) : super(const ProfileState()) {
    refresh();
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.activeAccount?.uid != next.activeAccount?.uid) {
        refresh();
      }
    });
  }

  Future<void> refresh() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) return;

    state = state.copyWith(isLoading: true);
    try {
      final prof = await _repository.getProfile(uid: account.uid);
      final posts = await _repository.getUserPosts(uid: account.uid, page: 1);
      state = state.copyWith(profile: prof, userPosts: posts, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileController(repo, ref);
});

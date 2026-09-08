import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../data/models/tieba_notification_model.dart';
import '../data/notification_repository.dart';

class NotificationState {
  final List<TiebaNotificationModel> replies;
  final List<TiebaNotificationModel> atList;
  final bool isLoading;

  const NotificationState({
    this.replies = const [],
    this.atList = const [],
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<TiebaNotificationModel>? replies,
    List<TiebaNotificationModel>? atList,
    bool? isLoading,
  }) {
    return NotificationState(
      replies: replies ?? this.replies,
      atList: atList ?? this.atList,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationController extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationController(this._repository, this._ref) : super(const NotificationState()) {
    refresh();
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.activeAccount?.uid != next.activeAccount?.uid) {
        refresh();
      }
    });
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final replies = await _repository.getReplyMe(page: 1);
      final atList = await _repository.getAtMe(page: 1);
      state = state.copyWith(replies: replies, atList: atList, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationController(repo, ref);
});


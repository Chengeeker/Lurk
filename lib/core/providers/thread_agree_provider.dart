import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThreadAgreeInfo {
  final bool isAgreed;
  final int agreeNum;

  const ThreadAgreeInfo({
    required this.isAgreed,
    required this.agreeNum,
  });
}

class ThreadAgreeNotifier extends StateNotifier<Map<String, ThreadAgreeInfo>> {
  ThreadAgreeNotifier() : super({});

  void setAgree(String threadId, bool isAgreed, int agreeNum) {
    state = {
      ...state,
      threadId: ThreadAgreeInfo(
        isAgreed: isAgreed,
        agreeNum: agreeNum.clamp(0, 999999),
      ),
    };
  }

  ThreadAgreeInfo? getInfo(String threadId) => state[threadId];
}

final threadAgreeProvider =
    StateNotifierProvider<ThreadAgreeNotifier, Map<String, ThreadAgreeInfo>>((ref) {
  return ThreadAgreeNotifier();
});

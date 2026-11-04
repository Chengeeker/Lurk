import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show DateUtils;

import '../../../core/auth/auth_provider.dart';
import '../../../core/storage/storage_service.dart';
import '../../profile/data/profile_repository.dart';
import '../data/models/followed_forum_model.dart';
import '../data/my_forums_repository.dart';

final batchSignNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

bool isEarlyBatchSignTime(DateTime now) =>
    now.toUtc().add(const Duration(hours: 8)).hour == 0;

const earlyBatchSignMessage =
    '普通用户在北京时间 00:00–01:00 暂不支持一键签到，请 01:00 后重试，或进入贴吧单独签到。';

class MyForumsState {
  final List<FollowedForumModel> forums;
  final bool isLoading;
  final bool isSigning;
  final String? errorMessage;
  final String? signMessage;

  const MyForumsState({
    this.forums = const [],
    this.isLoading = false,
    this.isSigning = false,
    this.errorMessage,
    this.signMessage,
  });

  MyForumsState copyWith({
    List<FollowedForumModel>? forums,
    bool? isLoading,
    bool? isSigning,
    String? errorMessage,
    String? signMessage,
    bool clearSignMessage = false,
  }) {
    return MyForumsState(
      forums: forums ?? this.forums,
      isLoading: isLoading ?? this.isLoading,
      isSigning: isSigning ?? this.isSigning,
      errorMessage: errorMessage,
      signMessage: clearSignMessage ? null : signMessage ?? this.signMessage,
    );
  }
}

class MyForumsController extends StateNotifier<MyForumsState> {
  final MyForumsRepository _repository;
  final Ref _ref;
  int _refreshSequence = 0;
  int _accountRevision = 0;
  DateTime? _signDay;
  DateTime? _forumsDay;
  final Set<String> _confirmedSigns = {};

  void _checkSignDay() {
    final today = DateUtils.dateOnly(
      _ref.read(batchSignNowProvider)().toUtc().add(const Duration(hours: 8)),
    );
    if (today != _signDay) {
      _signDay = today;
      _forumsDay = null;
      _confirmedSigns.clear();
    }
  }

  Iterable<FollowedForumModel> get _batchTargets {
    final eligible = state.forums.where((forum) => forum.userLevel >= 7);
    return eligible.isNotEmpty ? eligible : state.forums;
  }

  bool get _batchAlreadyComplete {
    final targets = _batchTargets;
    return targets.isNotEmpty &&
        targets.every(
          (forum) =>
              _confirmedSigns.contains(forum.name) ||
              (_forumsDay == _signDay && forum.isSigned),
        );
  }

  void markSigned(String forumName) {
    _checkSignDay();
    _confirmedSigns.add(forumName);
    state = state.copyWith(
      forums: [
        for (final forum in state.forums)
          forum.name == forumName ? forum.copyWith(isSigned: true) : forum,
      ],
    );
  }

  MyForumsController(this._repository, this._ref)
    : super(const MyForumsState()) {
    refresh();
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.activeAccount?.uid != next.activeAccount?.uid) {
        _accountRevision++;
        _forumsDay = null;
        _confirmedSigns.clear();
        state = const MyForumsState();
        refresh();
      }
    });
  }

  Future<bool> refresh({Set<String>? requiredNames}) async {
    _checkSignDay();
    final requestDay = _signDay;
    final requestSequence = ++_refreshSequence;
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      if (requestSequence != _refreshSequence) return false;
      state = state.copyWith(forums: [], isLoading: false);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getFollowedForums(uid: account.uid);
      final currentAccount = _ref.read(authStateProvider).activeAccount;
      if (!mounted ||
          requestSequence != _refreshSequence ||
          currentAccount?.uid != account.uid) {
        return false;
      }
      _checkSignDay();
      if (requiredNames != null &&
          (requestDay != _signDay ||
              !list
                  .map((forum) => forum.name)
                  .toSet()
                  .containsAll(requiredNames))) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      // A response started yesterday cannot confirm today's sign status.
      _forumsDay = requestDay == _signDay ? requestDay : null;
      state = state.copyWith(
        forums: [
          for (final forum in list)
            _confirmedSigns.contains(forum.name)
                ? forum.copyWith(isSigned: true)
                : forum,
        ],
        isLoading: false,
      );
      return true;
    } catch (e) {
      if (!mounted || requestSequence != _refreshSequence) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: requiredNames == null ? '获取关注贴吧失败' : null,
      );
      return false;
    }
  }

  Future<bool> batchSign() async {
    final account = _ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin || state.isSigning) return false;
    _checkSignDay();
    if (_batchAlreadyComplete) {
      state = state.copyWith(clearSignMessage: true);
      return true;
    }
    final revision = _accountRevision;
    final requestDay = _signDay;

    state = state.copyWith(isSigning: true, clearSignMessage: true);
    try {
      final tbs = await _ref.read(authStateProvider.notifier).getValidTbs();
      if (!mounted || revision != _accountRevision) return false;
      final now = _ref.read(batchSignNowProvider);
      bool? isMember;
      if (isEarlyBatchSignTime(now())) {
        try {
          final profile = await _ref
              .read(profileRepositoryProvider)
              .getProfile(uid: account.uid);
          if (profile?.id == account.uid) isMember = profile?.isMember;
        } catch (_) {
          // Unknown membership must not block a member's server-authorized sign.
        }
        if (!mounted || revision != _accountRevision) return false;
        if (isEarlyBatchSignTime(now()) && isMember == false) {
          state = state.copyWith(
            isSigning: false,
            signMessage: earlyBatchSignMessage,
          );
          return false;
        }
      }
      var ok = false;
      try {
        ok = await _repository.batchSignIn(
          tbs: tbs.isNotEmpty ? tbs : account.tbs,
        );
      } catch (_) {
        // A lost response can still follow a successful server-side sign.
      }
      if (!mounted || revision != _accountRevision) return false;
      _checkSignDay();
      final verifyStatus = !ok || requestDay != _signDay;
      if (verifyStatus) {
        final expectedNames = _batchTargets.map((forum) => forum.name).toSet();
        final refreshed = await refresh(requiredNames: expectedNames);
        if (!mounted || revision != _accountRevision) return false;
        ok =
            refreshed &&
            _forumsDay == _signDay &&
            _batchAlreadyComplete &&
            expectedNames.isNotEmpty;
      }
      if (ok) {
        _checkSignDay();
        // 百度贴吧一键签到官方限制：仅支持签到用户等级大于等于 7 级的吧
        // 未满 7 级的吧保持原本状态，不盲目显示为已签到
        final updated = state.forums.map((f) {
          if (f.userLevel >= 7) {
            _confirmedSigns.add(f.name);
            return f.copyWith(isSigned: true);
          }
          return f;
        }).toList();
        ++_refreshSequence;
        state = state.copyWith(
          forums: updated,
          isSigning: false,
          isLoading: false,
        );
        if (!verifyStatus) await refresh();
      } else {
        state = state.copyWith(
          isSigning: false,
          signMessage: isMember == null && isEarlyBatchSignTime(now())
              ? '一键签到未完成。$earlyBatchSignMessage'
              : null,
        );
      }
      return mounted && revision == _accountRevision && ok;
    } catch (_) {
      if (!mounted || revision != _accountRevision) return false;
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

class MyForumsLayoutNotifier extends StateNotifier<bool> {
  final StorageService _storage;

  MyForumsLayoutNotifier(this._storage)
    : super(_storage.getMyForumsSingleColumn());

  Future<void> toggle() async {
    final next = !state;
    state = next;
    await _storage.setMyForumsSingleColumn(next);
  }

  Future<void> setSingleColumn(bool value) async {
    if (state == value) return;
    state = value;
    await _storage.setMyForumsSingleColumn(value);
  }
}

final myForumsSingleColumnProvider =
    StateNotifierProvider<MyForumsLayoutNotifier, bool>((ref) {
      final storage = ref.watch(storageServiceProvider);
      return MyForumsLayoutNotifier(storage);
    });

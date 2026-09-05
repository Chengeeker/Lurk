import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/thread_agree_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../feed/presentation/feed_controller.dart';
import '../data/detail_repository.dart';
import '../data/models/tieba_post_model.dart';

enum CommentSortType {
  asc, // 正序
  desc, // 倒序
  hot, // 热门
}

class DetailState {
  final List<TiebaFloorModel> floors;
  final String threadTitle;
  final int threadCreateTime;
  final String threadIp;
  final bool? isAgreed;
  final int? agreeNum;
  final String firstPostId;
  final String forumId;
  final String forumName;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSubmittingReply;
  final int page;
  final bool hasMore;
  final bool seeLzOnly;
  final CommentSortType sortType;
  final String tbs;
  final String? errorMessage;

  const DetailState({
    this.floors = const [],
    this.threadTitle = '',
    this.threadCreateTime = 0,
    this.threadIp = '',
    this.isAgreed,
    this.agreeNum,
    this.firstPostId = '',
    this.forumId = '',
    this.forumName = '',
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSubmittingReply = false,
    this.page = 1,
    this.hasMore = true,
    this.seeLzOnly = false,
    this.sortType = CommentSortType.asc,
    this.tbs = '',
    this.errorMessage,
  });

  DetailState copyWith({
    List<TiebaFloorModel>? floors,
    String? threadTitle,
    int? threadCreateTime,
    String? threadIp,
    bool? isAgreed,
    int? agreeNum,
    String? firstPostId,
    String? forumId,
    String? forumName,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSubmittingReply,
    int? page,
    bool? hasMore,
    bool? seeLzOnly,
    CommentSortType? sortType,
    String? tbs,
    String? errorMessage,
  }) {
    return DetailState(
      floors: floors ?? this.floors,
      threadTitle: threadTitle ?? this.threadTitle,
      threadCreateTime: threadCreateTime ?? this.threadCreateTime,
      threadIp: threadIp ?? this.threadIp,
      isAgreed: isAgreed ?? this.isAgreed,
      agreeNum: agreeNum ?? this.agreeNum,
      firstPostId: firstPostId ?? this.firstPostId,
      forumId: forumId ?? this.forumId,
      forumName: forumName ?? this.forumName,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmittingReply: isSubmittingReply ?? this.isSubmittingReply,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      seeLzOnly: seeLzOnly ?? this.seeLzOnly,
      sortType: sortType ?? this.sortType,
      tbs: tbs ?? this.tbs,
      errorMessage: errorMessage,
    );
  }
}

class DetailController extends StateNotifier<DetailState> {
  final DetailRepository _repository;
  final String threadId;
  final Ref? _ref;

  DetailController(this._repository, this.threadId, [this._ref]) : super(const DetailState()) {
    refresh();
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, errorMessage: null);

    try {
      final res = await _repository.getThreadDetail(
        threadId: threadId,
        page: 1,
        seeLzOnly: state.seeLzOnly,
        reverse: state.sortType == CommentSortType.desc,
      );
      final list = res['floors'] as List<TiebaFloorModel>;
      final hasMore = res['has_more'] as bool? ?? false;
      final threadMap = res['thread'] as Map<String, dynamic>? ?? {};
      final serverTitle = threadMap['title']?.toString() ?? '';
      final serverCreateTime = int.tryParse(threadMap['create_time']?.toString() ?? '0') ?? 0;
      final authorMap = threadMap['author'] is Map ? threadMap['author'] as Map : null;
      final serverIp = threadMap['ip_address']?.toString() ??
          threadMap['location']?.toString() ??
          authorMap?['ip_address']?.toString() ??
          authorMap?['location']?.toString() ??
          '';

      final forumMap = res['forum'] as Map<String, dynamic>? ?? {};
      final serverFid = forumMap['id']?.toString() ??
          threadMap['fid']?.toString() ??
          threadMap['forum_id']?.toString() ??
          '';
      final serverFname = forumMap['name']?.toString() ??
          threadMap['fname']?.toString() ??
          threadMap['forum_name']?.toString() ??
          '';

      final agreeMap = threadMap['agree'] is Map ? (threadMap['agree'] as Map) : null;
      final serverAgreeNum = int.tryParse(agreeMap?['agree_num']?.toString() ??
          agreeMap?['diff_agree_num']?.toString() ??
          threadMap['agree_num']?.toString() ??
          '0');
      final serverHasAgreed = agreeMap?['has_agree'] == 1 ||
          agreeMap?['has_agree'] == '1' ||
          threadMap['has_agree'] == 1 ||
          threadMap['has_agree'] == '1' ||
          threadMap['is_agree'] == 1 ||
          threadMap['is_agree'] == '1';

      final serverFirstPostId = threadMap['first_post_id']?.toString() ??
          threadMap['post_id']?.toString() ??
          (list.isNotEmpty ? list.first.id : '');

      // 结合全局点赞状态：若全局已有用户操作的状态，优先保留全局记录；否则使用服务端权威状态
      final globalRecord = _ref?.read(threadAgreeProvider)[threadId];
      final bool finalAgreed = globalRecord != null ? globalRecord.isAgreed : serverHasAgreed;
      final int finalAgreeNum = globalRecord != null ? globalRecord.agreeNum : (serverAgreeNum ?? 0);

      // 同步到全局 Provider
      _ref?.read(threadAgreeProvider.notifier).setAgree(threadId, finalAgreed, finalAgreeNum);

      // 同步首楼状态，保证一致性
      if (list.isNotEmpty && list.first.floor == 1) {
        list[0] = list.first.copyWith(
          isAgreed: finalAgreed,
          agreeNum: finalAgreeNum,
        );
      }

      state = state.copyWith(
        floors: list,
        threadTitle: serverTitle,
        threadCreateTime: serverCreateTime,
        threadIp: serverIp.replaceAll('来自', '').trim(),
        isAgreed: finalAgreed,
        agreeNum: finalAgreeNum,
        firstPostId: serverFirstPostId,
        forumId: serverFid.isNotEmpty ? serverFid : state.forumId,
        forumName: serverFname.isNotEmpty ? serverFname : state.forumName,
        tbs: (res['anti'] is Map && res['anti']['tbs'] != null && res['anti']['tbs'].toString().isNotEmpty)
            ? res['anti']['tbs'].toString()
            : state.tbs,
        page: 1,
        hasMore: hasMore,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: '加载失败，请重试',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.isRefreshing) return;
    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.page + 1;
      final res = await _repository.getThreadDetail(
        threadId: threadId,
        page: nextPage,
        seeLzOnly: state.seeLzOnly,
        reverse: state.sortType == CommentSortType.desc,
      );
      final list = res['floors'] as List<TiebaFloorModel>;
      final hasMore = res['has_more'] as bool? ?? false;

      state = state.copyWith(
        floors: [...state.floors, ...list],
        page: nextPage,
        hasMore: hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleSeeLzOnly() {
    state = state.copyWith(seeLzOnly: !state.seeLzOnly);
    refresh();
  }

  void setSortType(CommentSortType type) {
    if (state.sortType == type) return;
    state = state.copyWith(sortType: type);
    refresh();
  }

  /// 针对主题帖/主楼的点赞操作，与卡片和全局保持 100% 状态一致
  Future<void> toggleThreadAgree({
    required bool currentAgreed,
    required int currentAgreeNum,
    String? firstPostId,
  }) async {
    final account = _ref?.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再点赞');
      return;
    }

    final newAgreed = !currentAgreed;
    final newAgreeNum = (currentAgreeNum + (newAgreed ? 1 : -1)).clamp(0, 999999);

    // 0 延迟即刻更新全局与本地状态
    _ref?.read(threadAgreeProvider.notifier).setAgree(threadId, newAgreed, newAgreeNum);

    final targetPostId = (firstPostId != null && firstPostId.isNotEmpty)
        ? firstPostId
        : (state.firstPostId.isNotEmpty
            ? state.firstPostId
            : (state.floors.isNotEmpty && state.floors.first.floor == 1 ? state.floors.first.id : '0'));

    final updatedFloors = List<TiebaFloorModel>.from(state.floors);
    if (updatedFloors.isNotEmpty && updatedFloors.first.floor == 1) {
      updatedFloors[0] = updatedFloors.first.copyWith(
        isAgreed: newAgreed,
        agreeNum: newAgreeNum,
      );
    }
    state = state.copyWith(
      isAgreed: newAgreed,
      agreeNum: newAgreeNum,
      floors: updatedFloors,
    );

    final tbs = await _ref?.read(authStateProvider.notifier).getValidTbs() ?? account.tbs;

    var result = await _repository.opAgree(
      threadId: threadId,
      postId: targetPostId,
      objType: '3',
      isAgree: newAgreed,
      tbs: tbs,
    );

    // 若返回 TBS 校验失败，通过原生客户端重新刷新并重试一次
    if (!result.success && (result.errorMsg.contains('TBS') || result.errorMsg.contains('tbs'))) {
      final freshTbs = await _ref?.read(authStateProvider.notifier).getValidTbs(forceRefresh: true) ?? '';
      if (freshTbs.isNotEmpty && freshTbs != tbs) {
        result = await _repository.opAgree(
          threadId: threadId,
          postId: targetPostId,
          objType: '3',
          isAgree: newAgreed,
          tbs: freshTbs,
        );
      }
    }

    if (!result.success) {
      // 失败回滚
      _ref?.read(threadAgreeProvider.notifier).setAgree(threadId, currentAgreed, currentAgreeNum);
      if (updatedFloors.isNotEmpty && updatedFloors.first.floor == 1) {
        updatedFloors[0] = updatedFloors.first.copyWith(
          isAgreed: currentAgreed,
          agreeNum: currentAgreeNum,
        );
      }
      state = state.copyWith(
        isAgreed: currentAgreed,
        agreeNum: currentAgreeNum,
        floors: updatedFloors,
      );
      AppToast.showToast(result.errorMsg.isNotEmpty ? result.errorMsg : '点赞失败，请重试');
    } else {
      // 同步到 feed 控制器
      try {
        _ref?.read(feedControllerProvider.notifier).syncThreadAgree(threadId, newAgreed, newAgreeNum);
        _ref?.read(followFeedControllerProvider.notifier).syncThreadAgree(threadId, newAgreed, newAgreeNum);
      } catch (_) {}
    }
  }

  Future<void> toggleFloorAgree(String floorId) async {
    final account = _ref?.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再点赞');
      return;
    }

    final floorIndex = state.floors.indexWhere((f) => f.id == floorId);
    if (floorIndex == -1) return;

    final oldFloor = state.floors[floorIndex];
    // 若点击的是首楼，直接转发给主题帖点赞逻辑
    if (oldFloor.floor == 1) {
      final globalRecord = _ref?.read(threadAgreeProvider)[threadId];
      final curAgreed = globalRecord?.isAgreed ?? state.isAgreed ?? oldFloor.isAgreed;
      final curAgreeNum = globalRecord?.agreeNum ?? state.agreeNum ?? oldFloor.agreeNum;
      return toggleThreadAgree(
        currentAgreed: curAgreed,
        currentAgreeNum: curAgreeNum,
        firstPostId: oldFloor.id,
      );
    }

    final newAgreed = !oldFloor.isAgreed;
    final newAgreeNum = (oldFloor.agreeNum + (newAgreed ? 1 : -1)).clamp(0, 999999);

    final updatedFloors = List<TiebaFloorModel>.from(state.floors);
    updatedFloors[floorIndex] = oldFloor.copyWith(
      isAgreed: newAgreed,
      agreeNum: newAgreeNum,
    );
    state = state.copyWith(floors: updatedFloors);

    final tbs = await _ref?.read(authStateProvider.notifier).getValidTbs() ?? account.tbs;

    var result = await _repository.opAgree(
      threadId: threadId,
      postId: floorId,
      objType: '1',
      isAgree: newAgreed,
      tbs: tbs,
    );

    // 若返回 TBS 校验失败，通过原生客户端重新刷新并重试一次
    if (!result.success && (result.errorMsg.contains('TBS') || result.errorMsg.contains('tbs'))) {
      final freshTbs = await _ref?.read(authStateProvider.notifier).getValidTbs(forceRefresh: true) ?? '';
      if (freshTbs.isNotEmpty && freshTbs != tbs) {
        result = await _repository.opAgree(
          threadId: threadId,
          postId: floorId,
          objType: '1',
          isAgree: newAgreed,
          tbs: freshTbs,
        );
      }
    }

    if (!result.success) {
      // Rollback on failure
      final rollbackFloors = List<TiebaFloorModel>.from(state.floors);
      final idx = rollbackFloors.indexWhere((f) => f.id == floorId);
      if (idx != -1) {
        rollbackFloors[idx] = oldFloor;
        state = state.copyWith(floors: rollbackFloors);
      }
      AppToast.showToast(result.errorMsg.isNotEmpty ? result.errorMsg : '点赞失败，请重试');
    }
  }

  void setForumInfo(String fid, String fname) {
    if (fid.isEmpty && fname.isEmpty) return;
    state = state.copyWith(
      forumId: fid.isNotEmpty ? fid : state.forumId,
      forumName: fname.isNotEmpty ? fname : state.forumName,
    );
  }

  Future<bool> sendReply({
    required String content,
    String? postId,
    String? subPostId,
    String? replyUserId,
    String? replyUserName,
    String? replyUserPortrait,
    String? fallbackFid,
    String? fallbackFname,
  }) async {
    final account = _ref?.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再发表评论');
      return false;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      AppToast.showToast('评论内容不能为空');
      return false;
    }

    final fid = (state.forumId.isNotEmpty ? state.forumId : fallbackFid) ?? '';
    final fname = (state.forumName.isNotEmpty ? state.forumName : fallbackFname) ?? '';

    if (fid.isEmpty || fname.isEmpty) {
      AppToast.showToast('获取吧信息失败，请稍后重试');
      return false;
    }

    state = state.copyWith(isSubmittingReply: true);

    try {
      final tbs = state.tbs.isNotEmpty
          ? state.tbs
          : (await _ref?.read(authStateProvider.notifier).getValidTbs() ?? account.tbs);

      var result = await _repository.addReply(
        threadId: threadId,
        forumId: fid,
        forumName: fname,
        content: trimmed,
        tbs: tbs,
        postId: postId,
        subPostId: subPostId,
        replyUserId: replyUserId,
        replyUserName: replyUserName,
        replyUserPortrait: replyUserPortrait,
        nameShow: account.nameShow.isNotEmpty ? account.nameShow : account.name,
      );

      // 若 TBS 校验失败，通过 authStateProvider 强制刷新 TBS 重试一次
      if (!result.success &&
          (result.errorMsg.contains('TBS') ||
              result.errorMsg.contains('tbs') ||
              result.errorMsg.contains('校验码'))) {
        final freshTbs = await _ref?.read(authStateProvider.notifier).getValidTbs(forceRefresh: true) ?? '';
        if (freshTbs.isNotEmpty && freshTbs != tbs) {
          result = await _repository.addReply(
            threadId: threadId,
            forumId: fid,
            forumName: fname,
            content: trimmed,
            tbs: freshTbs,
            postId: postId,
            subPostId: subPostId,
            replyUserId: replyUserId,
            replyUserName: replyUserName,
            replyUserPortrait: replyUserPortrait,
            nameShow: account.nameShow.isNotEmpty ? account.nameShow : account.name,
          );
        }
      }

      state = state.copyWith(isSubmittingReply: false);

      if (result.success) {
        AppToast.showToast('回复成功');
        await refresh();
        return true;
      } else {
        AppToast.showToast(result.errorMsg.isNotEmpty ? result.errorMsg : '回复失败，请重试');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isSubmittingReply: false);
      AppToast.showToast('发送异常: $e');
      return false;
    }
  }

  Future<bool> deleteFloor(
    String floorId, {
    String? fallbackFid,
    String? fallbackFname,
  }) async {
    final account = _ref?.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再操作');
      return false;
    }

    final floorIndex = state.floors.indexWhere((f) => f.id == floorId);
    if (floorIndex == -1) return false;

    final fid = (state.forumId.isNotEmpty ? state.forumId : fallbackFid) ?? '';
    final fname = (state.forumName.isNotEmpty ? state.forumName : fallbackFname) ?? '';
    if (fid.isEmpty || fname.isEmpty) {
      AppToast.showToast('获取吧信息失败，无法删除');
      return false;
    }

    final tbs = state.tbs.isNotEmpty
        ? state.tbs
        : (await _ref?.read(authStateProvider.notifier).getValidTbs() ?? account.tbs);

    var result = await _repository.deletePost(
      forumId: fid,
      forumName: fname,
      threadId: threadId,
      postId: floorId,
      tbs: tbs,
      isFloor: false,
    );

    if (!result.success &&
        (result.errorMsg.contains('TBS') ||
            result.errorMsg.contains('tbs') ||
            result.errorMsg.contains('校验码'))) {
      final freshTbs = await _ref?.read(authStateProvider.notifier).getValidTbs(forceRefresh: true) ?? '';
      if (freshTbs.isNotEmpty) {
        result = await _repository.deletePost(
          forumId: fid,
          forumName: fname,
          threadId: threadId,
          postId: floorId,
          tbs: freshTbs,
          isFloor: false,
        );
      }
    }

    if (result.success) {
      AppToast.showToast('删除成功');
      final updatedList = List<TiebaFloorModel>.from(state.floors)..removeAt(floorIndex);
      state = state.copyWith(floors: updatedList);
      return true;
    } else {
      AppToast.showToast(result.errorMsg.isNotEmpty ? result.errorMsg : '删除失败，请重试');
      return false;
    }
  }

  Future<bool> deleteSubPost({
    required String subPostId,
    String? fallbackFid,
    String? fallbackFname,
  }) async {
    final account = _ref?.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再操作');
      return false;
    }

    final fid = (state.forumId.isNotEmpty ? state.forumId : fallbackFid) ?? '';
    final fname = (state.forumName.isNotEmpty ? state.forumName : fallbackFname) ?? '';
    if (fid.isEmpty || fname.isEmpty) {
      AppToast.showToast('获取吧信息失败，无法删除');
      return false;
    }

    final tbs = state.tbs.isNotEmpty
        ? state.tbs
        : (await _ref?.read(authStateProvider.notifier).getValidTbs() ?? account.tbs);

    var result = await _repository.deletePost(
      forumId: fid,
      forumName: fname,
      threadId: threadId,
      postId: subPostId,
      tbs: tbs,
      isFloor: false, // 对齐 TiebaLite：不论主楼或楼中楼均传 isfloor: 0
    );

    if (!result.success &&
        (result.errorMsg.contains('TBS') ||
            result.errorMsg.contains('tbs') ||
            result.errorMsg.contains('校验码'))) {
      final freshTbs = await _ref?.read(authStateProvider.notifier).getValidTbs(forceRefresh: true) ?? '';
      if (freshTbs.isNotEmpty) {
        result = await _repository.deletePost(
          forumId: fid,
          forumName: fname,
          threadId: threadId,
          postId: subPostId,
          tbs: freshTbs,
          isFloor: false,
        );
      }
    }

    if (result.success) {
      AppToast.showToast('删除成功');
      await refresh();
      return true;
    } else {
      AppToast.showToast(result.errorMsg.isNotEmpty ? result.errorMsg : '删除失败，请重试');
      return false;
    }
  }

  Future<bool> deleteCurrentThread({
    String? fallbackFid,
    String? fallbackFname,
  }) async {
    final account = _ref?.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.showToast('请先登录后再操作');
      return false;
    }

    final fid = (state.forumId.isNotEmpty ? state.forumId : fallbackFid) ?? '';
    final fname = (state.forumName.isNotEmpty ? state.forumName : fallbackFname) ?? '';
    if (fid.isEmpty || fname.isEmpty) {
      AppToast.showToast('获取吧信息失败，无法删除');
      return false;
    }

    final tbs = state.tbs.isNotEmpty
        ? state.tbs
        : (await _ref?.read(authStateProvider.notifier).getValidTbs() ?? account.tbs);

    var result = await _repository.deleteThread(
      forumId: fid,
      forumName: fname,
      threadId: threadId,
      tbs: tbs,
    );

    if (!result.success &&
        (result.errorMsg.contains('TBS') ||
            result.errorMsg.contains('tbs') ||
            result.errorMsg.contains('校验码'))) {
      final freshTbs = await _ref?.read(authStateProvider.notifier).getValidTbs(forceRefresh: true) ?? '';
      if (freshTbs.isNotEmpty) {
        result = await _repository.deleteThread(
          forumId: fid,
          forumName: fname,
          threadId: threadId,
          tbs: freshTbs,
        );
      }
    }

    if (result.success) {
      AppToast.showToast('帖子已删除');
      return true;
    } else {
      AppToast.showToast(result.errorMsg.isNotEmpty ? result.errorMsg : '删除失败，请重试');
      return false;
    }
  }
}

final detailControllerFamily =
    StateNotifierProvider.family<DetailController, DetailState, String>((ref, threadId) {
  final repo = ref.watch(detailRepositoryProvider);
  return DetailController(repo, threadId, ref);
});


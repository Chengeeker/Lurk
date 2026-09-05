import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import '../../feed/data/models/tieba_thread_model.dart';
import 'models/forum_model.dart';

class ForumRepository {
  final TiebaDioClient _client;
  final Map<String, String> _forumIdCache = {};

  ForumRepository(this._client);

  Future<Map<String, dynamic>> getForumPage({
    required String forumName,
    String? forumId,
    required int page,
    int sortType = 0,
    int tabId = 0,
    int tabType = 0,
    String tabName = '',
    bool isGood = false,
  }) async {
    if (forumId != null && forumId.isNotEmpty) {
      _forumIdCache[forumName] = forumId;
    }

    final bool isGeneralTab =
        tabId > 0 &&
        !isGood &&
        !tabName.contains('精华') &&
        (tabType == 15 || tabId > 1000);

    if (isGeneralTab) {
      String? fid = forumId ?? _forumIdCache[forumName];
      if (fid == null || fid.isEmpty) {
        try {
          final initRes = await _client.post(
            TiebaConstants.pathForumPage,
            data: {'kw': forumName, 'pn': '1', 'rn': '1'},
          );
          if (initRes.data is Map && initRes.data['forum']?['id'] != null) {
            fid = initRes.data['forum']['id'].toString();
            _forumIdCache[forumName] = fid;
          }
        } catch (_) {}
      }

      final res = await _client.post(
        TiebaConstants.pathGeneralTabList,
        data: {
          'forum_id': fid ?? '',
          'kw': forumName,
          'tab_id': tabId.toString(),
          'tab_type': tabType.toString(),
          'tab_name': tabName,
          'is_general_tab': '1',
          'pn': page.toString(),
          'rn': '30',
          'sort_type': sortType.toString(),
        },
      );

      final data = res.data;
      if (data is Map) {
        final Map<String, Map<String, dynamic>> userMap = {};
        final userListRaw = data['user_list'] as List? ?? [];
        for (var u in userListRaw) {
          if (u is Map && u['id'] != null) {
            userMap[u['id'].toString()] = u is Map<String, dynamic>
                ? u
                : Map<String, dynamic>.from(u);
          }
        }

        final rawList =
            (data['general_list'] as List?) ??
            (data['thread_list'] as List?) ??
            [];
        final threads = rawList
            .map(
              (e) => TiebaThreadModel.fromJson(
                e is Map<String, dynamic>
                    ? e
                    : Map<String, dynamic>.from(e as Map),
                userMap: userMap,
              ),
            )
            .toList();

        return {
          'threads': threads,
          'pinned_threads': <TiebaThreadModel>[],
          'has_more': data['has_more'] == 1 || data['has_more'] == '1',
        };
      }
      return {
        'threads': <TiebaThreadModel>[],
        'pinned_threads': <TiebaThreadModel>[],
        'has_more': false,
      };
    }

    final Map<String, dynamic> params = {
      'kw': forumName,
      'pn': page.toString(),
      'rn': '30',
      'sort_type': sortType.toString(),
    };

    if (isGood || tabName.contains('精华')) {
      params['is_good'] = '1';
      params['tab_id'] = '301';
      params['tab_type'] = '12';
    } else if (tabId > 0) {
      params['tab_id'] = tabId.toString();
      if (tabType > 0) {
        params['tab_type'] = tabType.toString();
      }
    }

    final res = await _client.post(TiebaConstants.pathForumPage, data: params);

    final data = res.data;
    if (data is Map) {
      // 1. Build userMap from data['user_list']
      final Map<String, Map<String, dynamic>> userMap = {};
      final userListRaw = data['user_list'] as List? ?? [];
      for (var u in userListRaw) {
        if (u is Map<String, dynamic> && u['id'] != null) {
          userMap[u['id'].toString()] = u;
        }
      }

      // 2. Parse tabs from nav_tab_info or frs_tab_info
      final List<ForumTabModel> tabs = [];
      final navTabRaw = data['nav_tab_info']?['tab'] as List?;
      final frsTabRaw =
          data['frs_tab_info'] as List? ?? data['frs_main_tab_list'] as List?;

      final targetTabs = navTabRaw ?? frsTabRaw;
      if (targetTabs != null && targetTabs.isNotEmpty) {
        for (var item in targetTabs) {
          if (item is Map<String, dynamic>) {
            final t = ForumTabModel.fromJson(item);
            if (!tabs.any((existing) => existing.tabName == t.tabName)) {
              tabs.add(t);
            }
          }
        }
      }

      if (tabs.isEmpty) {
        tabs.add(const ForumTabModel(tabId: 0, tabName: '全部', tabType: 0));
        tabs.add(
          const ForumTabModel(
            tabId: 301,
            tabName: '最新精华',
            tabType: 12,
            isGood: true,
          ),
        );
      } else {
        // Ensure "精华" tab is marked as isGood: true
        final goodIndex = tabs.indexWhere(
          (t) => t.tabName.contains('精华') || t.tabId == 301,
        );
        if (goodIndex != -1) {
          final existing = tabs[goodIndex];
          tabs[goodIndex] = ForumTabModel(
            tabId: existing.tabId == 0 ? 301 : existing.tabId,
            tabName: existing.tabName,
            tabType: existing.tabType == 0 ? 12 : existing.tabType,
            isGood: true,
          );
        } else {
          tabs.insert(
            1,
            const ForumTabModel(
              tabId: 301,
              tabName: '最新精华',
              tabType: 12,
              isGood: true,
            ),
          );
        }
      }

      // 3. Parse forum rule
      ForumRuleModel? rule;
      final ruleRaw = data['forum_rule'];
      if (ruleRaw is Map<String, dynamic>) {
        rule = ForumRuleModel.fromJson(ruleRaw);
      }

      final tbs = data['anti']?['tbs']?.toString() ?? '';
      final forumRaw = data['forum'] as Map<String, dynamic>? ?? {};
      final forum = ForumDetailModel.fromJson(
        forumRaw,
        tabs: tabs,
        rule: rule,
        tbs: tbs,
      );
      if (forum.id.isNotEmpty) {
        _forumIdCache[forumName] = forum.id;
      }

      // 4. Map threads with userMap
      final threadListRaw = data['thread_list'] as List? ?? [];
      final allThreads = threadListRaw
          .map(
            (e) => TiebaThreadModel.fromJson(
              e as Map<String, dynamic>,
              userMap: userMap,
            ),
          )
          .toList();

      final pinnedThreads = allThreads.where((t) => t.isTop).toList();
      final regularThreads = allThreads.where((t) => !t.isTop).toList();

      return {
        'forum': forum,
        'pinned_threads': pinnedThreads,
        'threads': regularThreads,
        'has_more':
            data['page']?['has_more'] == 1 || data['page']?['has_more'] == '1',
      };
    }
    return {
      'threads': <TiebaThreadModel>[],
      'pinned_threads': <TiebaThreadModel>[],
      'has_more': false,
    };
  }

  Future<bool> signForum({
    required String forumName,
    required String forumId,
    required String tbs,
  }) async {
    final res = await _client.post(
      TiebaConstants.pathSign,
      data: {'kw': forumName, 'fid': forumId, 'tbs': tbs},
    );
    final data = res.data;
    return data is Map &&
        (data['error_code'] == 0 || data['error_code'] == '0');
  }

  String? getCachedForumId(String forumName) => _forumIdCache[forumName];

  Future<({bool success, String errorMsg})> likeForum({
    required String forumName,
    required String forumId,
    required String tbs,
  }) async {
    var resolvedFid = (forumId.isNotEmpty && forumId != '0')
        ? forumId
        : (_forumIdCache[forumName] ?? '');
    if (resolvedFid.isEmpty || resolvedFid == '0') {
      try {
        final pageRes = await getForumPage(forumName: forumName, page: 1);
        final f = pageRes['forum'];
        if (f is ForumDetailModel && f.id.isNotEmpty && f.id != '0') {
          resolvedFid = f.id;
          _forumIdCache[forumName] = resolvedFid;
        }
      } catch (_) {}
    }

    try {
      final res = await _client.post(
        TiebaConstants.pathLikeForum,
        data: {
          if (resolvedFid.isNotEmpty) 'fid': resolvedFid,
          'kw': forumName,
          'tbs': tbs,
        },
      );
      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        if (code == 0 || code == '0') {
          return (success: true, errorMsg: '');
        }
        final msg =
            data['error_msg']?.toString() ??
            data['error']?['errmsg']?.toString() ??
            '关注失败';
        return (success: false, errorMsg: msg);
      }
      return (success: false, errorMsg: '关注失败，服务器返回异常');
    } catch (e) {
      return (success: false, errorMsg: '网络异常，请稍后重试');
    }
  }

  Future<({bool success, String errorMsg})> unlikeForum({
    required String forumName,
    required String forumId,
    required String tbs,
  }) async {
    var resolvedFid = (forumId.isNotEmpty && forumId != '0')
        ? forumId
        : (_forumIdCache[forumName] ?? '');
    if (resolvedFid.isEmpty || resolvedFid == '0') {
      try {
        final pageRes = await getForumPage(forumName: forumName, page: 1);
        final f = pageRes['forum'];
        if (f is ForumDetailModel && f.id.isNotEmpty && f.id != '0') {
          resolvedFid = f.id;
          _forumIdCache[forumName] = resolvedFid;
        }
      } catch (_) {}
    }

    try {
      final res = await _client.post(
        TiebaConstants.pathUnlikeForum,
        data: {
          if (resolvedFid.isNotEmpty) 'fid': resolvedFid,
          'kw': forumName,
          'tbs': tbs,
        },
      );
      final data = res.data;
      if (data is Map) {
        final code = data['error_code'];
        if (code == 0 || code == '0') {
          return (success: true, errorMsg: '');
        }
        final msg =
            data['error_msg']?.toString() ??
            data['error']?['errmsg']?.toString() ??
            '取消关注失败';
        return (success: false, errorMsg: msg);
      }
      return (success: false, errorMsg: '取消关注失败，服务器返回异常');
    } catch (e) {
      return (success: false, errorMsg: '网络异常，请稍后重试');
    }
  }

  Future<ForumRuleDetailModel?> getForumRuleDetail(String forumId) async {
    if (forumId.trim().isEmpty || forumId == '0') return null;

    final res = await _client.post(
      TiebaConstants.pathForumRuleDetail,
      data: {'forum_id': forumId},
    );
    final raw = res.data;
    if (raw is! Map) {
      throw const FormatException('官方吧规接口返回了无法解析的数据');
    }

    final topLevel = Map<String, dynamic>.from(raw);
    final errorCode = topLevel['error_code'];
    if (errorCode != null && errorCode != 0 && errorCode != '0') {
      throw StateError(topLevel['error_msg']?.toString() ?? '官方吧规接口返回错误');
    }

    dynamic payload = topLevel;
    for (final key in const [
      'data',
      'result',
      'forum_rule_detail',
      'forum_rule',
    ]) {
      final candidate = payload is Map ? payload[key] : null;
      if (candidate is Map) {
        payload = candidate;
        break;
      }
    }

    if (payload is! Map) {
      throw const FormatException('官方吧规内容结构无法解析');
    }
    return ForumRuleDetailModel.fromJson(Map<String, dynamic>.from(payload));
  }
}

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return ForumRepository(client);
});

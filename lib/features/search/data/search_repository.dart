import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/constants/tieba_constants.dart";
import "../../../core/network/tieba_dio_client.dart";
import "../../feed/data/models/tieba_thread_model.dart";
import "models/tieba_search_model.dart";

class SearchRepository {
  final TiebaDioClient _client;

  SearchRepository(this._client);

  Future<List<TiebaSearchResultModel>> searchPosts({
    required String keyword,
    required int page,
    int sortMode = 0,
    int onlyThread = 1,
    String? forumName,
  }) async {
    final Map<String, dynamic> params = {
      "word": keyword,
      "pn": page.toString(),
      "rn": "20",
      "only_thread": onlyThread.toString(),
      "sm": sortMode.toString(),
      "_client_version": "12.65.1.0",
      "_client_type": "2",
    };
    if (forumName != null && forumName.isNotEmpty) {
      params["kw"] = forumName;
    }

    final res = await _client.post(
      TiebaConstants.pathSearchPost,
      data: params,
    );

    final data = res.data;
    if (data is Map && data["post_list"] is List) {
      final list = data["post_list"] as List;
      final rawResults = list
          .map((e) => TiebaSearchResultModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // 并发富化检索结果：从 pb/page 获取楼主高清头像与贴子首楼图片/多图
      final enriched = await Future.wait(
        rawResults.map((item) async {
          if (item.id.isEmpty) return item;
          try {
            final pbRes = await _client.post(
              TiebaConstants.pathThreadDetail,
              data: {
                "kz": item.id,
                "pn": "1",
                "rn": "1",
                "from": "baidu_appstore",
              },
            ).timeout(const Duration(milliseconds: 2500));

            final pbData = pbRes.data;
            if (pbData is Map) {
              final threadMap = pbData["thread"] as Map<String, dynamic>?;
              final postList = pbData["post_list"] as List? ?? [];
              final firstPost = postList.isNotEmpty ? postList[0] as Map<String, dynamic>? : null;

              String portrait = item.authorPortrait;
              if (portrait.isEmpty && threadMap != null) {
                final a = threadMap["author"] as Map<String, dynamic>?;
                portrait = a?["portrait"]?.toString() ?? "";
              }

              final List<TiebaMediaModel> mediaList = [];
              final Set<String> seenKeys = {};
              if (firstPost != null) {
                final content = firstPost["content"] as List? ?? [];
                for (var c in content) {
                  if (c is Map && (c["type"] == 3 || c["type"] == "3" || c["type"] == 5)) {
                    final m = TiebaMediaModel.fromJson(Map<String, dynamic>.from(c));
                    final key = m.videoUrl.isNotEmpty
                        ? m.videoUrl
                        : (m.originUrl.isNotEmpty ? m.originUrl : m.bigCdnUrl);
                    if (key.isNotEmpty && seenKeys.contains(key)) continue;
                    if (key.isNotEmpty) seenKeys.add(key);
                    mediaList.add(m);
                  }
                }
              }

              return item.copyWith(
                authorPortrait: portrait,
                mediaList: mediaList,
              );
            }
          } catch (_) {}
          return item;
        }),
      );

      return enriched;
    }
    return [];
  }

  Future<SearchForumResultModel> searchForums({required String keyword}) async {
    try {
      final res = await _client.dio.get(
        "https://tieba.baidu.com/mo/q/search/forum",
        queryParameters: {"word": keyword},
      );
      final data = res.data;
      final map = data is Map ? data : null;
      final dataMap = map?["data"] is Map ? map!["data"] as Map : null;
      if (dataMap != null) {
        SearchForumItem? exact;
        if (dataMap["exactMatch"] is Map) {
          exact = SearchForumItem.fromJson(Map<String, dynamic>.from(dataMap["exactMatch"] as Map));
        }
        final List<SearchForumItem> fuzzy = [];
        if (dataMap["fuzzyMatch"] is List) {
          for (var f in dataMap["fuzzyMatch"]) {
            if (f is Map) {
              fuzzy.add(SearchForumItem.fromJson(Map<String, dynamic>.from(f)));
            }
          }
        }
        return SearchForumResultModel(exactMatch: exact, fuzzyMatch: fuzzy);
      }
    } catch (_) {}
    return const SearchForumResultModel();
  }

  Future<SearchUserResultModel> searchUsers({required String keyword}) async {
    try {
      final res = await _client.dio.get(
        "https://tieba.baidu.com/mo/q/search/user",
        queryParameters: {"word": keyword},
      );
      final data = res.data;
      final map = data is Map ? data : null;
      final dataMap = map?["data"] is Map ? map!["data"] as Map : null;
      if (dataMap != null) {
        SearchUserItem? exact;
        if (dataMap["exactMatch"] is Map) {
          exact = SearchUserItem.fromJson(Map<String, dynamic>.from(dataMap["exactMatch"] as Map));
        }
        final List<SearchUserItem> fuzzy = [];
        if (dataMap["fuzzyMatch"] is List) {
          for (var u in dataMap["fuzzyMatch"]) {
            if (u is Map) {
              fuzzy.add(SearchUserItem.fromJson(Map<String, dynamic>.from(u)));
            }
          }
        }
        return SearchUserResultModel(exactMatch: exact, fuzzyMatch: fuzzy);
      }
    } catch (_) {}
    return const SearchUserResultModel();
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return SearchRepository(client);
});

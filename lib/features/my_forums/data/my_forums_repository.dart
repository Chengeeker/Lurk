import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import 'models/followed_forum_model.dart';

class MyForumsRepository {
  final TiebaDioClient _client;

  MyForumsRepository(this._client);

  Future<List<FollowedForumModel>> getFollowedForums({required String uid}) async {
    final res = await _client.post(
      TiebaConstants.pathFollowedForums,
      data: {
        'uid': uid,
      },
    );

    final data = res.data;
    if (data is Map) {
      final listRaw = data['forum_info'] as List? ?? data['forum_list'] as List? ?? [];
      return listRaw
          .map((e) => FollowedForumModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<bool> batchSignIn({required String tbs}) async {
    final res = await _client.post(
      TiebaConstants.pathBatchSign,
      data: {
        'tbs': tbs,
      },
    );
    final data = res.data;
    return data is Map && (data['error_code'] == 0 || data['error_code'] == '0');
  }
}

final myForumsRepositoryProvider = Provider<MyForumsRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return MyForumsRepository(client);
});

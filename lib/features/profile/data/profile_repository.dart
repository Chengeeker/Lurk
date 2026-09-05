import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import '../../feed/data/models/tieba_thread_model.dart';
import 'models/tieba_profile_model.dart';

class ProfileRepository {
  final TiebaDioClient _client;

  ProfileRepository(this._client);

  Future<TiebaProfileModel?> getProfile({required String uid}) async {
    final res = await _client.post(
      TiebaConstants.pathProfile,
      data: {
        'uid': uid,
        'need_post_count': '1',
      },
    );

    final data = res.data;
    if (data is Map && (data['error_code'] == 0 || data['error_code'] == '0')) {
      return TiebaProfileModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<List<TiebaThreadModel>> getUserPosts({required String uid, required int page}) async {
    final res = await _client.post(
      TiebaConstants.pathUserPost,
      data: {
        'uid': uid,
        'pn': page.toString(),
        'rn': '20',
        'is_thread': '1',
        'need_content': '1',
      },
    );

    final data = res.data;
    if (data is Map && data['post_list'] is List) {
      final list = data['post_list'] as List;
      return list.map((e) => TiebaThreadModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<bool> followUser({required String portrait, required String tbs}) async {
    final res = await _client.post(
      TiebaConstants.pathFollow,
      data: {
        'portrait': portrait,
        'tbs': tbs,
      },
    );
    final data = res.data;
    return data is Map && (data['error_code'] == 0 || data['error_code'] == '0');
  }

  Future<bool> unfollowUser({required String portrait, required String tbs}) async {
    final res = await _client.post(
      TiebaConstants.pathUnfollow,
      data: {
        'portrait': portrait,
        'tbs': tbs,
      },
    );
    final data = res.data;
    return data is Map && (data['error_code'] == 0 || data['error_code'] == '0');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return ProfileRepository(client);
});

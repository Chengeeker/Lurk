import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/network/tieba_dio_client.dart';
import 'models/tieba_notification_model.dart';

class NotificationRepository {
  final TiebaDioClient _client;

  NotificationRepository(this._client);

  Future<List<TiebaNotificationModel>> getReplyMe({required int page}) async {
    final res = await _client.post(
      TiebaConstants.pathReplyMe,
      data: {'pn': page.toString()},
    );

    final data = res.data;
    if (data is Map && data['reply_list'] is List) {
      final list = data['reply_list'] as List;
      return list.map((e) => TiebaNotificationModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<TiebaNotificationModel>> getAtMe({required int page}) async {
    final res = await _client.post(
      TiebaConstants.pathAtMe,
      data: {'pn': page.toString()},
    );

    final data = res.data;
    if (data is Map && data['at_list'] is List) {
      final list = data['at_list'] as List;
      return list.map((e) => TiebaNotificationModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(tiebaDioClientProvider);
  return NotificationRepository(client);
});

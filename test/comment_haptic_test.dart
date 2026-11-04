import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/theme/app_theme.dart';
import 'package:lurk/core/utils/haptic_feedback_util.dart';
import 'package:lurk/features/detail/data/detail_repository.dart';
import 'package:lurk/features/detail/data/models/tieba_post_model.dart';
import 'package:lurk/features/detail/presentation/detail_controller.dart';
import 'package:lurk/features/detail/presentation/widgets/floor_item.dart';
import 'package:lurk/features/detail/presentation/widgets/sub_floor_sheet.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Detail extends StateNotifier<DetailState> implements DetailController {
  _Detail() : super(const DetailState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Replies extends DetailRepository {
  _Replies() : super(TiebaDioClient());
  @override
  Future<List<TiebaSubPostModel>> getFloorReplies({
    required String threadId,
    required String postId,
    required int page,
  }) async => const [
    TiebaSubPostModel(
      id: 'reply',
      author: TiebaAuthorModel(id: 'author'),
      contentList: [PostContentSegment(type: 0, text: '长按评论')],
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        paths,
        (call) async => Directory.systemTemp.path,
      );
  tearDownAll(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null),
  );
  for (final nested in [false, true]) {
    for (final enabled in [false, true]) {
      testWidgets(
        'comment long press nested=$nested haptics=$enabled emits once or none',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            StorageService.keyEnableHaptics: enabled,
          });
          final storage = StorageService(await SharedPreferences.getInstance());
          final oldEnabled = HapticFeedbackUtil.isEnabled;
          HapticFeedbackUtil.isEnabled = enabled;
          final calls = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'HapticFeedback.vibrate') calls.add(call);
              return null;
            },
          );
          addTearDown(() {
            HapticFeedbackUtil.isEnabled = oldEnabled;
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            );
          });
          final navigator = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                storageServiceProvider.overrideWithValue(storage),
                authStateProvider.overrideWith((ref) => _Auth()),
                detailControllerFamily('thread')
                    .overrideWith((ref) => _Detail()),
                detailRepositoryProvider.overrideWithValue(_Replies()),
              ],
              child: MaterialApp(
                navigatorKey: navigator,
                theme: AppTheme.lightTheme(),
                home: Scaffold(
                  body: nested
                      ? const SubFloorSheet(
                          threadId: 'thread',
                          postId: 'post',
                          floorNum: 2,
                        )
                      : const FloorItem(
                          threadId: 'thread',
                          floor: TiebaFloorModel(
                            id: 'post',
                            floor: 2,
                            author: TiebaAuthorModel(id: 'author'),
                            contentList: [
                              PostContentSegment(type: 0, text: '长按评论'),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final point = tester.getCenter(find.text('长按评论', findRichText: true));
          final gesture = await tester.startGesture(point);
          // Match a real hold so the app's wall-clock haptic cooldown has elapsed.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(calls.length, enabled ? 1 : 0);
          if (enabled) {
            expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
          }
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/services/saved_thread_preview_service.dart';
import 'package:lurk/core/utils/spring_page_route.dart';
import 'package:lurk/core/widgets/app_web_view_page.dart';
import 'package:lurk/features/detail/data/detail_repository.dart';
import 'package:lurk/features/detail/data/models/tieba_post_model.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/my_forums/presentation/my_forums_controller.dart';
import 'package:lurk/features/profile/data/bookmarks_repository.dart';
import 'package:lurk/features/profile/presentation/widgets/bookmarks_view.dart';
import 'package:lurk/features/profile/presentation/widgets/history_view.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Forums extends StateNotifier<MyForumsState>
    implements MyForumsController {
  _Forums() : super(const MyForumsState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const target = 'https://pan.quark.cn/s/test';
Map<String, dynamic> _detail() => {
  'floors': [
    const TiebaFloorModel(
      id: 'post',
      floor: 1,
      author: TiebaAuthorModel(id: 'author'),
      contentList: [PostContentSegment(type: 1, text: '夸克网盘', url: target)],
    ),
  ],
};

class _Detail extends DetailRepository {
  _Detail() : super(TiebaDioClient());
  int calls = 0;
  bool delay = false;
  final pending = <String, Completer<Map<String, dynamic>>>{};
  @override
  Future<Map<String, dynamic>> getThreadDetail({
    required String threadId,
    required int page,
    bool seeLzOnly = false,
    bool reverse = false,
  }) async {
    calls++;
    return delay
        ? pending.putIfAbsent(threadId, () => Completer()).future
        : _detail();
  }
}

class _Observer extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed = route;
}

TiebaThreadModel _old(String id) => TiebaThreadModel(
  id: id,
  title: '旧记录',
  author: const TiebaAuthorModel(id: 'author'),
  contentSnippet: '网页链接',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final history in [true, false]) {
    testWidgets(
      'actual ${history ? 'history' : 'bookmarks'} page recovers and persists old links',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          StorageService.keyBrowsingHistory: [
            jsonEncode(_old('thread').toJson()),
          ],
          StorageService.keyBookmarks: [jsonEncode(_old('thread').toJson())],
        });
        final storage = StorageService(await SharedPreferences.getInstance());
        final detail = _Detail();
        final observer = _Observer();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              authStateProvider.overrideWith((ref) => _Auth()),
              myForumsControllerProvider.overrideWith((ref) => _Forums()),
              detailRepositoryProvider.overrideWithValue(detail),
            ],
            child: MaterialApp(
              navigatorObservers: [observer],
              home: history ? const HistoryView() : const BookmarksView(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(detail.calls, 1);
        final rich = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == target,
        );
        expect(rich, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(rich);
        final box = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 4),
            )
            .first
            .toRect();
        observer.pushed = null;
        await tester.tapAt(paragraph.localToGlobal(box.center));
        final route = observer.pushed! as SpringPageRoute;
        expect((route.page as AppWebViewPage).url, target);
        route.navigator!.removeRoute(route);
        await tester.pumpAndSettle();
        for (final key in [
          StorageService.keyBrowsingHistory,
          StorageService.keyBookmarks,
        ]) {
          final saved = TiebaThreadModel.fromJson(
            jsonDecode(storage.getStringList(key).single),
          );
          expect(saved.snippetSegments.single.url, target);
        }
      },
    );
  }
  test(
    'saved link recovery coalesces requests and limits concurrency to two',
    () async {
      SharedPreferences.setMockInitialValues({});
      final detail = _Detail()..delay = true;
      final storage = StorageService(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          authStateProvider.overrideWith((ref) => _Auth()),
          detailRepositoryProvider.overrideWithValue(detail),
        ],
      );
      addTearDown(container.dispose);
      final service = container.read(savedThreadPreviewServiceProvider);
      final requests = [
        for (var i = 0; i < 4; i++) service.recover(_old('$i')),
        service.recover(_old('0')),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(detail.calls, 2);
      detail.pending['0']!.complete(_detail());
      detail.pending['1']!.complete(_detail());
      await Future<void>.delayed(Duration.zero);
      expect(detail.calls, 4);
      detail.pending['2']!.complete(_detail());
      detail.pending['3']!.complete(_detail());
      final recovered = await Future.wait(requests);
      expect(
        recovered.every((t) => t.snippetSegments.single.url == target),
        isTrue,
      );
    },
  );
  test('cloud bookmark refresh preserves richer local links', () async {
    final rich = _old('thread').copyWith(
      contentSnippet: '夸克网盘',
      snippetSegments: [const ThreadSnippetSegment('夸克网盘', url: target)],
    );
    SharedPreferences.setMockInitialValues({
      StorageService.bookmarksKeyForAccount('user'): [
        jsonEncode(rich.toJson()),
      ],
    });
    final storage = StorageService(await SharedPreferences.getInstance());
    final repo = BookmarksRepository(TiebaDioClient(), storage);
    await repo.syncOfficialToLocal([_old('thread')], userId: 'user');
    await repo.mergeOfficialToLocal([_old('thread')], userId: 'user');
    expect(
      repo.getLocalBookmarks(userId: 'user').single.snippetSegments.single.url,
      target,
    );
  });
}

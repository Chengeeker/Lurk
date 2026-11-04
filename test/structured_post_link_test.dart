import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/services/link_routing_service.dart';
import 'package:lurk/core/utils/spring_page_route.dart';
import 'package:lurk/core/utils/tieba_text_parser.dart';
import 'package:lurk/core/widgets/app_web_view_page.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/features/detail/data/models/tieba_post_model.dart';
import 'package:lurk/features/detail/presentation/detail_controller.dart';
import 'package:lurk/features/detail/presentation/widgets/floor_item.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Observer extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed = route;
}

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

void main() {
  test('only official web checkurl wrappers resolve to native threads', () {
    final target = Uri.encodeComponent('https://tieba.baidu.com/p/123');
    expect(
      LinkRoutingService.canHandleNatively(
        'https://tieba.baidu.com/mo/q/checkurl?url=$target',
      ),
      isTrue,
    );
    expect(
      LinkRoutingService.canHandleNatively(
        'https://tieba.baidu.com.evil.example/mo/q/checkurl?url=$target',
      ),
      isFalse,
    );
    expect(
      LinkRoutingService.canHandleNatively(
        'https://tieba.baidu.com/other?url=$target',
      ),
      isFalse,
    );
    expect(
      LinkRoutingService.canHandleNatively(
        'https://tieba.baidu.com/mo/q/checkurl?url=javascript%3Aalert(1)',
      ),
      isFalse,
    );
  });
  const target = 'https://pan.quark.cn/s/e0c0079e4291';
  const wrapped =
      'https://tieba.baidu.com/mo/q/checkurl?url=https%3A%2F%2Fpan.quark.cn%2Fs%2Fe0c0079e4291&urlrefer=fd99ae82cea89214ebcd11c1bc795aea';
  test('full display preserves query, fragment, encoding and foreign wrappers', () {
    const full = '$target?pwd=ab12&file=a%2Fb%20c&next=a%26b#folder';
    final wrapper =
        'https://tieba.baidu.com/mo/q/checkurl?url=${Uri.encodeComponent(full)}';
    expect(LinkRoutingService.displayUrl(wrapper), full);
    expect(LinkRoutingService.displayUrl(full), full);
    final foreign =
        'https://example.com/mo/q/checkurl?url=${Uri.encodeComponent(full)}';
    expect(LinkRoutingService.displayUrl(foreign), foreign);
  });
  testWidgets('comment and nested reply preview both display full targets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    final full =
        '$target?pwd=ab12&file=${List.filled(15, 'abcdefgh').join()}#folder';
    final wrapper =
        'https://tieba.baidu.com/mo/q/checkurl?url=${Uri.encodeComponent(full)}';
    final part = PostContentSegment(type: 1, text: '夸克网盘', url: wrapper);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          authStateProvider.overrideWith((ref) => _Auth()),
          detailControllerFamily('thread').overrideWith((ref) => _Detail()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FloorItem(
                threadId: 'thread',
                floor: TiebaFloorModel(
                  id: 'post',
                  floor: 2,
                  author: const TiebaAuthorModel(id: 'author', name: '作者'),
                  contentList: [part],
                  subPostCount: 1,
                  subPosts: [
                    TiebaSubPostModel(
                      id: 'reply',
                      author: const TiebaAuthorModel(
                        id: 'reply-author',
                        name: '回复者',
                      ),
                      contentList: [part],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final rich = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(full),
    );
    expect(rich, findsNWidgets(2));
    for (final paragraph in tester.widgetList<RichText>(rich)) {
      expect(paragraph.maxLines, isNull);
      expect(paragraph.text.toPlainText().contains('夸克网盘'), isFalse);
    }
    for (final element in rich.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final end = paragraph.text.toPlainText().length;
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: end - 1, extentOffset: end),
        ),
        isNotEmpty,
      );
    }
    expect(tester.takeException(), isNull);
  });
  for (final internal in [true, false]) {
    for (final named in [true, false]) {
      testWidgets(
        'structured link opens actual target internal=$internal named=$named',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            StorageService.keyUseInternalBrowser: internal,
          });
          final storage = StorageService(await SharedPreferences.getInstance());
          final observer = _Observer();
          final calls = <MethodCall>[];
          const launcher = MethodChannel('plugins.flutter.io/url_launcher');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            launcher,
            (call) async {
              calls.add(call);
              return true;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(launcher, null),
          );
          final segment = PostContentSegment.fromJson({
            'type': 1,
            'text': named ? '夸克网盘' : '',
            if (named) 'link': wrapped else 'url': target,
          });
          late TextSpan span;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [storageServiceProvider.overrideWithValue(storage)],
              child: MaterialApp(
                navigatorObservers: [observer],
                home: Builder(
                  builder: (context) {
                    span =
                        TiebaTextParser.parseRichText(
                              context,
                              segment.text,
                              linkUrl: segment.url,
                            ).single
                            as TextSpan;
                    return const Scaffold();
                  },
                ),
              ),
            ),
          );
          expect(span.text, target);
          observer.pushed = null;
          (span.recognizer! as TapGestureRecognizer).onTap!();
          if (internal) {
            final route = observer.pushed! as SpringPageRoute;
            expect((route.page as AppWebViewPage).url, target);
            expect(calls, isEmpty);
            route.navigator!.removeRoute(route);
          } else {
            await tester.idle();
            expect(calls.single.arguments['url'], target);
            expect(observer.pushed, isNull);
          }
          span.recognizer!.dispose();
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets('non-web structured target stays plain text', (tester) async {
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span =
                TiebaTextParser.parseRichText(
                      context,
                      '夸克网盘',
                      linkUrl: 'javascript:alert(1)',
                    ).single
                    as TextSpan;
            return const Scaffold();
          },
        ),
      ),
    );
    expect(span.text, '夸克网盘');
    expect(span.recognizer, isNull);
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/services/link_routing_service.dart';
import 'package:lurk/core/utils/spring_page_route.dart';
import 'package:lurk/core/utils/tieba_text_parser.dart';
import 'package:lurk/core/widgets/app_web_view_page.dart';
import 'package:lurk/features/detail/data/models/tieba_post_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Observer extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed = route;
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
          expect(span.text, named ? '夸克网盘' : '网页链接 🔗');
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

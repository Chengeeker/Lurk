import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/utils/spring_page_route.dart';
import 'package:lurk/core/widgets/app_web_view_page.dart';
import 'package:lurk/features/detail/presentation/thread_detail_page.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/feed/presentation/widgets/tieba_card.dart';

class _Observer extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed = route;
}

void main() {
  const target = 'https://pan.quark.cn/s/e0c0079e4291';
  final wrapped =
      'https://tieba.baidu.com/mo/q/checkurl?url=${Uri.encodeComponent(target)}';
  for (final mode in ['structured', 'plain', 'text']) {
    testWidgets('long $mode preview wraps at narrow width and large text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final longUrl =
          '$target?pwd=ab12&file=${List.filled(25, 'abcdefgh').join()}#folder';
      final model = TiebaThreadModel.fromJson({
        'id': 'long',
        'title': '长链接',
        'abstract': [
          {
            'type': mode == 'structured' ? 1 : 0,
            'text': mode == 'structured'
                ? '夸克网盘'
                : mode == 'plain'
                ? longUrl
                : List.filled(80, '普通正文').join(),
            if (mode == 'structured') 'link': longUrl,
          },
        ],
      });
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                body: SingleChildScrollView(child: TiebaCard(thread: model)),
              ),
            ),
          ),
        ),
      );
      final rich = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains(mode == 'text' ? '普通正文' : target),
      );
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      if (mode == 'text') {
        expect(paragraph.maxLines, 3);
      } else {
        expect(paragraph.text.toPlainText(), longUrl);
        expect(paragraph.maxLines, isNull);
        final lastGlyph = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: longUrl.length - 1,
            extentOffset: longUrl.length,
          ),
        );
        expect(lastGlyph, isNotEmpty);
        expect(lastGlyph.last.bottom, lessThanOrEqualTo(paragraph.size.height));
        expect(paragraph.text.toPlainText().contains('pwd=ab12&file='), isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final field in ['abstract', 'first_post_content', 'content']) {
    test(
      '$field links retain names and destinations through cache and like updates',
      () {
        final model = TiebaThreadModel.fromJson({
          'id': 'test',
          'title': '帖子标题',
          field: [
            {'type': 0, 'text': '前文 '},
            {'type': 1, 'text': '下载', 'link': target},
            {'type': 0, 'text': ' 或 '},
            {'type': 1, 'text': '下载', 'link': 'https://example.com/other'},
            {'type': 0, 'text': ' 后文'},
          ],
        });
        final restored = TiebaThreadModel.fromJson(
          model.copyWith(isAgreed: true).toJson(),
        );
        expect(restored.contentSnippet, '前文 下载 或 下载 后文');
        expect(
          restored.snippetSegments
              .where((s) => s.url != null)
              .map((s) => s.url)
              .toList(),
          [target, 'https://example.com/other'],
        );
        expect(
          restored.copyWith(contentSnippet: '新摘要').snippetSegments,
          isEmpty,
        );
      },
    );
  }
  for (final internal in [true, false]) {
    for (final mode in ['named', 'generic', 'plain']) {
      testWidgets(
        'card preview opens target directly $mode internal=$internal',
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
          final model = TiebaThreadModel.fromJson({
            'id': '11159294397',
            'title': '帖子标题',
            'abstract': [
              {'type': 0, 'text': '前文 '},
              if (mode == 'plain')
                {'type': 0, 'text': wrapped}
              else
                {
                  'type': 1,
                  'text': mode == 'named' ? '夸克网盘' : '网页链接',
                  'link': wrapped,
                },
              {'type': 0, 'text': ' 后文'},
            ],
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [storageServiceProvider.overrideWithValue(storage)],
              child: MaterialApp(
                navigatorObservers: [observer],
                home: Scaffold(
                  body: TiebaCard(
                    thread: TiebaThreadModel.fromJson(model.toJson()),
                  ),
                ),
              ),
            ),
          );
          final rich = find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('前文'),
          );
          expect(rich, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(rich);
          final text = paragraph.text.toPlainText();
          expect(text, '前文 $target 后文');
          expect(text.contains('网页链接'), isFalse);
          final start = text.indexOf(target);
          final box = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: start, extentOffset: start + 4),
              )
              .first
              .toRect();
          observer.pushed = null;
          await tester.tapAt(paragraph.localToGlobal(box.center));
          if (internal) {
            final route = observer.pushed! as SpringPageRoute;
            expect(route.page, isA<AppWebViewPage>());
            expect((route.page as AppWebViewPage).url, target);
            route.navigator!.removeRoute(route);
          } else {
            await tester.idle();
            expect(observer.pushed, isNull);
            expect(calls.single.arguments['url'], target);
          }
          await tester.pumpAndSettle();
          await tester.tap(find.text('帖子标题'));
          final articleRoute = observer.pushed! as SpringPageRoute;
          expect(articleRoute.page, isA<ThreadDetailPage>());
          articleRoute.navigator!.removeRoute(articleRoute);
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

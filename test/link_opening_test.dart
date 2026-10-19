import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/utils/spring_page_route.dart';
import 'package:lurk/core/utils/tieba_text_parser.dart';
import 'package:lurk/core/widgets/app_web_view_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

void main() {
  for (final savedPreference in <bool?>[null, true, false]) {
    final useInternal = savedPreference ?? true;
    testWidgets('rendered links respect browser preference $savedPreference', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        if (savedPreference != null)
          StorageService.keyUseInternalBrowser: savedPreference,
      });
      final storage = StorageService(await SharedPreferences.getInstance());
      final observer = _RouteObserver();
      final externalCalls = <MethodCall>[];
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
        call,
      ) async {
        externalCalls.add(call);
        return true;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcher,
          null,
        );
      });

      late TextSpan link;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            navigatorObservers: [observer],
            home: Builder(
              builder: (context) {
                link =
                    TiebaTextParser.parseRichText(
                          context,
                          'HTTPS://example.com/article',
                        ).single
                        as TextSpan;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      observer.lastPushed = null;
      (link.recognizer! as TapGestureRecognizer).onTap!();

      if (useInternal) {
        final route = observer.lastPushed! as SpringPageRoute;
        expect(route.page, isA<AppWebViewPage>());
        expect(
          (route.page as AppWebViewPage).url,
          'https://example.com/article',
        );
        expect(externalCalls, isEmpty);
        // Inspect routing without mounting the native WebView in a widget test.
        route.navigator!.removeRoute(route);
      } else {
        await tester.idle();
        expect(observer.lastPushed, isNull);
        expect(
          externalCalls.single.arguments['url'],
          'https://example.com/article',
        );
        expect(externalCalls.single.arguments['useWebView'], false);
      }
      link.recognizer!.dispose();
      await tester.pumpAndSettle();
    });
  }
}

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/constants/tieba_constants.dart';
import 'package:lurk/core/widgets/app_network_image.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/feed/presentation/widgets/nine_grid_view.dart';

class _Observer extends NavigatorObserver {
  int galleryPushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) galleryPushes++;
  }
}

void main() {
  for (final count in [1, 2, 4]) {
    testWidgets(
      'image keeps its tap target during Hero return ($count images)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = StorageService(await SharedPreferences.getInstance());
        const url = 'https://example.com/gallery-hit-test.png';
        final image = await tester.runAsync(
          () => createTestImage(width: 100, height: 100),
        );
        final provider = ExtendedNetworkImageProvider(
          url,
          cache: true,
          headers: {'User-Agent': TiebaConstants.defaultUserAgent},
        );
        final cache = PaintingBinding.instance.imageCache;
        cache.putIfAbsent(
          await provider.obtainKey(ImageConfiguration.empty),
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image!)),
          ),
        );
        addTearDown(() {
          cache.clear();
          cache.clearLiveImages();
        });
        final navigator = GlobalKey<NavigatorState>();
        final observer = _Observer();
        var articleTaps = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              navigatorKey: navigator,
              navigatorObservers: [observer],
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: Material(
                      child: InkWell(
                        onTap: () => articleTaps++,
                        child: NineGridView(
                          mediaList: List.generate(
                            count,
                            (_) => const TiebaMediaModel(
                              originUrl: url,
                              bigCdnUrl: url,
                              thumbUrl: url,
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final point = tester.getCenter(find.byType(AppNetworkImage).first);
        await tester.tapAt(point);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tapAt(point);
        expect(articleTaps, 0);
        expect(observer.galleryPushes, 2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        // The source also remains clickable after the return flight completes.
        await tester.tapAt(point);
        expect(articleTaps, 0);
        expect(observer.galleryPushes, 3);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
      },
    );
  }
}

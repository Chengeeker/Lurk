import 'dart:async';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/constants/tieba_constants.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/widgets/app_network_image.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/feed/presentation/widgets/nine_grid_view.dart';
import 'package:lurk/features/detail/presentation/widgets/image_gallery_page.dart';

Future<ui.Image> _pixels(
  WidgetTester tester,
  Color color,
  int width,
  int height,
) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(color, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }))!;
}

Future<List<int>> _flightPixel(WidgetTester tester) async {
  final plane = find.byKey(const ValueKey('gallery-image-flight-plane'));
  expect(plane, findsOneWidget);
  final size = tester.getSize(plane);
  final painter = tester.widget<CustomPaint>(plane).painter!;
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    picture.dispose();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = ((size.height ~/ 2) * image.width + size.width ~/ 2) * 4;
    final pixel = data.buffer.asUint8List().sublist(offset, offset + 4);
    image.dispose();
    return pixel;
  }))!;
}

void main() {
  testWidgets(
    'real card keeps loaded thumbnails through slow open, reentry and next page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final blue = await _pixels(tester, Colors.blue, 40, 80);
      final red = await _pixels(tester, Colors.red, 80, 160);
      const thumb = 'https://example.com/preview.png';
      const full = 'https://example.com/original.png';
      final original = Completer<ImageInfo>();
      for (final url in [thumb, full]) {
        for (final width in <int?>[null, 160]) {
          final provider = ExtendedImage.network(
            url,
            cache: true,
            cacheWidth: width,
            headers: {'User-Agent': TiebaConstants.defaultUserAgent},
          ).image;
          final key = await provider.obtainKey(ImageConfiguration.empty);
          tester.binding.imageCache.putIfAbsent(
            key,
            () => OneFrameImageStreamCompleter(
              url == full && width == null
                  ? original.future
                  : Future.value(ImageInfo(image: blue.clone())),
            ),
          );
        }
      }
      final nav = GlobalKey<NavigatorState>();
      var articleOpens = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            navigatorKey: nav,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: Material(
                    child: InkWell(
                      onTap: () => articleOpens++,
                      child: NineGridView(
                        mediaList: List.generate(
                          2,
                          (_) => const TiebaMediaModel(
                            originUrl: full,
                            bigCdnUrl: thumb,
                            thumbUrl: thumb,
                            width: 40,
                            height: 80,
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
      await tester.pump();
      final point = tester.getCenter(find.byType(AppNetworkImage).first);
      await tester.tapAt(point);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(await _flightPixel(tester), [33, 150, 243, 255]);
      for (var cycle = 0; cycle < 2; cycle++) {
        nav.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tapAt(point);
        await tester.pump();
        for (final ms in [1, 16, 33]) {
          await tester.pump(Duration(milliseconds: ms));
          expect(await _flightPixel(tester), [33, 150, 243, 255]);
        }
      }
      expect(articleOpens, 0);
      expect(original.isCompleted, isFalse);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        find
                .byKey(const ValueKey('gallery-opening-preview'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('gallery-loading-preview-0'))
                .evaluate()
                .isNotEmpty,
        isTrue,
      );
      final page = tester.widget<ExtendedImageGesturePageView>(
        find.byType(ExtendedImageGesturePageView),
      );
      page.controller.jumpToPage(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final preview = find.byKey(const ValueKey('gallery-loading-preview-1'));
      expect(preview, findsOneWidget);
      original.complete(ImageInfo(image: red.clone()));
      await tester.pump();
      await tester.pump();
      expect(preview, findsNothing);
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox());
      tester.binding.imageCache.clear();
      tester.binding.imageCache.clearLiveImages();
      blue.dispose();
      red.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  for (final cover in [false, true]) {
    for (final decode in ['during-flight', 'after-flight', 'failed']) {
      testWidgets('thumbnail pixels survive $decode original (cover=$cover)', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final storage = StorageService(await SharedPreferences.getInstance());
        final blue = await _pixels(tester, Colors.blue, 40, 80);
        final red = await _pixels(tester, Colors.red, 80, 160);
        const url = 'https://example.com/slow-original.png';
        final original = Completer<ImageInfo>();
        final provider = ExtendedNetworkImageProvider(
          url,
          cache: true,
          headers: {'User-Agent': TiebaConstants.defaultUserAgent},
        );
        final key = await provider.obtainKey(ImageConfiguration.empty);
        tester.binding.imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(original.future),
        );
        final nav = GlobalKey<NavigatorState>();
        final scope = Object();
        const sourceKey = ValueKey('source-thumbnail');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              navigatorKey: nav,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: GestureDetector(
                      key: sourceKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ImageGalleryPage.open(
                        context,
                        images: [url],
                        heroScope: scope,
                      ),
                      child: ImageGalleryHeroThumbnail(
                        scope: scope,
                        index: 0,
                        mediaIdentity: url,
                        thumbnailUsesCover: cover,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: RawImage(
                              image: blue,
                              fit: cover ? BoxFit.cover : BoxFit.contain,
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
        await tester.tap(find.byKey(sourceKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(original.isCompleted, isFalse);
        expect(await _flightPixel(tester), [33, 150, 243, 255]);
        if (decode == 'during-flight') {
          original.complete(ImageInfo(image: red.clone()));
          await tester.pump();
          await tester.pump();
          // Decoded original replaces the actual painted flight, before 330ms.
          expect(await _flightPixel(tester), [244, 67, 54, 255]);
        } else if (decode == 'failed') {
          original.completeError(StateError('synthetic decode failure'));
          await tester.pump();
          await tester.pump();
          expect(await _flightPixel(tester), [33, 150, 243, 255]);
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        final preview = find.byKey(const ValueKey('gallery-opening-preview'));
        if (decode != 'during-flight') {
          expect(preview, findsOneWidget);
          expect(
            tester.widget<RawImage>(preview).image!.isCloneOf(blue),
            isTrue,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          if (decode == 'after-flight') {
            original.complete(ImageInfo(image: red.clone()));
            await tester.pump();
            await tester.pump();
          } else {
            expect(find.text('点击重试'), findsOneWidget);
          }
        }
        if (decode != 'failed') {
          expect(preview, findsNothing);
          expect(find.byType(ExtendedImageGesture), findsOneWidget);
          expect(
            tester
                .widgetList<ExtendedImage>(find.byType(ExtendedImage))
                .where((image) => image.mode == ExtendedImageMode.gesture)
                .single
                .onDoubleTap,
            isNotNull,
          );
        }
        if (decode == 'during-flight' && cover) {
          final gesture = find.byType(ExtendedImageGesture);
          final center = tester.getCenter(gesture);
          await tester.tapAt(center);
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tapAt(center);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final state = tester.state<ExtendedImageGestureState>(gesture);
          expect(state.gestureDetails!.totalScale, greaterThan(1));
        }
        nav.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpWidget(const SizedBox());
        tester.binding.imageCache.evict(key);
        tester.binding.imageCache.clear();
        tester.binding.imageCache.clearLiveImages();
        blue.dispose();
        red.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

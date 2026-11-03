import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/core/constants/tieba_constants.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/widgets/app_network_image.dart';
import 'package:lurk/features/detail/data/models/tieba_post_model.dart';
import 'package:lurk/features/detail/presentation/detail_controller.dart';
import 'package:lurk/features/detail/presentation/widgets/floor_item.dart';
import 'package:lurk/features/detail/presentation/widgets/image_gallery_page.dart';
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

class _Observer extends NavigatorObserver {
  int pushes = 0;
  Route<dynamic>? last;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      pushes++;
      last = route;
    }
  }
}

void main() {
  testWidgets(
    'comment pictures use stable distinct Hero tags and reopen on return',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      const url = 'https://example.com/comment-hero.png';
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
      late StateSetter rebuild;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            authStateProvider.overrideWith((ref) => _Auth()),
            detailControllerFamily('thread').overrideWith((ref) => _Detail()),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final id in ['first', 'second'])
                          FloorItem(
                            threadId: 'thread',
                            floor: TiebaFloorModel(
                              id: id,
                              floor: 2,
                              author: const TiebaAuthorModel(id: 'author'),
                              contentList: const [
                                PostContentSegment(
                                  type: 3,
                                  text: '',
                                  originSrc: url,
                                ),
                                PostContentSegment(
                                  type: 3,
                                  text: '',
                                  originSrc: url,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final before = tester
          .widgetList<ImageGalleryHeroThumbnail>(
            find.byType(ImageGalleryHeroThumbnail),
          )
          .map((w) => (w.scope, w.index, w.mediaIdentity))
          .toList();
      expect(before.length, 4);
      expect(before.toSet().length, 4);
      rebuild(() {});
      await tester.pump();
      final thumbnails = tester
          .widgetList<ImageGalleryHeroThumbnail>(
            find.byType(ImageGalleryHeroThumbnail),
          )
          .toList();
      expect(
        thumbnails.map((w) => (w.scope, w.index, w.mediaIdentity)).toList(),
        before,
      );
      final selected = thumbnails[1];
      final point = tester.getCenter(find.byType(AppNetworkImage).at(1));
      await tester.tapAt(point);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final gallery = tester.widget<ImageGalleryPage>(
        find.byType(ImageGalleryPage),
      );
      expect(gallery.initialIndex, 1);
      expect(gallery.heroScope, selected.scope);
      expect(
        (observer.last! as PageRoute).transitionDuration,
        const Duration(milliseconds: 330),
      );
      expect(
        (observer.last! as PageRoute).reverseTransitionDuration,
        const Duration(milliseconds: 200),
      );
      final tag = ImageGalleryHeroTag(
        scope: selected.scope,
        index: 1,
        mediaIdentity: url,
      );
      expect(
        tester
            .widgetList<Hero>(find.byType(Hero, skipOffstage: false))
            .where((w) => w.tag == tag)
            .length,
        2,
      );
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(point);
      expect(observer.pushes, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    },
  );
}

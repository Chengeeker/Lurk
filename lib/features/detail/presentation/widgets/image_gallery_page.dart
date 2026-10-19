import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderClipRRect, RenderImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../core/services/media_save_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/haptic_feedback_util.dart';
import '../../../../core/constants/tieba_constants.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../feed/presentation/widgets/tieba_video_player_page.dart';

@immutable
class GalleryMediaItem {
  const GalleryMediaItem({
    required this.imageUrl,
    this.isVideo = false,
    this.videoUrl = '',
  });

  final String imageUrl;
  final bool isVideo;
  final String videoUrl;
}

@immutable
class ImageGalleryHeroTag {
  const ImageGalleryHeroTag({
    required this.scope,
    required this.index,
    required this.mediaIdentity,
    this.thumbnailUsesCover = true,
  });

  final Object scope;
  final int index;
  final String mediaIdentity;
  final bool thumbnailUsesCover;

  @override
  bool operator ==(Object other) =>
      other is ImageGalleryHeroTag &&
      other.scope == scope &&
      other.index == index &&
      other.mediaIdentity == mediaIdentity;

  @override
  int get hashCode => Object.hash(scope, index, mediaIdentity);
}

Widget imageGalleryHeroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;
  if (flightDirection != HeroFlightDirection.pop) return toHero.child;

  final tag = fromHero.tag;
  final target = toHeroContext.findRenderObject();
  if (tag is! ImageGalleryHeroTag ||
      !tag.thumbnailUsesCover ||
      target is! RenderBox ||
      !target.hasSize ||
      target.size.width <= 0 ||
      target.size.height <= 0) {
    return fromHero.child;
  }

  final sourceGeometry = _HeroImageGeometry.capture(fromHeroContext);
  final targetGeometry = _HeroImageGeometry.capture(toHeroContext);
  if (sourceGeometry == null || targetGeometry == null) return fromHero.child;
  return _HeroReturnImageMorph(
    animation: animation,
    image: sourceGeometry.image.clone(),
    source: sourceGeometry,
    target: targetGeometry,
  );
}

class _HeroImageGeometry {
  const _HeroImageGeometry(this.image, this.rect, this.radius);

  final ui.Image image;
  final Rect rect;
  final BorderRadius radius;

  static _HeroImageGeometry? capture(BuildContext context) {
    final root = context.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return null;

    final direction = Directionality.of(context);
    _HeroImageGeometry? result;
    var radius = BorderRadius.zero;
    void visit(RenderObject object) {
      if (result != null) return;
      if (object is RenderClipRRect) {
        radius = object.borderRadius.resolve(direction);
      }

      ui.Image? image;
      BoxFit? fit;
      AlignmentGeometry alignment = Alignment.center;
      Rect? gestureRect;
      if (object is ExtendedRenderImage) {
        image = object.image;
        fit = object.fit;
        alignment = object.alignment;
        final gesture = object.gestureDetails;
        if (gesture?.destinationRect != null && gesture?.layoutRect != null) {
          gestureRect = gesture!.destinationRect!.shift(
            -gesture.layoutRect!.topLeft,
          );
        }
      } else if (object is RenderImage) {
        image = object.image;
        fit = object.fit;
        alignment = object.alignment;
      }

      if (image != null && object is RenderBox && object.hasSize) {
        final pixels = Size(image.width.toDouble(), image.height.toDouble());
        final align = alignment.resolve(direction);
        final fitted = applyBoxFit(
          fit ?? BoxFit.scaleDown,
          pixels,
          object.size,
        );
        final crop = align.inscribe(fitted.source, Offset.zero & pixels);
        final painted =
            gestureRect ??
            align.inscribe(fitted.destination, Offset.zero & object.size);
        final scaleX = painted.width / crop.width;
        final scaleY = painted.height / crop.height;
        final fullImage = Rect.fromLTWH(
          painted.left - crop.left * scaleX,
          painted.top - crop.top * scaleY,
          pixels.width * scaleX,
          pixels.height * scaleY,
        );
        result = _HeroImageGeometry(
          image,
          MatrixUtils.transformRect(object.getTransformTo(root), fullImage),
          radius,
        );
        return;
      }
      object.visitChildren(visit);
    }

    visit(root);
    return result;
  }
}

class _HeroReturnImageMorph extends StatefulWidget {
  const _HeroReturnImageMorph({
    required this.animation,
    required this.image,
    required this.source,
    required this.target,
  });

  final Animation<double> animation;
  final ui.Image image;
  final _HeroImageGeometry source;
  final _HeroImageGeometry target;

  @override
  State<_HeroReturnImageMorph> createState() => _HeroReturnImageMorphState();
}

class _HeroReturnImageMorphState extends State<_HeroReturnImageMorph> {
  @override
  void dispose() {
    widget.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('gallery-return-image-plane'),
    painter: _HeroReturnPainter(
      widget.image,
      widget.animation,
      widget.source,
      widget.target,
    ),
    child: const SizedBox.expand(),
  );
}

class _HeroReturnPainter extends CustomPainter {
  _HeroReturnPainter(this.image, this.animation, this.source, this.target)
    : super(repaint: animation);

  final ui.Image image;
  final Animation<double> animation;
  final _HeroImageGeometry source;
  final _HeroImageGeometry target;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = (1 - animation.value).clamp(0.0, 1.0);
    final imageRect = Rect.lerp(source.rect, target.rect, progress)!;
    final radius = BorderRadius.lerp(source.radius, target.radius, progress)!;
    canvas.save();
    canvas.clipRRect(radius.toRRect(Offset.zero & size));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeroReturnPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.target != target ||
      oldDelegate.animation != animation;
}

class ImageGalleryHeroThumbnail extends StatelessWidget {
  const ImageGalleryHeroThumbnail({
    super.key,
    required this.scope,
    required this.index,
    required this.mediaIdentity,
    required this.child,
    this.thumbnailUsesCover = true,
  });

  final Object scope;
  final int index;
  final String mediaIdentity;
  final Widget child;
  final bool thumbnailUsesCover;

  @override
  Widget build(BuildContext context) => Hero(
    tag: ImageGalleryHeroTag(
      scope: scope,
      index: index,
      mediaIdentity: mediaIdentity,
      thumbnailUsesCover: thumbnailUsesCover,
    ),
    flightShuttleBuilder: imageGalleryHeroFlightShuttleBuilder,
    child: child,
  );
}

class ImageGalleryPage extends ConsumerStatefulWidget {
  final List<String> images;
  final List<GalleryMediaItem>? mediaItems;
  final int initialIndex;
  final String? folderName;
  final Object? heroScope;
  final String? threadId;

  const ImageGalleryPage({
    super.key,
    required this.images,
    this.mediaItems,
    this.initialIndex = 0,
    this.folderName,
    this.heroScope,
    this.threadId,
  });

  static void open(
    BuildContext context, {
    List<String>? images,
    List<GalleryMediaItem>? mediaItems,
    int initialIndex = 0,
    String? folderName,
    Object? heroScope,
    String? threadId,
  }) {
    final imageUrls =
        images ?? mediaItems?.map((item) => item.imageUrl).toList();
    if (imageUrls == null) {
      throw ArgumentError('Provide images or mediaItems.');
    }
    if (imageUrls.isEmpty) return;
    if (mediaItems != null && mediaItems.length != imageUrls.length) {
      throw ArgumentError('images and mediaItems must have the same length.');
    }
    final startIndex = initialIndex.clamp(0, imageUrls.length - 1);
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, __) => ImageGalleryPage(
          images: imageUrls,
          mediaItems: mediaItems,
          initialIndex: startIndex,
          folderName: folderName,
          heroScope: heroScope,
          threadId: threadId,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  ConsumerState<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends ConsumerState<ImageGalleryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _doubleTapController;
  Animation<double>? _doubleTapAnimation;
  VoidCallback? _doubleTapListener;
  late int _currentIndex;
  late ExtendedPageController _pageController;
  late PageController _thumbnailController;
  late final ValueNotifier<int> _activeMediaIndex;
  Animation<double>? _routeAnimation;
  bool _thumbnailUserScrolling = false;
  bool _thumbnailSettling = false;
  bool _mainUserScrolling = false;
  int _thumbnailSyncEpoch = 0;
  final Expando<ExtendedImageGesture> _pagingImages = Expando();
  bool _showChrome = true;
  bool _routeTransitionComplete = false;
  bool _videoFullscreen = false;
  Timer? _galleryTapTimer;
  Offset? _pendingGalleryTapPosition;
  Duration? _pendingGalleryTapTime;
  int? _trackedGalleryPointer;
  Offset? _galleryPointerDownPosition;
  bool _galleryPointerMoved = false;
  bool _galleryPointerMultitouch = false;
  bool _galleryDoubleTapCandidate = false;
  double _videoBottomControlsHeight = 0;
  double? _thumbnailScrollBottom;
  String _currentVideoUrl = '';

  GalleryMediaItem _mediaAt(int index) =>
      widget.mediaItems?[index] ??
      GalleryMediaItem(imageUrl: widget.images[index]);

  double get _thumbnailBottom =>
      _thumbnailScrollBottom ??
      (_mediaAt(_currentIndex).isVideo && _videoBottomControlsHeight > 0
          ? _videoBottomControlsHeight + 8
          : MediaQuery.paddingOf(context).bottom + 32);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _activeMediaIndex = ValueNotifier(_currentIndex);
    _currentVideoUrl = _mediaAt(widget.initialIndex).videoUrl;
    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
    _thumbnailController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.16,
    )..addListener(_syncMainPageToThumbnail);
    _doubleTapController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (identical(routeAnimation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = routeAnimation;
    _routeTransitionComplete =
        routeAnimation?.status == AnimationStatus.completed;
    routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    final complete = status == AnimationStatus.completed;
    if (complete == _routeTransitionComplete) return;
    setState(() => _routeTransitionComplete = complete);
  }

  @override
  void dispose() {
    _thumbnailSyncEpoch++;
    _cancelPendingGalleryTap();
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _thumbnailController
      ..removeListener(_syncMainPageToThumbnail)
      ..dispose();
    _activeMediaIndex.dispose();
    _pageController.dispose();
    if (_doubleTapListener != null) {
      _doubleTapAnimation?.removeListener(_doubleTapListener!);
    }
    _doubleTapController.dispose();
    super.dispose();
  }

  void _animateDoubleTap(ExtendedImageGestureState state) {
    _cancelPendingGalleryTap();
    HapticFeedbackUtil.light();
    final pointerPosition = state.pointerDownPosition;
    final currentScale = state.gestureDetails?.totalScale ?? 1.0;
    final targetScale = currentScale <= 1.05
        ? 2.5
        : currentScale <= 3.6
        ? 6.0
        : 1.0;

    _doubleTapController
      ..stop()
      ..reset();
    if (_doubleTapListener != null) {
      _doubleTapAnimation?.removeListener(_doubleTapListener!);
    }
    _doubleTapAnimation = Tween<double>(begin: currentScale, end: targetScale)
        .animate(
          CurvedAnimation(
            parent: _doubleTapController,
            curve: Curves.easeOutCubic,
          ),
        );
    _doubleTapListener = () => state.handleDoubleTap(
      scale: _doubleTapAnimation!.value,
      doubleTapPosition: pointerPosition,
    );
    _doubleTapAnimation!.addListener(_doubleTapListener!);
    _doubleTapController.forward();
  }

  Widget _withGalleryHero(int index, Widget child) {
    final scope = widget.heroScope;
    if (scope == null || _mediaAt(index).isVideo) {
      return child;
    }
    return HeroMode(
      enabled: index == _currentIndex,
      child: Hero(
        tag: ImageGalleryHeroTag(
          scope: scope,
          index: index,
          mediaIdentity: widget.images[index],
        ),
        flightShuttleBuilder: imageGalleryHeroFlightShuttleBuilder,
        child: child,
      ),
    );
  }

  void _handleGalleryTapAt(Offset globalPosition) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final x = globalPosition.dx;
    if (x >= screenWidth / 3 && x < screenWidth * 2 / 3) {
      setState(() => _showChrome = !_showChrome);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleGalleryPointerDown(PointerDownEvent event) {
    if (_trackedGalleryPointer != null) {
      _galleryPointerMultitouch = true;
      return;
    }

    _trackedGalleryPointer = event.pointer;
    _galleryPointerDownPosition = event.position;
    _galleryPointerMoved = false;
    _galleryPointerMultitouch = false;

    final pendingPosition = _pendingGalleryTapPosition;
    final pendingTime = _pendingGalleryTapTime;
    _galleryDoubleTapCandidate =
        pendingPosition != null &&
        pendingTime != null &&
        event.timeStamp - pendingTime <= kDoubleTapTimeout &&
        (event.position - pendingPosition).distance <= kDoubleTapSlop;
    if (_galleryDoubleTapCandidate) {
      _galleryTapTimer?.cancel();
      _galleryTapTimer = null;
    } else {
      _dispatchPendingGalleryTap();
    }
  }

  void _handleGalleryPointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackedGalleryPointer) return;
    final start = _galleryPointerDownPosition;
    if (start != null && (event.position - start).distance > kTouchSlop) {
      _galleryPointerMoved = true;
    }
  }

  void _handleGalleryPointerUp(PointerUpEvent event) {
    if (event.pointer != _trackedGalleryPointer) return;
    final isTap = !_galleryPointerMoved && !_galleryPointerMultitouch;
    if (_galleryDoubleTapCandidate) {
      if (isTap) {
        _cancelPendingGalleryTap();
      } else {
        _dispatchPendingGalleryTap();
      }
    } else if (isTap) {
      _pendingGalleryTapPosition = event.position;
      _pendingGalleryTapTime = event.timeStamp;
      _galleryTapTimer = Timer(kDoubleTapTimeout, _dispatchPendingGalleryTap);
    }
    _resetGalleryPointerTracking();
  }

  void _handleGalleryPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _trackedGalleryPointer) return;
    if (_galleryDoubleTapCandidate) _dispatchPendingGalleryTap();
    _resetGalleryPointerTracking();
  }

  void _resetGalleryPointerTracking() {
    _trackedGalleryPointer = null;
    _galleryPointerDownPosition = null;
    _galleryPointerMoved = false;
    _galleryPointerMultitouch = false;
    _galleryDoubleTapCandidate = false;
  }

  void _dispatchPendingGalleryTap() {
    final position = _pendingGalleryTapPosition;
    _cancelPendingGalleryTap();
    if (position != null && mounted) _handleGalleryTapAt(position);
  }

  void _cancelPendingGalleryTap() {
    _galleryTapTimer?.cancel();
    _galleryTapTimer = null;
    _pendingGalleryTapPosition = null;
    _pendingGalleryTapTime = null;
  }

  void _handleVideoFullscreenChanged(bool isFullscreen) {
    if (!mounted) return;
    setState(() {
      _videoFullscreen = isFullscreen;
      _showChrome = !isFullscreen;
    });
  }

  void _handleVideoControlsChanged(bool visible) {
    if (!mounted || _videoFullscreen || _showChrome == visible) return;
    setState(() => _showChrome = visible);
  }

  void _handleVideoBottomControlsHeightChanged(double height) {
    if (!mounted || (_videoBottomControlsHeight - height).abs() < 0.5) return;
    setState(() => _videoBottomControlsHeight = height);
  }

  void _handleVideoUrlChanged(String url) {
    if (!mounted || _currentVideoUrl == url) return;
    setState(() => _currentVideoUrl = url);
  }

  void _selectThumbnail(int index) {
    _cancelPendingGalleryTap();
    if (index != _currentIndex && _pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  void _syncMainPageToThumbnail() {
    if (!_thumbnailUserScrolling ||
        !_thumbnailController.hasClients ||
        !_pageController.hasClients) {
      return;
    }

    final page = (_thumbnailController.page ?? _currentIndex.toDouble()).clamp(
      0.0,
      (widget.images.length - 1).toDouble(),
    );
    final mainPosition = _pageController.position;
    if (mainPosition.viewportDimension <= 0) return;
    final targetPixels =
        (mainPosition.minScrollExtent + page * mainPosition.viewportDimension)
            .clamp(mainPosition.minScrollExtent, mainPosition.maxScrollExtent)
            .toDouble();
    if ((mainPosition.pixels - targetPixels).abs() > 0.5) {
      mainPosition.jumpTo(targetPixels);
    }
  }

  void _settleThumbnailScroll() {
    if (_thumbnailSettling ||
        !_thumbnailController.hasClients ||
        !_pageController.hasClients) {
      return;
    }

    final target = (_thumbnailController.page ?? _currentIndex.toDouble())
        .round()
        .clamp(0, widget.images.length - 1);
    final epoch = ++_thumbnailSyncEpoch;
    _thumbnailUserScrolling = false;
    _thumbnailSettling = true;
    const duration = Duration(milliseconds: 120);
    unawaited(
      Future.wait<void>([
        _thumbnailController.animateToPage(
          target,
          duration: duration,
          curve: Curves.easeOutCubic,
        ),
        _pageController.animateToPage(
          target,
          duration: duration,
          curve: Curves.easeOutCubic,
        ),
      ]).whenComplete(() {
        if (!mounted || epoch != _thumbnailSyncEpoch) return;
        setState(() {
          _thumbnailSettling = false;
          _thumbnailScrollBottom = null;
        });
        _activeMediaIndex.value = _currentIndex;
      }),
    );
  }

  bool _handleThumbnailScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _thumbnailSyncEpoch++;
      _thumbnailSettling = false;
      _thumbnailUserScrolling = true;
      _mainUserScrolling = false;
      _activeMediaIndex.value = -1;
      setState(() => _thumbnailScrollBottom ??= _thumbnailBottom);
    } else if (notification is ScrollEndNotification &&
        _thumbnailUserScrolling) {
      final epoch = _thumbnailSyncEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            epoch == _thumbnailSyncEpoch &&
            _thumbnailUserScrolling) {
          _settleThumbnailScroll();
        }
      });
    }
    return false;
  }

  bool _handleMainGalleryScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _thumbnailSyncEpoch++;
      _thumbnailUserScrolling = false;
      _thumbnailSettling = false;
      _mainUserScrolling = true;
      _activeMediaIndex.value = -1;
      if (_thumbnailController.hasClients &&
          _thumbnailController.position.isScrollingNotifier.value) {
        final position = _thumbnailController.position;
        position.jumpTo(position.pixels);
      }
      if (_thumbnailScrollBottom != null) {
        setState(() => _thumbnailScrollBottom = null);
      }
    } else if (notification is ScrollEndNotification && _mainUserScrolling) {
      final epoch = _thumbnailSyncEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            epoch != _thumbnailSyncEpoch ||
            !_mainUserScrolling ||
            _pageController.position.isScrollingNotifier.value) {
          return;
        }
        _mainUserScrolling = false;
        _activeMediaIndex.value = _currentIndex;
      });
    }
    return false;
  }

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 64,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleThumbnailScroll,
        child: PageView.builder(
          controller: _thumbnailController,
          physics: const ClampingScrollPhysics(),
          pageSnapping: false,
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            final selected = index == _currentIndex;
            final item = _mediaAt(index);
            return Semantics(
              label: item.isVideo
                  ? '第 ${index + 1} 项，视频'
                  : '第 ${index + 1} 张图片',
              selected: selected,
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtil.selection();
                  _thumbnailSyncEpoch++;
                  _thumbnailUserScrolling = false;
                  _thumbnailSettling = false;
                  _thumbnailController.jumpToPage(index);
                  _selectThumbnail(index);
                  if (index == _currentIndex) _activeMediaIndex.value = index;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ExtendedImage.network(
                            AppNetworkImage.safeUrl(item.imageUrl),
                            fit: BoxFit.cover,
                            cache: true,
                            cacheWidth: 160,
                            headers: {
                              'User-Agent': TiebaConstants.defaultUserAgent,
                            },
                          ),
                          if (item.isVideo)
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          if (!selected)
                            const ColoredBox(color: Colors.white30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass = ref.watch(
      themeProvider.select((state) => state.useLiquidGlass),
    );
    final galleryPage = ExtendedImageSlidePage(
      slideAxis: SlideAxis.horizontal,
      slideType: SlideType.onlyImage,
      slidePageBackgroundHandler: (offset, pageSize) => Colors.black.withValues(
        alpha: math.max(0.0, 1.0 - offset.dx.abs() / (pageSize.width / 2)),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleMainGalleryScroll,
              child: ExtendedImageGesturePageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                canScrollPage: (details) => (details?.totalScale ?? 1.0) <= 1.0,
                shouldAccpetHorizontalOrVerticalDrag: (trackers) =>
                    trackers.length == 1,
                pageSnapping: !_thumbnailUserScrolling && !_thumbnailSettling,
                itemCount: widget.images.length,
                onPageChanged: (i) {
                  if (i != _currentIndex) {
                    _cancelPendingGalleryTap();
                    if (_thumbnailUserScrolling) {
                      HapticFeedbackUtil.selectionTick();
                    }
                  }
                  setState(() {
                    if (i != _currentIndex && _videoFullscreen) {
                      _videoFullscreen = false;
                      _showChrome = true;
                    }
                    if (_mediaAt(i).isVideo) _videoBottomControlsHeight = 0;
                    _currentVideoUrl = _mediaAt(i).videoUrl;
                    _currentIndex = i;
                  });
                  if (!_thumbnailUserScrolling &&
                      !_thumbnailSettling &&
                      !_mainUserScrolling) {
                    _activeMediaIndex.value = i;
                  }
                  if (!_thumbnailUserScrolling &&
                      !_thumbnailSettling &&
                      _thumbnailController.hasClients) {
                    _thumbnailController.jumpToPage(i);
                  }
                },
                itemBuilder: (context, index) {
                  final item = _mediaAt(index);
                  if (item.isVideo) {
                    return ValueListenableBuilder<int>(
                      valueListenable: _activeMediaIndex,
                      builder: (context, activeIndex, _) => activeIndex == index
                          ? TiebaVideoPlayerPage(
                              key: ValueKey('gallery-video-$index'),
                              videoUrl: item.videoUrl,
                              coverUrl: item.imageUrl,
                              threadId: widget.threadId,
                              authorName: widget.folderName,
                              embedded: true,
                              onFullscreenChanged: (isFullscreen) {
                                if (index == _currentIndex) {
                                  _handleVideoFullscreenChanged(isFullscreen);
                                }
                              },
                              onControlsVisibilityChanged: (visible) {
                                if (index == _currentIndex) {
                                  _handleVideoControlsChanged(visible);
                                }
                              },
                              onBottomControlsHeightChanged: (height) {
                                if (index == _currentIndex) {
                                  _handleVideoBottomControlsHeightChanged(
                                    height,
                                  );
                                }
                              },
                              onVideoUrlChanged: (url) {
                                if (index == _currentIndex) {
                                  _handleVideoUrlChanged(url);
                                }
                              },
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                ExtendedImage.network(
                                  AppNetworkImage.safeUrl(item.imageUrl),
                                  fit: BoxFit.contain,
                                  cache: true,
                                  headers: {
                                    'User-Agent':
                                        TiebaConstants.defaultUserAgent,
                                  },
                                ),
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ],
                            ),
                    );
                  }
                  final url = AppNetworkImage.safeUrl(item.imageUrl);
                  final image = ExtendedImage.network(
                    url,
                    fit: BoxFit.contain,
                    mode: ExtendedImageMode.gesture,
                    cache: true,
                    headers: {'User-Agent': TiebaConstants.defaultUserAgent},
                    onDoubleTap: (state) {
                      _animateDoubleTap(state);
                    },
                    enableSlideOutPage: false,
                    initGestureConfigHandler: (state) {
                      return GestureConfig(
                        minScale: 1.0,
                        animationMinScale: 1.0,
                        maxScale: 8.0,
                        animationMaxScale: 9.0,
                        speed: 1.0,
                        inertialSpeed: 120.0,
                        initialScale: 1.0,
                        inPageView: true,
                        initialAlignment: InitialAlignment.center,
                      );
                    },
                    loadStateChanged: (state) {
                      switch (state.extendedImageLoadState) {
                        case LoadState.loading:
                          return const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white70,
                                ),
                              ),
                            ),
                          );
                        case LoadState.failed:
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.broken_image_rounded,
                                  size: 40,
                                  color: Colors.white54,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '图片加载失败',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => state.reLoadImage(),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    '点击重试',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.white38,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        case LoadState.completed:
                          return _pagingImages[state
                              .extendedImageInfo!] ??= ExtendedImageGesture(
                            state,
                            imageBuilder: (image, {imageGestureState}) {
                              final gestureState = imageGestureState!;
                              final pager = gestureState.context
                                  .findAncestorStateOfType<
                                    ExtendedImageGesturePageViewState
                                  >();
                              if (pager == null) return image;
                              return Listener(
                                onPointerDown: (_) {
                                  pager.extendedImageGestureStates.remove(
                                    gestureState,
                                  );
                                  pager.extendedImageGestureState =
                                      gestureState;
                                },
                                child: RawGestureDetector(
                                  gestures: {
                                    ExtendedHorizontalDragGestureRecognizer:
                                        GestureRecognizerFactoryWithHandlers<
                                          ExtendedHorizontalDragGestureRecognizer
                                        >(
                                          () => ExtendedHorizontalDragGestureRecognizer(
                                            canHorizontalOrVerticalDrag: () =>
                                                (gestureState
                                                        .gestureDetails
                                                        ?.totalScale ??
                                                    1) <=
                                                1,
                                            shouldAccpetHorizontalOrVerticalDrag:
                                                (trackers) =>
                                                    trackers.length == 1,
                                          ),
                                          (recognizer) => recognizer
                                            ..onDown = pager.onDragDown
                                            ..onStart = pager.onDragStart
                                            ..onUpdate = pager.onDragUpdate
                                            ..onEnd = pager.onDragEnd
                                            ..onCancel = pager.onDragCancel
                                            ..minFlingDistance = pager
                                                .widget
                                                .physics
                                                .minFlingDistance
                                            ..minFlingVelocity = pager
                                                .widget
                                                .physics
                                                .minFlingVelocity
                                            ..maxFlingVelocity = pager
                                                .widget
                                                .physics
                                                .maxFlingVelocity
                                            ..gestureSettings =
                                                MediaQuery.gestureSettingsOf(
                                                  context,
                                                ),
                                        ),
                                  },
                                  child: image,
                                ),
                              );
                            },
                          );
                      }
                    },
                  );
                  return Semantics(
                    onTap: () => setState(() => _showChrome = !_showChrome),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _handleGalleryPointerDown,
                      onPointerMove: _handleGalleryPointerMove,
                      onPointerUp: _handleGalleryPointerUp,
                      onPointerCancel: _handleGalleryPointerCancel,
                      child: _withGalleryHero(index, image),
                    ),
                  );
                },
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 12,
                right: 12,
                bottom: _thumbnailBottom,
                child: IgnorePointer(
                  ignoring: !_showChrome || !_routeTransitionComplete,
                  child: AnimatedOpacity(
                    opacity: _showChrome && _routeTransitionComplete ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: _buildThumbnailStrip(),
                  ),
                ),
              ),
            if (_showChrome && _routeTransitionComplete)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 24,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _GalleryGlassIconButton(
                            tooltip: '关闭',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () => Navigator.pop(context),
                            useLiquidGlass: useLiquidGlass,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: widget.images.length > 1
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${_currentIndex + 1} / ${widget.images.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_mediaAt(_currentIndex).isVideo &&
                                widget.threadId?.isNotEmpty == true)
                              _GalleryGlassIconButton(
                                tooltip: '分享视频',
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final id = widget.threadId!;
                                  ShareService.shareTextContent(
                                    context,
                                    text: '贴吧视频\nhttps://tieba.baidu.com/p/$id',
                                    title: '贴吧视频',
                                    fallbackMessage: '视频链接已复制到剪贴板',
                                  );
                                },
                                useLiquidGlass: useLiquidGlass,
                              )
                            else
                              const SizedBox(width: 48),
                            if (!_mediaAt(_currentIndex).isVideo ||
                                _currentVideoUrl.isNotEmpty)
                              _GalleryGlassIconButton(
                                tooltip: _mediaAt(_currentIndex).isVideo
                                    ? '保存视频'
                                    : '保存图片',
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () {
                                  final item = _mediaAt(_currentIndex);
                                  if (item.isVideo) {
                                    MediaSaveService.saveVideo(
                                      context,
                                      _currentVideoUrl,
                                      folderName: widget.folderName,
                                    );
                                  } else {
                                    MediaSaveService.saveImage(
                                      context,
                                      item.imageUrl,
                                      folderName: widget.folderName,
                                    );
                                  }
                                },
                                useLiquidGlass: useLiquidGlass,
                              )
                            else
                              const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return galleryPage;
  }
}

class _GalleryGlassIconButton extends StatefulWidget {
  const _GalleryGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.useLiquidGlass,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool useLiquidGlass;

  @override
  State<_GalleryGlassIconButton> createState() =>
      _GalleryGlassIconButtonState();
}

class _GalleryGlassIconButtonState extends State<_GalleryGlassIconButton> {
  static Future<ui.FragmentProgram>? _programFuture;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (!widget.useLiquidGlass && ui.ImageFilter.isShaderFilterSupported) {
      _loadShader();
    }
  }

  @override
  void didUpdateWidget(covariant _GalleryGlassIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useLiquidGlass == widget.useLiquidGlass) return;
    if (widget.useLiquidGlass) {
      _shader?.dispose();
      _shader = null;
    } else if (ui.ImageFilter.isShaderFilterSupported) {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    try {
      final program = await (_programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/gallery_glass_button.frag',
      ));
      final shader = program.fragmentShader();
      if (!mounted || widget.useLiquidGlass) {
        shader.dispose();
        return;
      }
      setState(() => _shader = shader);
    } catch (_) {
      // Blur and the highlight remain usable when shader loading is unavailable.
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useLiquidGlass) {
      return GestureDetector(
        excludeFromSemantics: true,
        onLongPress: () {},
        child: GlassButton(
          label: widget.tooltip,
          width: 48,
          height: 48,
          icon: widget.icon,
          iconSize: 22,
          iconColor: Colors.white,
          onTap: widget.onPressed,
          enabled: true,
          useOwnLayer: true,
          stretch: 0.8,
          anchorStretchSettings: const AnchorStretchSettings(
            intensity: 0.8,
            squashFactor: 0.3,
            translationDamping: 0.15,
            bounciness: 0.2,
          ),
          glowColor: const Color(0x20FFFFFF),
          glowOpacity: 1,
          quality: GlassQuality.premium,
          settings: const LiquidGlassSettings(
            glassColor: Color(0x66000000),
            bodyMode: GlassBodyMode.clear,
            thickness: 32,
            blur: 2,
            lightIntensity: 0.25,
            ambientStrength: 0,
            refractiveIndex: 1.24,
            chromaticAberration: 0.025,
            shadowElevation: 0,
          ),
        ),
      );
    }
    final blur = ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5);
    final shader = _shader;
    final filter = shader == null
        ? blur
        : ui.ImageFilter.compose(
            outer: ui.ImageFilter.shader(shader),
            inner: blur,
          );

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: filter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade200.withValues(alpha: 0.30),
                          Colors.grey.shade500.withValues(alpha: 0.20),
                          Colors.grey.shade800.withValues(alpha: 0.36),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: widget.tooltip,
            onPressed: widget.onPressed,
            icon: widget.icon,
          ),
        ],
      ),
    );
  }
}

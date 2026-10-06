import 'dart:async';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/media_save_service.dart';
import '../../../../core/utils/haptic_feedback_util.dart';
import '../../../../core/constants/tieba_constants.dart';
import '../../../../core/widgets/app_network_image.dart';

class ImageGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? folderName;

  const ImageGalleryPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.folderName,
  });

  static void open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? folderName,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => ImageGalleryPage(
          images: images,
          initialIndex: initialIndex,
          folderName: folderName,
        ),
      ),
    );
  }

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  late int _currentIndex;
  late ExtendedPageController _pageController;
  late PageController _thumbnailController;
  bool _thumbnailUserScrolling = false;
  bool _thumbnailSettling = false;
  int _thumbnailSyncEpoch = 0;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
    _thumbnailController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.16,
    )..addListener(_syncMainPageToThumbnail);
  }

  @override
  void dispose() {
    _thumbnailSyncEpoch++;
    _thumbnailController
      ..removeListener(_syncMainPageToThumbnail)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleGalleryTap(TapUpDetails details) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final x = details.globalPosition.dx;
    if (x >= screenWidth / 3 && x < screenWidth * 2 / 3) {
      setState(() => _showChrome = !_showChrome);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _selectThumbnail(int index) {
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
        _thumbnailSettling = false;
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
    } else if (notification is ScrollEndNotification &&
        _thumbnailUserScrolling) {
      _settleThumbnailScroll();
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
            return Semantics(
              label: '第 ${index + 1} 张图片',
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
                            AppNetworkImage.safeUrl(widget.images[index]),
                            fit: BoxFit.cover,
                            cache: true,
                            cacheWidth: 160,
                            headers: {
                              'User-Agent': TiebaConstants.defaultUserAgent,
                            },
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleGalleryTap,
        child: Stack(
          children: [
            NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification.dragDetails != null) {
                  _thumbnailSyncEpoch++;
                  _thumbnailUserScrolling = false;
                  _thumbnailSettling = false;
                }
                return false;
              },
              child: ExtendedImageGesturePageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.images.length,
                onPageChanged: (i) {
                  if (i != _currentIndex) {
                    if (_thumbnailUserScrolling) {
                      HapticFeedbackUtil.selectionTick();
                    } else if (!_thumbnailSettling) {
                      HapticFeedbackUtil.selection();
                    }
                  }
                  setState(() => _currentIndex = i);
                  if (!_thumbnailUserScrolling &&
                      !_thumbnailSettling &&
                      _thumbnailController.hasClients) {
                    _thumbnailController.jumpToPage(i);
                  }
                },
                itemBuilder: (context, index) {
                  final url = AppNetworkImage.safeUrl(widget.images[index]);
                  return ExtendedImage.network(
                    url,
                    fit: BoxFit.contain,
                    mode: ExtendedImageMode.gesture,
                    cache: true,
                    headers: {'User-Agent': TiebaConstants.defaultUserAgent},
                    onDoubleTap: (state) {
                      final currentScale =
                          state.gestureDetails?.totalScale ?? 1.0;
                      final targetScale = currentScale > 1.01 ? 1.0 : 2.0;
                      state.handleDoubleTap(
                        scale: targetScale,
                        doubleTapPosition: state.pointerDownPosition,
                      );
                    },
                    initGestureConfigHandler: (state) {
                      return GestureConfig(
                        minScale: 1.0,
                        animationMinScale: 1.0,
                        maxScale: 3.5,
                        animationMaxScale: 4.0,
                        speed: 1.0,
                        inertialSpeed: 100.0,
                        initialScale: 1.0,
                        inPageView: true,
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
                          return null;
                      }
                    },
                  );
                },
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 32,
                child: Visibility(
                  visible: _showChrome,
                  maintainState: true,
                  child: _buildThumbnailStrip(),
                ),
              ),
            if (_showChrome)
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black87,
                        Colors.black38,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GalleryGlassIconButton(
                        tooltip: '关闭',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      if (widget.images.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
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
                        ),
                      _GalleryGlassIconButton(
                        tooltip: '保存图片',
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () {
                          if (widget.images.isNotEmpty) {
                            final currentUrl = widget.images[_currentIndex];
                            MediaSaveService.saveImage(
                              context,
                              currentUrl,
                              folderName: widget.folderName,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryGlassIconButton extends StatefulWidget {
  const _GalleryGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

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
    if (ui.ImageFilter.isShaderFilterSupported) _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await (_programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/gallery_glass_button.frag',
      ));
      if (mounted) setState(() => _shader = program.fragmentShader());
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

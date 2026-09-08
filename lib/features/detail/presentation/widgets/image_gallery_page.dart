import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/media_save_service.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ExtendedImageGesturePageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final url = AppNetworkImage.safeUrl(widget.images[index]);
              return ExtendedImage.network(
                url,
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                cache: true,
                headers: {'User-Agent': TiebaConstants.defaultUserAgent},
                onDoubleTap: (state) {
                  final currentScale = state.gestureDetails?.totalScale ?? 1.0;
                  final targetScale = currentScale > 1.01 ? 1.0 : 2.0;
                  state.handleDoubleTap(
                    scale: targetScale,
                    doubleTapPosition: state.pointerDownPosition,
                  );
                },
                initGestureConfigHandler: (state) {
                  return GestureConfig(
                    minScale: 0.9,
                    animationMinScale: 0.7,
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
                                side: const BorderSide(color: Colors.white38),
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
                  colors: [Colors.black87, Colors.black38, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // 左上角关闭按钮 (带深色高反差圆底与柔和阴影)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
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
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  // 页码指示胶囊
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
                  const SizedBox(width: 10),
                  // 右上角保存图片按钮 (带深色高反差圆底与柔和阴影)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
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
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: '保存图片',
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

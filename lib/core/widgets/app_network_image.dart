import "package:extended_image/extended_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../features/settings/presentation/providers/habit_settings_provider.dart";
import "../constants/tieba_constants.dart";

class AppNetworkImage extends ConsumerStatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final BorderRadius? borderRadius;
  final bool enableGesture;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.constraints,
    this.borderRadius,
    this.enableGesture = false,
  });

  static String safeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http://")) {
      u = "https://${u.substring(7)}";
    }
    return u;
  }

  @override
  ConsumerState<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends ConsumerState<AppNetworkImage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final processedUrl = AppNetworkImage.safeUrl(widget.url);

    if (processedUrl.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        constraints: widget.constraints,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Icon(Icons.broken_image_outlined, size: 24, color: colorScheme.outline),
      );
    }

    // 非手势看大图模式下，受图片加载模式影响
    if (!widget.enableGesture) {
      final habit = ref.watch(habitSettingsProvider);
      // 1 (智能无图) 与 3 (始终无图)：正常刷帖完全不占用任何空白与占位，纯粹显示文字
      if (habit.imageLoadMode == 1 || habit.imageLoadMode == 3) {
        return const SizedBox.shrink();
      }
    }

    Widget imageWidget = ExtendedImage.network(
      processedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cache: true,
      headers: {"User-Agent": TiebaConstants.defaultUserAgent},
      mode: widget.enableGesture ? ExtendedImageMode.gesture : ExtendedImageMode.none,
      initGestureConfigHandler: widget.enableGesture
          ? (state) => GestureConfig(
                minScale: 0.9,
                animationMinScale: 0.7,
                maxScale: 3.5,
                animationMaxScale: 4.0,
                speed: 1.0,
                inertialSpeed: 100.0,
                initialScale: 1.0,
                inPageView: true,
              )
          : null,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return Container(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            );
          case LoadState.failed:
            return GestureDetector(
              onTap: () => state.reLoadImage(),
              child: Container(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 22, color: colorScheme.outline),
                      const SizedBox(height: 4),
                      Text(
                        "重新加载",
                        style: TextStyle(color: colorScheme.outline, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            );
          case LoadState.completed:
            return null;
        }
      },
    );

    if (widget.constraints != null) {
      imageWidget = ConstrainedBox(constraints: widget.constraints!, child: imageWidget);
    }

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(borderRadius: widget.borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }
}

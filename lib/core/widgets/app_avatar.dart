import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import '../constants/tieba_constants.dart';

class AppAvatar extends StatelessWidget {
  final String? portrait;
  final String? url;
  final double size;
  final double radius;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.portrait,
    this.url,
    this.size = 40,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = url ?? TiebaConstants.getPortraitUrl(portrait);

    Widget avatar = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: colorScheme.surfaceContainerHighest,
        child: ExtendedImage.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cache: true,
          loadStateChanged: (state) {
            switch (state.extendedImageLoadState) {
              case LoadState.loading:
                return Icon(Icons.person_rounded, size: size * 0.6, color: colorScheme.outlineVariant);
              case LoadState.completed:
                return null;
              case LoadState.failed:
                return Icon(Icons.person_rounded, size: size * 0.6, color: colorScheme.outlineVariant);
            }
          },
        ),
      ),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }
}

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../constants/tieba_constants.dart';

class AppAvatar extends StatelessWidget {
  final String? portrait;
  final String? url;
  final double size;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const AppAvatar({
    super.key,
    this.portrait,
    this.url,
    this.size = 40,
    this.radius = 20,
    this.onTap,
    this.semanticLabel,
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
                return Icon(
                  Icons.person_rounded,
                  size: size * 0.6,
                  color: colorScheme.outlineVariant,
                );
              case LoadState.completed:
                return null;
              case LoadState.failed:
                return Icon(
                  Icons.person_rounded,
                  size: size * 0.6,
                  color: colorScheme.outlineVariant,
                );
            }
          },
        ),
      ),
    );

    if (onTap != null) {
      avatar = Semantics(
        button: true,
        label: semanticLabel ?? '查看头像',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: avatar,
          ),
        ),
      );
    } else {
      avatar = Semantics(
        image: true,
        label: semanticLabel ?? '头像',
        child: avatar,
      );
    }

    return avatar;
  }
}

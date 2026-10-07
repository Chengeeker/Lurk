import 'package:flutter/material.dart';

/// Shared surface for grouped settings and profile sections.
///
/// Keeping the shape, border, and elevation in one place prevents individual
/// screens from drifting away from the application's Material 3 surface style.
class AppSectionCard extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry borderRadius;

  const AppSectionCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide.none,
      ),
      child: child,
    );
  }
}

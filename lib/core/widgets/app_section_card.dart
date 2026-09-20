import 'package:flutter/material.dart';

/// Shared surface for grouped settings and profile sections.
///
/// Keeping the shape, border, and elevation in one place prevents individual
/// screens from drifting away from the application's Material 3 surface style.
class AppSectionCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? margin;

  const AppSectionCard({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color:
          color ?? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}

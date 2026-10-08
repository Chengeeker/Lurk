import 'package:flutter/material.dart';

class SpringPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SpringPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;

          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final startX = Directionality.of(context) == TextDirection.ltr
              ? 1.0
              : -1.0;

          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(startX, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
      );
}

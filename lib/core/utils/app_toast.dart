import 'dart:async';

import 'package:flutter/material.dart';

class AppToast {
  AppToast._();

  static OverlayEntry? _bottomEntry;
  static Timer? _bottomTimer;

  // A root overlay stays at the screen bottom when the source route changes.
  static void showBottom(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _bottomTimer?.cancel();
    _bottomEntry?.remove();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
        child: IgnorePointer(
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _bottomEntry = entry;
    overlay.insert(entry);
    _bottomTimer = Timer(const Duration(seconds: 2), () {
      entry.remove();
      if (identical(_bottomEntry, entry)) _bottomEntry = null;
    });
  }

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    BuildContext? context,
    String message, {
    bool isError = false,
  }) {
    final messenger = context != null
        ? ScaffoldMessenger.maybeOf(context) ??
              scaffoldMessengerKey.currentState
        : scaffoldMessengerKey.currentState;

    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF323232),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showToast(String message, {bool isError = false}) {
    show(null, message, isError: isError);
  }
}

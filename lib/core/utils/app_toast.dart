import 'package:flutter/material.dart';

class AppToast {
  AppToast._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(BuildContext? context, String message, {bool isError = false}) {
    final messenger = context != null
        ? ScaffoldMessenger.maybeOf(context) ?? scaffoldMessengerKey.currentState
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

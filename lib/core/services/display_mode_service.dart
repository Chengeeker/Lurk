import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import '../storage/storage_service.dart';

class DisplayModeService {
  static const String keyDisplayModeId = 'key_selected_display_mode_id';

  static Future<void> init(StorageService storage) async {
    if (!kIsWeb && Platform.isAndroid) {
      final savedId = storage.getInt(keyDisplayModeId);
      await applyModeById(savedId);
    }
  }

  static Future<List<DisplayMode>> getSupportedModes() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await FlutterDisplayMode.supported;
      } catch (e) {
        debugPrint('Failed to get supported display modes: $e');
      }
    }
    return [];
  }

  static Future<DisplayMode?> getActiveMode() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await FlutterDisplayMode.active;
      } catch (e) {
        debugPrint('Failed to get active display mode: $e');
      }
    }
    return null;
  }

  static Future<void> applyModeById(int modeId) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      if (modeId == 0) {
        await FlutterDisplayMode.setHighRefreshRate();
      } else {
        final modes = await FlutterDisplayMode.supported;
        final matched = modes.firstWhere((m) => m.id == modeId, orElse: () => DisplayMode.auto);
        await FlutterDisplayMode.setPreferredMode(matched);
      }
    } catch (e) {
      debugPrint('Failed to apply display mode $modeId: $e');
    }
  }

  static Future<void> applyModeIndex(int index) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      if (index == 0) {
        await FlutterDisplayMode.setPreferredMode(DisplayMode.auto);
      } else if (index == 1) {
        await FlutterDisplayMode.setHighRefreshRate();
      } else {
        final modes = await FlutterDisplayMode.supported;
        final targetHz = index == 2 ? 60 : (index == 3 ? 90 : 120);

        DisplayMode? matchedMode;
        for (var m in modes) {
          if ((m.refreshRate - targetHz).abs() < 2) {
            matchedMode = m;
            break;
          }
        }

        if (matchedMode != null) {
          await FlutterDisplayMode.setPreferredMode(matchedMode);
        } else if (targetHz >= 90) {
          await FlutterDisplayMode.setHighRefreshRate();
        } else {
          await FlutterDisplayMode.setLowRefreshRate();
        }
      }
    } catch (e) {
      debugPrint('Failed to apply display mode index $index: $e');
    }
  }
}

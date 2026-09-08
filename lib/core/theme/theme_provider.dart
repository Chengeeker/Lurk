import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/display_mode_service.dart';
import '../storage/storage_service.dart';
import '../utils/haptic_feedback_util.dart';

class ThemeState {
  final ThemeMode themeMode;
  final bool useDynamicColor;
  final int themeColorIndex;
  final bool isPureBlackDark;
  final bool enableHaptics;
  final bool useFloatingNavBar;
  final int fontWeightIndex;
  final int refreshRateIndex;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = false,
    this.themeColorIndex = 0,
    this.isPureBlackDark = false,
    this.enableHaptics = true,
    this.useFloatingNavBar = true,
    this.fontWeightIndex = 1,
    this.refreshRateIndex = 0,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    int? themeColorIndex,
    bool? isPureBlackDark,
    bool? enableHaptics,
    bool? useFloatingNavBar,
    int? fontWeightIndex,
    int? refreshRateIndex,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      themeColorIndex: themeColorIndex ?? this.themeColorIndex,
      isPureBlackDark: isPureBlackDark ?? this.isPureBlackDark,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      useFloatingNavBar: useFloatingNavBar ?? this.useFloatingNavBar,
      fontWeightIndex: fontWeightIndex ?? this.fontWeightIndex,
      refreshRateIndex: refreshRateIndex ?? this.refreshRateIndex,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final StorageService _storage;

  ThemeNotifier(this._storage) : super(const ThemeState()) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final modeIndex = _storage.getInt(StorageService.keyThemeMode, defaultValue: 0);
    final useDynamic = _storage.getBool(StorageService.keyUseDynamicColor, defaultValue: false);
    final colorIdx = _storage.getInt(StorageService.keyThemeColorIndex, defaultValue: 0);
    final pureBlack = _storage.getBool(StorageService.keyIsPureBlackDark, defaultValue: false);
    final haptics = _storage.getEnableHaptics();
    final floatingNav = _storage.getUseFloatingNavBar();
    final fontWt = _storage.getFontWeightIndex();
    final refreshRate = _storage.getRefreshRateIndex();

    ThemeMode mode = ThemeMode.system;
    if (modeIndex == 1) mode = ThemeMode.light;
    if (modeIndex == 2) mode = ThemeMode.dark;

    HapticFeedbackUtil.isEnabled = haptics;

    state = ThemeState(
      themeMode: mode,
      useDynamicColor: useDynamic,
      themeColorIndex: colorIdx,
      isPureBlackDark: pureBlack,
      enableHaptics: haptics,
      useFloatingNavBar: floatingNav,
      fontWeightIndex: fontWt,
      refreshRateIndex: refreshRate,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    int index = 0;
    if (mode == ThemeMode.light) index = 1;
    if (mode == ThemeMode.dark) index = 2;
    await _storage.setInt(StorageService.keyThemeMode, index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setUseDynamicColor(bool useDynamic) async {
    await _storage.setBool(StorageService.keyUseDynamicColor, useDynamic);
    state = state.copyWith(useDynamicColor: useDynamic);
  }

  Future<void> setThemeColorIndex(int index) async {
    await _storage.setInt(StorageService.keyThemeColorIndex, index);
    state = state.copyWith(themeColorIndex: index);
  }

  Future<void> setPureBlackDark(bool enabled) async {
    await _storage.setBool(StorageService.keyIsPureBlackDark, enabled);
    state = state.copyWith(isPureBlackDark: enabled);
  }

  Future<void> setEnableHaptics(bool enabled) async {
    await _storage.setEnableHaptics(enabled);
    HapticFeedbackUtil.isEnabled = enabled;
    state = state.copyWith(enableHaptics: enabled);
  }

  Future<void> setUseFloatingNavBar(bool enabled) async {
    await _storage.setUseFloatingNavBar(enabled);
    state = state.copyWith(useFloatingNavBar: enabled);
  }

  Future<void> setFontWeightIndex(int index) async {
    await _storage.setFontWeightIndex(index);
    state = state.copyWith(fontWeightIndex: index);
  }

  Future<void> setRefreshRateIndex(int index) async {
    await _storage.setRefreshRateIndex(index);
    state = state.copyWith(refreshRateIndex: index);
    await DisplayModeService.applyModeIndex(index);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeNotifier(storage);
});

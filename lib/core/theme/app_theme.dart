import 'package:flutter/material.dart';
import '../utils/haptic_feedback_util.dart';

class AppTheme {
  AppTheme._();

  static const List<Map<String, dynamic>> themeColors = [
    {'name': '贴吧蓝', 'color': Color(0xFF2F54EB)},
    {'name': '活力橙', 'color': Color(0xFFFF7A00)},
    {'name': '薄荷绿', 'color': Color(0xFF00A870)},
    {'name': '优雅紫', 'color': Color(0xFF722ED1)},
    {'name': '樱花粉', 'color': Color(0xFFEB2F96)},
    {'name': '极光青', 'color': Color(0xFF13C2C2)},
    {'name': '玄青黑', 'color': Color(0xFF374151)},
  ];

  static Color getSeedColor(int index) {
    if (index >= 0 && index < themeColors.length) {
      return themeColors[index]['color'] as Color;
    }
    return const Color(0xFF2F54EB);
  }

  static FontWeight getBaseFontWeight(int index) {
    switch (index) {
      case 0:
        return FontWeight.w300; // 偏细
      case 1:
        return FontWeight.w400; // 默认
      case 2:
        return FontWeight.w500; // 中等
      case 3:
        return FontWeight.w600; // 偏粗
      case 4:
        return FontWeight.w700; // 加粗
      default:
        return FontWeight.w400;
    }
  }

  static FontWeight getBoldFontWeight(int index) {
    switch (index) {
      case 0:
        return FontWeight.w500;
      case 1:
        return FontWeight.w600;
      case 2:
        return FontWeight.w700;
      case 3:
        return FontWeight.w800;
      case 4:
        return FontWeight.w900;
      default:
        return FontWeight.w600;
    }
  }

  static TextTheme _applyFontWeight(TextTheme base, int index) {
    if (index == 1) return base;
    final baseWeight = getBaseFontWeight(index);
    final boldWeight = getBoldFontWeight(index);
    return base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(fontWeight: baseWeight),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: baseWeight),
      bodySmall: base.bodySmall?.copyWith(fontWeight: baseWeight),
      titleLarge: base.titleLarge?.copyWith(fontWeight: boldWeight),
      titleMedium: base.titleMedium?.copyWith(fontWeight: boldWeight),
      titleSmall: base.titleSmall?.copyWith(fontWeight: boldWeight),
      labelLarge: base.labelLarge?.copyWith(fontWeight: baseWeight),
      labelMedium: base.labelMedium?.copyWith(fontWeight: baseWeight),
      labelSmall: base.labelSmall?.copyWith(fontWeight: baseWeight),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: boldWeight),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: boldWeight),
    );
  }

  static ThemeData lightTheme({
    ColorScheme? dynamicColorScheme,
    int colorIndex = 0,
    int fontWeightIndex = 1,
  }) {
    final seed = getSeedColor(colorIndex);
    final scheme = dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        );

    final baseTheme = ThemeData(
      useMaterial3: true,
      splashFactory: const HapticSplashFactory(),
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: getBoldFontWeight(fontWeightIndex),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        color: scheme.surfaceContainerLowest,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.3),
        thickness: 0.5,
      ),
    );

    return baseTheme.copyWith(
      textTheme: _applyFontWeight(baseTheme.textTheme, fontWeightIndex),
    );
  }

  static ThemeData darkTheme({
    ColorScheme? dynamicColorScheme,
    int colorIndex = 0,
    bool isPureBlack = false,
    int fontWeightIndex = 1,
  }) {
    final seed = getSeedColor(colorIndex);
    final scheme = dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        );

    final bgColor = isPureBlack ? Colors.black : const Color(0xFF111215);
    final cardColor = isPureBlack ? const Color(0xFF121212) : const Color(0xFF1B1C20);
    final appBarColor = isPureBlack ? Colors.black : const Color(0xFF111215);
    final navBgColor = isPureBlack ? Colors.black : const Color(0xFF16171B);

    final baseTheme = ThemeData(
      useMaterial3: true,
      splashFactory: const HapticSplashFactory(),
      colorScheme: isPureBlack
          ? scheme.copyWith(
              surface: Colors.black,
              surfaceContainer: const Color(0xFF121212),
              surfaceContainerHigh: const Color(0xFF181818),
              surfaceContainerHighest: const Color(0xFF222222),
            )
          : scheme,
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: getBoldFontWeight(fontWeightIndex),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isPureBlack
                ? Colors.white.withValues(alpha: 0.12)
                : scheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        color: cardColor,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: navBgColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isPureBlack
            ? Colors.white.withValues(alpha: 0.1)
            : scheme.outlineVariant.withValues(alpha: 0.2),
        thickness: 0.5,
      ),
    );

    return baseTheme.copyWith(
      textTheme: _applyFontWeight(baseTheme.textTheme, fontWeightIndex),
    );
  }
}

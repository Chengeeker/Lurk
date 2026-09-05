import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import 'display_mode_settings_page.dart';

class PersonalizationSettingsPage extends ConsumerWidget {
  const PersonalizationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedbackUtil.light();
            Navigator.of(context).pop();
          },
        ),
        title: const Text('个性化', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '外观与视觉',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.dark_mode_outlined, color: colorScheme.primary),
                  title: const Text('夜间模式', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_getThemeModeLabel(themeState.themeMode), style: const TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('选择夜间模式'),
                        children: [
                          _buildThemeModeOption(context, themeNotifier, ThemeMode.system, '跟随系统'),
                          _buildThemeModeOption(context, themeNotifier, ThemeMode.light, '始终浅色'),
                          _buildThemeModeOption(context, themeNotifier, ThemeMode.dark, '始终深色'),
                        ],
                      ),
                    );
                  },
                ),
                if (isDark) ...[
                  Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                  SwitchListTile(
                    secondary: Icon(Icons.brightness_2_outlined, color: colorScheme.primary),
                    title: const Text('纯黑深色模式', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('针对 OLED 屏幕优化的纯黑背景', style: TextStyle(fontSize: 12.5)),
                    value: themeState.isPureBlackDark,
                    onChanged: (val) {
                      HapticFeedbackUtil.light();
                      themeNotifier.setPureBlackDark(val);
                    },
                  ),
                ],
                Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                SwitchListTile(
                  secondary: Icon(Icons.color_lens_outlined, color: colorScheme.primary),
                  title: const Text('动态色彩 (Material You)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('从壁纸中提取主色调（需 Android 12+）', style: TextStyle(fontSize: 12.5)),
                  value: themeState.useDynamicColor,
                  onChanged: (val) {
                    HapticFeedbackUtil.light();
                    themeNotifier.setUseDynamicColor(val);
                  },
                ),
                if (!themeState.useDynamicColor) ...[
                  Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('预设主题色', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(AppTheme.themeColors.length, (index) {
                            final color = AppTheme.themeColors[index]['color'] as Color;
                            final isSelected = themeState.themeColorIndex == index;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedbackUtil.light();
                                themeNotifier.setThemeColorIndex(index);
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? colorScheme.onSurface : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                ListTile(
                  leading: Icon(Icons.format_size_rounded, color: colorScheme.primary),
                  title: const Text('字体粗细调节', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_getFontWeightLabel(themeState.fontWeightIndex), style: const TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('设置字体粗细'),
                        children: [
                          _buildFontWeightOption(context, themeNotifier, 0, '偏细 (Light)'),
                          _buildFontWeightOption(context, themeNotifier, 1, '默认 (Regular)'),
                          _buildFontWeightOption(context, themeNotifier, 2, '中等 (Medium)'),
                          _buildFontWeightOption(context, themeNotifier, 3, '偏粗 (SemiBold)'),
                          _buildFontWeightOption(context, themeNotifier, 4, '加粗 (Bold)'),
                        ],
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                ListTile(
                  leading: Icon(Icons.speed_rounded, color: colorScheme.primary),
                  title: const Text('屏幕帧率设置', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('选择屏幕刷新率档位', style: TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.of(context).push(
                      SpringPageRoute(page: const DisplayModeSettingsPage()),
                    );
                  },
                ),
                Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                SwitchListTile(
                  secondary: Icon(Icons.view_carousel_outlined, color: colorScheme.primary),
                  title: const Text('悬浮胶囊底栏', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('开启后底部使用浮动胶囊导航条', style: TextStyle(fontSize: 12.5)),
                  value: themeState.useFloatingNavBar,
                  onChanged: (val) {
                    HapticFeedbackUtil.light();
                    themeNotifier.setUseFloatingNavBar(val);
                  },
                ),
                Divider(height: 1, indent: 56, color: theme.dividerColor.withValues(alpha: 0.1)),
                SwitchListTile(
                  secondary: Icon(Icons.vibration_rounded, color: colorScheme.primary),
                  title: const Text('震动反馈', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('触控与操作轻微震动反馈', style: TextStyle(fontSize: 12.5)),
                  value: themeState.enableHaptics,
                  onChanged: (val) {
                    HapticFeedbackUtil.light();
                    themeNotifier.setEnableHaptics(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '始终浅色';
      case ThemeMode.dark:
        return '始终深色';
    }
  }

  Widget _buildThemeModeOption(BuildContext context, ThemeNotifier notifier, ThemeMode mode, String label) {
    return SimpleDialogOption(
      onPressed: () {
        HapticFeedbackUtil.light();
        notifier.setThemeMode(mode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  String _getFontWeightLabel(int index) {
    switch (index) {
      case 0:
        return '偏细 (Light)';
      case 1:
        return '默认 (Regular)';
      case 2:
        return '中等 (Medium)';
      case 3:
        return '偏粗 (SemiBold)';
      case 4:
        return '加粗 (Bold)';
      default:
        return '默认';
    }
  }

  Widget _buildFontWeightOption(BuildContext context, ThemeNotifier notifier, int index, String label) {
    return SimpleDialogOption(
      onPressed: () {
        HapticFeedbackUtil.light();
        notifier.setFontWeightIndex(index);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: AppTheme.getBaseFontWeight(index),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

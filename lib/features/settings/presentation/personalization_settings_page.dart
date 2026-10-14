import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../../core/widgets/app_section_card.dart';
import 'display_mode_settings_page.dart';

class PersonalizationSettingsPage extends ConsumerWidget {
  const PersonalizationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final colorScheme = theme.colorScheme;

    Widget section(String title, Widget content) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
        AppSectionCard(child: content),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('个性化')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          section(
            '明暗模式',
            Column(
              children: [
                RadioGroup<ThemeMode>(
                  groupValue: themeState.themeMode,
                  onChanged: (value) {
                    if (value == null) return;
                    HapticFeedbackUtil.light();
                    themeNotifier.setThemeMode(value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: Text('跟随系统'),
                      ),
                      Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: Text('浅色模式'),
                      ),
                      Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: Text('深色模式'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.contrast_rounded, size: 24),
                  title: const Text('纯黑深色模式 (OLED 省电)'),
                  value: themeState.isPureBlackDark,
                  onChanged: (value) {
                    HapticFeedbackUtil.light();
                    themeNotifier.setPureBlackDark(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          section(
            '色彩方案',
            Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_outlined, size: 24),
                  title: const Text('Material You (Monet) 动态取色'),
                  value: themeState.useDynamicColor,
                  onChanged: (value) {
                    HapticFeedbackUtil.light();
                    themeNotifier.setUseDynamicColor(value);
                  },
                ),
                if (!themeState.useDynamicColor) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '预置主题配色搭配',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(AppTheme.themeColors.length, (
                        index,
                      ) {
                        final item = AppTheme.themeColors[index];
                        final name = item['name'] as String;
                        final color = item['color'] as Color;
                        final isSelected = themeState.themeColorIndex == index;

                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: color,
                            radius: 10,
                          ),
                          label: Text(name),
                          selected: isSelected,
                          onSelected: (_) {
                            HapticFeedbackUtil.light();
                            themeNotifier.setThemeColorIndex(index);
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          section(
            '字体粗细',
            ListTile(
              leading: const Icon(Icons.format_bold_rounded, size: 24),
              title: const Text('自定义应用字体粗细'),
              subtitle: Text(
                '当前：${_getFontWeightLabel(themeState.fontWeightIndex)}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showFontWeightDialog(context, ref, themeState),
            ),
          ),
          const SizedBox(height: 32),
          section(
            '字体大小',
            ListTile(
              leading: const Icon(Icons.format_size_rounded, size: 24),
              title: const Text('应用字体大小'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${themeState.fontSizePercent}%'),
                  Slider(
                    key: const ValueKey('app-text-scale-slider'),
                    value: themeState.fontSizePercent / 100,
                    min: 0.8,
                    max: 1.4,
                    divisions: 12,
                    label: '${themeState.fontSizePercent}%',
                    onChanged: (value) {
                      themeNotifier.previewFontSizePercent(
                        (value * 100).round(),
                      );
                    },
                    onChangeEnd: (value) {
                      themeNotifier.setFontSizePercent((value * 100).round());
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          section(
            '导航布局风格',
            SwitchListTile(
              secondary: const Icon(Icons.dock_rounded, size: 24),
              title: const Text('悬浮胶囊底栏 (MD3 Expressive)'),
              value: themeState.useFloatingNavBar,
              onChanged: (value) {
                HapticFeedbackUtil.light();
                themeNotifier.setUseFloatingNavBar(value);
              },
            ),
          ),
          const SizedBox(height: 32),
          section(
            '屏幕显示',
            ListTile(
              leading: const Icon(Icons.speed_rounded, size: 24),
              title: const Text('屏幕帧率设置'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedbackUtil.light();
                Navigator.of(
                  context,
                ).push(SpringPageRoute(page: const DisplayModeSettingsPage()));
              },
            ),
          ),
          const SizedBox(height: 32),
          section(
            '触感与震动',
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded, size: 24),
              title: const Text('触感与震动反馈'),
              value: themeState.enableHaptics,
              onChanged: (value) {
                HapticFeedbackUtil.light();
                themeNotifier.setEnableHaptics(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFontWeightDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeState themeState,
  ) {
    HapticFeedbackUtil.light();
    final notifier = ref.read(themeProvider.notifier);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择字体粗细'),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: RadioGroup<int>(
          groupValue: themeState.fontWeightIndex,
          onChanged: (value) {
            if (value == null) return;
            HapticFeedbackUtil.light();
            notifier.setFontWeightIndex(value);
            Navigator.pop(dialogContext);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final isSelected = themeState.fontWeightIndex == index;
              return RadioListTile<int>(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                title: Text(
                  _getFontWeightLabel(index),
                  style: TextStyle(
                    fontWeight: AppTheme.getBaseFontWeight(index),
                    color: isSelected
                        ? Theme.of(dialogContext).colorScheme.primary
                        : null,
                  ),
                ),
                value: index,
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  String _getFontWeightLabel(int index) {
    switch (index) {
      case 0:
        return '偏细';
      case 1:
        return '默认';
      case 2:
        return '中等';
      case 3:
        return '偏粗';
      case 4:
        return '加粗';
      default:
        return '默认';
    }
  }
}

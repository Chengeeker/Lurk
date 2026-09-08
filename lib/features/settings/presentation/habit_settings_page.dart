import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "providers/habit_settings_provider.dart";

class HabitSettingsPage extends ConsumerWidget {
  const HabitSettingsPage({super.key});

  static const _tabTitles = ["进吧", "动态", "消息", "我的"];
  static const _imageModes = ["智能省流量", "智能无图", "始终高质量", "始终无图"];
  static const _forumSortTitles = ["回复时间排序", "发帖时间排序"];

  void _showInitialTabDialog(BuildContext context, int current, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(
          "选择启动首选页",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        children: List.generate(_tabTitles.length, (index) {
          final isSelected = current == index;
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () {
              ref
                  .read(habitSettingsProvider.notifier)
                  .setInitialTabIndex(index);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _tabTitles[index],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showImageModeDialog(BuildContext context, int current, WidgetRef ref) {
    final descriptions = [
      "自动压缩优化，列表省流，查看大图加载高清原图（推荐）",
      "列表仅展示占位提示，点击才加载图片，极致省流",
      "所有位置均优先请求无压缩原图，画质极致",
      "完全不加载并隐藏贴子配图，纯文本浏览",
    ];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(
          "图片加载设置",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        children: List.generate(_imageModes.length, (index) {
          final isSelected = current == index;
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () {
              ref.read(habitSettingsProvider.notifier).setImageLoadMode(index);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _imageModes[index],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descriptions[index],
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showForumSortDialog(BuildContext context, int current, WidgetRef ref) {
    final descriptions = ["优先展示最近有新回帖的贴子（平台默认）", "按贴子最初发表时间倒序排列，查看最新贴子"];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(
          "默认排序方式",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        children: List.generate(_forumSortTitles.length, (index) {
          final isSelected = current == index;
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () {
              ref
                  .read(habitSettingsProvider.notifier)
                  .setForumDefaultSort(index);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _forumSortTitles[index],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descriptions[index],
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final habitState = ref.watch(habitSettingsProvider);
    final habitNotifier = ref.read(habitSettingsProvider.notifier);

    final initialTabName =
        (habitState.initialTabIndex >= 0 &&
            habitState.initialTabIndex < _tabTitles.length)
        ? _tabTitles[habitState.initialTabIndex]
        : "推荐";

    final imageModeName =
        (habitState.imageLoadMode >= 0 &&
            habitState.imageLoadMode < _imageModes.length)
        ? _imageModes[habitState.imageLoadMode]
        : "智能省流量";

    final forumSortName =
        (habitState.forumDefaultSort >= 0 &&
            habitState.forumDefaultSort < _forumSortTitles.length)
        ? _forumSortTitles[habitState.forumDefaultSort]
        : "回复时间排序";

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          "使用习惯",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "启动与偏好",
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
                  leading: Icon(
                    Icons.home_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "启动首选页",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "当前首选：$initialTabName",
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInitialTabDialog(
                    context,
                    habitState.initialTabIndex,
                    ref,
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_filter_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "图片加载设置",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "当前模式：$imageModeName",
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showImageModeDialog(
                    context,
                    habitState.imageLoadMode,
                    ref,
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                ListTile(
                  leading: Icon(Icons.sort_rounded, color: colorScheme.primary),
                  title: const Text(
                    "吧默认排序方式",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "当前排序：$forumSortName",
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showForumSortDialog(
                    context,
                    habitState.forumDefaultSort,
                    ref,
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.history_toggle_off_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "不保存浏览记录",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "开启后，看帖与进吧均不会写入本地浏览历史",
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: habitState.doNotSaveHistory,
                  onChanged: (val) {
                    habitNotifier.setDoNotSaveHistory(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "浏览与交互偏好",
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
                SwitchListTile(
                  secondary: Icon(
                    Icons.autorenew_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "自动加载更多",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "滑动至列表底部时自动预载下一页内容",
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: habitState.autoLoadMore,
                  onChanged: (val) {
                    habitNotifier.setAutoLoadMore(val);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.vertical_align_top_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "双击顶栏返回顶部",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "快速双击顶部标题栏平滑滚回页面最上方",
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: habitState.doubleTapTop,
                  onChanged: (val) {
                    habitNotifier.setDoubleTapTop(val);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.image_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "看图优先加载高清原图",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "进入大图查看时自动加载高清未压缩原图",
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: habitState.showOriginalImg,
                  onChanged: (val) {
                    habitNotifier.setShowOriginalImg(val);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.touch_app_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "双击底栏快速刷新",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "在推荐页双击底部导航栏图标自动触发刷新",
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: habitState.doubleTapFeedRefresh,
                  onChanged: (val) {
                    habitNotifier.setDoubleTapFeedRefresh(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

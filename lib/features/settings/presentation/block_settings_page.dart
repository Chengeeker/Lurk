import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import 'block_words_manager_page.dart';
import 'providers/block_settings_provider.dart';

class BlockSettingsPage extends ConsumerWidget {
  const BlockSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockState = ref.watch(blockSettingsProvider);
    final blockNotifier = ref.read(blockSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedbackUtil.light();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          '屏蔽设置',
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
              '内容过滤与屏蔽',
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
                    Icons.filter_alt_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '屏蔽词管理',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '黑名单 ${blockState.blockWords.length} 个  |  白名单 ${blockState.whiteWords.length} 个',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedbackUtil.light();
                    Navigator.of(context).push(
                      SpringPageRoute(page: const BlockWordsManagerPage()),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.visibility_off_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '彻底隐藏被屏蔽的内容',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '开启后被屏蔽内容直接不显示，不留占位符',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: blockState.hideBlockedCompletely,
                  onChanged: (val) {
                    HapticFeedbackUtil.light();
                    blockNotifier.setHideBlockedCompletely(val);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.videocam_off_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '不看视频贴',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '自动过滤推荐流与社区中的所有视频内容',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: blockState.blockVideoThreads,
                  onChanged: (val) {
                    HapticFeedbackUtil.light();
                    blockNotifier.setBlockVideoThreads(val);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.favorite_outline_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    '只推荐已关注的吧',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '主页推荐信息流仅展示已关注版块的内容',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: blockState.recommendFollowedOnly,
                  onChanged: (val) {
                    HapticFeedbackUtil.light();
                    blockNotifier.setRecommendFollowedOnly(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

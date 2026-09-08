import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import 'providers/block_settings_provider.dart';

class BlockWordsManagerPage extends ConsumerStatefulWidget {
  const BlockWordsManagerPage({super.key});

  @override
  ConsumerState<BlockWordsManagerPage> createState() => _BlockWordsManagerPageState();
}

class _BlockWordsManagerPageState extends ConsumerState<BlockWordsManagerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _blackInputController = TextEditingController();
  final TextEditingController _whiteInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _blackInputController.dispose();
    _whiteInputController.dispose();
    super.dispose();
  }

  void _addBlackWord() {
    final text = _blackInputController.text.trim();
    if (text.isEmpty) return;
    HapticFeedbackUtil.light();
    ref.read(blockSettingsProvider.notifier).addBlockWord(text);
    _blackInputController.clear();
  }

  void _addWhiteWord() {
    final text = _whiteInputController.text.trim();
    if (text.isEmpty) return;
    HapticFeedbackUtil.light();
    ref.read(blockSettingsProvider.notifier).addWhiteWord(text);
    _whiteInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockState = ref.watch(blockSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedbackUtil.light();
            Navigator.of(context).pop();
          },
        ),
        title: const Text('屏蔽词管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(text: '黑名单 (${blockState.blockWords.length})'),
            Tab(text: '白名单 (${blockState.whiteWords.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWordListTab(
            isBlackList: true,
            words: blockState.blockWords,
            controller: _blackInputController,
            hintText: '输入屏蔽词，标题或内容包含时屏蔽...',
            onAdd: _addBlackWord,
            onRemove: (word) => ref.read(blockSettingsProvider.notifier).removeBlockWord(word),
            onClearAll: () => ref.read(blockSettingsProvider.notifier).clearBlockWords(),
            emptyMessage: '暂无黑名单屏蔽词\n添加后包含该词的帖子将被过滤屏蔽',
            colorScheme: colorScheme,
            theme: theme,
          ),
          _buildWordListTab(
            isBlackList: false,
            words: blockState.whiteWords,
            controller: _whiteInputController,
            hintText: '输入白名单词，命中时免受黑名单屏蔽...',
            onAdd: _addWhiteWord,
            onRemove: (word) => ref.read(blockSettingsProvider.notifier).removeWhiteWord(word),
            onClearAll: () => ref.read(blockSettingsProvider.notifier).clearWhiteWords(),
            emptyMessage: '暂无白名单词\n白名单内的词汇将豁免黑名单屏蔽规则',
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildWordListTab({
    required bool isBlackList,
    required List<String> words,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
    required VoidCallback onClearAll,
    required String emptyMessage,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(fontSize: 13.5, color: colorScheme.outline),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => controller.clear(),
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text('添加', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        if (words.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已添加 ${words.length} 个词汇',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.outline),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedbackUtil.light();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('清空${isBlackList ? "黑名单" : "白名单"}'),
                        content: Text('确定要清空全部${isBlackList ? "黑名单" : "白名单"}词汇吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onClearAll();
                            },
                            child: const Text('清空', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('清空全部', style: TextStyle(fontSize: 12.5, color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        Expanded(
          child: words.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isBlackList ? Icons.shield_outlined : Icons.verified_user_outlined,
                        size: 56,
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: words.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.06),
                          width: 0.8,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isBlackList
                                ? Colors.redAccent.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isBlackList ? Colors.redAccent : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          word,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: colorScheme.error.withValues(alpha: 0.8),
                          onPressed: () {
                            HapticFeedbackUtil.light();
                            onRemove(word);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

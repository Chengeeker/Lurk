import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/cache_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/widgets/app_section_card.dart';

class CacheManagementPage extends ConsumerStatefulWidget {
  const CacheManagementPage({super.key});

  @override
  ConsumerState<CacheManagementPage> createState() =>
      _CacheManagementPageState();
}

class _CacheManagementPageState extends ConsumerState<CacheManagementPage> {
  CacheBreakdown _stats = CacheBreakdown.empty;
  late int _thresholdMb;
  bool _loading = true;
  bool _loadFailed = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _thresholdMb = ref
        .read(storageServiceProvider)
        .getAutoClearCacheThresholdMb();
    _loadStats();
  }

  Future<void> _loadStats({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final stats = await CacheService.getCacheStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loadFailed = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    if (_clearing) return;
    HapticFeedbackUtil.light();

    final bytesBeforeClear = _stats.totalBytes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理所有缓存？'),
        content: Text(
          _loadFailed || bytesBeforeClear <= 0
              ? '将清理 Lurk 的图片缓存及 Android 应用缓存目录。不会删除账号、收藏、浏览记录或已保存的照片和视频。'
              : '将清理约 ${CacheBreakdown.formatBytes(bytesBeforeClear)} 的图片、网络与运行时缓存。不会删除账号、收藏、浏览记录或已保存的照片和视频。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('立即清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    HapticFeedbackUtil.medium();
    final clearedBytes = await CacheService.clearCache();
    await _loadStats(showLoading: false);
    if (!mounted) return;
    setState(() => _clearing = false);
    HapticFeedbackUtil.medium();
    if (clearedBytes == null) {
      AppToast.show(context, '图片缓存已清理，但 Android 缓存目录清理失败');
      return;
    }
    AppToast.show(
      context,
      clearedBytes > 0
          ? '缓存清理完毕，已释放 ${CacheBreakdown.formatBytes(clearedBytes)} 空间'
          : '缓存清理完毕',
    );
  }

  Future<void> _selectThreshold() async {
    HapticFeedbackUtil.light();
    const options = <(String, int)>[
      ('不限制（从不自动清理）', 0),
      ('50 MB', 50),
      ('100 MB', 100),
      ('200 MB', 200),
      ('500 MB', 500),
      ('1 GB (1024 MB)', 1024),
      ('2 GB (2048 MB)', 2048),
    ];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择自动清理阈值'),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: RadioGroup<int>(
          groupValue: _thresholdMb,
          onChanged: (value) {
            if (value == null) return;
            HapticFeedbackUtil.light();
            Navigator.pop(dialogContext, value);
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, value) in options)
                  RadioListTile<int>(
                    title: Text(label),
                    value: value,
                    dense: true,
                  ),
              ],
            ),
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
    if (selected == null) return;

    await ref
        .read(storageServiceProvider)
        .setAutoClearCacheThresholdMb(selected);
    if (!mounted) return;
    setState(() => _thresholdMb = selected);
    final cleared = selected > 0
        ? await CacheService.checkAndAutoClearCache(selected)
        : false;
    if (!mounted) return;
    if (cleared) await _loadStats(showLoading: false);
    if (!mounted) return;
    AppToast.show(
      context,
      selected == 0 ? '已关闭自动清理' : '已设置缓存阈值为 ${_formatThreshold(selected)}',
    );
  }

  String _formatThreshold(int mb) {
    if (mb <= 0) return '不限制（从不自动清理）';
    if (mb >= 1024) {
      final value = (mb / 1024).toStringAsFixed(mb % 1024 == 0 ? 0 : 1);
      return '$value GB';
    }
    return '$mb MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final storage = ref.watch(storageServiceProvider);
    final clearOnExit = storage.getAutoClearCacheOnExit();

    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildOverviewCard(colorScheme),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_loading || _clearing) ? null : _clearCache,
                  icon: _clearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_sweep_rounded),
                  label: Text(_clearing ? '正在清理...' : '一键清理所有缓存'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, '自动清理规则'),
          const SizedBox(height: 12),
          AppSectionCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.auto_delete_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('自动清理缓存阈值'),
                  subtitle: const Text('启动时达到阈值后自动清理'),
                  trailing: Text(
                    _formatThreshold(_thresholdMb),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _selectThreshold,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: Icon(
                    Icons.exit_to_app_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('退出时自动清理缓存'),
                  value: clearOnExit,
                  onChanged: (value) async {
                    HapticFeedbackUtil.light();
                    await storage.setAutoClearCacheOnExit(value);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, '清理范围'),
          const SizedBox(height: 12),
          AppSectionCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '清理范围包括图片内存与磁盘缓存，以及 Android 应用缓存目录。分类按文件名和扩展名估算。不会清除账号凭据、收藏、浏览记录或保存到系统相册的媒体。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(ColorScheme colorScheme) {
    final total = _stats.totalBytes;
    final imageRatio = total > 0 ? _stats.imageBytes / total : 0.0;
    final networkRatio = total > 0 ? _stats.networkBytes / total : 0.0;
    final systemRatio = total > 0 ? _stats.systemBytes / total : 0.0;

    return AppSectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.cleaning_services_rounded,
              color: colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Text(
                _loadFailed ? '暂不可用' : CacheBreakdown.formatBytes(total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '当前应用缓存占用',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (_loadFailed)
              TextButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新读取'),
              )
            else ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 10,
                  color: colorScheme.surfaceContainerHighest,
                  child: total <= 0
                      ? null
                      : Row(
                          children: [
                            if (imageRatio > 0)
                              Expanded(
                                flex: (imageRatio * 1000).round().clamp(
                                  1,
                                  1000,
                                ),
                                child: ColoredBox(color: colorScheme.primary),
                              ),
                            if (networkRatio > 0)
                              Expanded(
                                flex: (networkRatio * 1000).round().clamp(
                                  1,
                                  1000,
                                ),
                                child: ColoredBox(color: colorScheme.tertiary),
                              ),
                            if (systemRatio > 0)
                              Expanded(
                                flex: (systemRatio * 1000).round().clamp(
                                  1,
                                  1000,
                                ),
                                child: ColoredBox(color: colorScheme.secondary),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildLegendItem(
                    colorScheme.primary,
                    '图片与媒体',
                    _stats.imageBytes,
                    colorScheme,
                  ),
                  _buildLegendItem(
                    colorScheme.tertiary,
                    '网络与临时',
                    _stats.networkBytes,
                    colorScheme,
                  ),
                  _buildLegendItem(
                    colorScheme.secondary,
                    '系统运行时',
                    _stats.systemBytes,
                    colorScheme,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label,
    int bytes,
    ColorScheme colorScheme,
  ) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CacheBreakdown.formatBytes(bytes),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

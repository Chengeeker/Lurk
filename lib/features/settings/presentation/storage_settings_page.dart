// ignore_for_file: deprecated_member_use
import "package:extended_image/extended_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/auth/auth_provider.dart";
import "../../../core/storage/storage_service.dart";
import "../../../core/utils/app_toast.dart";
import "../../../core/utils/haptic_feedback_util.dart";

/// 存储设置页面 (管理图片与视频存储路径、缓存自动与手动清理)
class StorageSettingsPage extends ConsumerStatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  ConsumerState<StorageSettingsPage> createState() =>
      _StorageSettingsPageState();
}

class _StorageSettingsPageState extends ConsumerState<StorageSettingsPage> {
  String _getPathSummary(int type, String myNickname, {required bool isVideo}) {
    switch (type) {
      case 1:
        return "Pictures/Lurk/$myNickname/";
      case 2:
        return "Pictures/Lurk/该贴发布用户昵称/";
      default:
        return "Pictures/Lurk/";
    }
  }

  void _showPathSelectorDialog(
    BuildContext context,
    StorageService storage,
    String myNickname, {
    required bool isVideo,
  }) {
    HapticFeedbackUtil.light();
    final currentType = isVideo
        ? storage.getVideoSavePathType()
        : storage.getImageSavePathType();
    final title = isVideo ? "视频存储路径" : "图片存储路径";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "保存${isVideo ? "视频" : "图片"}时，文件将自动归类并存储至相册对应文件夹下。",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Option 0: Pictures/Lurk/
                ListTile(
                  title: const Text(
                    "默认路径",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Pictures/Lurk/",
                    style: TextStyle(fontSize: 12),
                  ),
                  leading: Radio<int>(
                    value: 0,
                    groupValue: currentType,
                    onChanged: (val) async {
                      if (val != null) {
                        HapticFeedbackUtil.light();
                        Navigator.pop(ctx);
                        if (isVideo) {
                          await storage.setVideoSavePathType(val);
                        } else {
                          await storage.setImageSavePathType(val);
                        }
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  onTap: () async {
                    HapticFeedbackUtil.light();
                    Navigator.pop(ctx);
                    if (isVideo) {
                      await storage.setVideoSavePathType(0);
                    } else {
                      await storage.setImageSavePathType(0);
                    }
                    if (mounted) setState(() {});
                  },
                ),

                // Option 1: Pictures/Lurk/自己的用户昵称
                ListTile(
                  title: const Text(
                    "按本人昵称前缀归类",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Pictures/Lurk/$myNickname/",
                    style: const TextStyle(fontSize: 12),
                  ),
                  leading: Radio<int>(
                    value: 1,
                    groupValue: currentType,
                    onChanged: (val) async {
                      if (val != null) {
                        HapticFeedbackUtil.light();
                        Navigator.pop(ctx);
                        if (isVideo) {
                          await storage.setVideoSavePathType(val);
                        } else {
                          await storage.setImageSavePathType(val);
                        }
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  onTap: () async {
                    HapticFeedbackUtil.light();
                    Navigator.pop(ctx);
                    if (isVideo) {
                      await storage.setVideoSavePathType(1);
                    } else {
                      await storage.setImageSavePathType(1);
                    }
                    if (mounted) setState(() {});
                  },
                ),

                // Option 2: Pictures/Lurk/该贴发布用户昵称
                ListTile(
                  title: const Text(
                    "按楼主昵称前缀归类",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Pictures/Lurk/该贴发布用户昵称/",
                    style: TextStyle(fontSize: 12),
                  ),
                  leading: Radio<int>(
                    value: 2,
                    groupValue: currentType,
                    onChanged: (val) async {
                      if (val != null) {
                        HapticFeedbackUtil.light();
                        Navigator.pop(ctx);
                        if (isVideo) {
                          await storage.setVideoSavePathType(val);
                        } else {
                          await storage.setImageSavePathType(val);
                        }
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  onTap: () async {
                    HapticFeedbackUtil.light();
                    Navigator.pop(ctx);
                    if (isVideo) {
                      await storage.setVideoSavePathType(2);
                    } else {
                      await storage.setImageSavePathType(2);
                    }
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storageService = ref.watch(storageServiceProvider);
    final authState = ref.watch(authStateProvider);
    final myNickname = authState.activeAccount?.displayName ?? "MyProfile";

    final imagePathType = storageService.getImageSavePathType();
    final videoPathType = storageService.getVideoSavePathType();
    final autoClearCache = storageService.getAutoClearCacheOnExit();

    return Scaffold(
      appBar: AppBar(title: const Text("存储设置")),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. 媒体保存路径卡片
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.image_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "图片存储路径",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _getPathSummary(imagePathType, myNickname, isVideo: false),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPathSelectorDialog(
                    context,
                    storageService,
                    myNickname,
                    isVideo: false,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    Icons.video_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "视频存储路径",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _getPathSummary(videoPathType, myNickname, isVideo: true),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPathSelectorDialog(
                    context,
                    storageService,
                    myNickname,
                    isVideo: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. 缓存管理卡片
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.auto_delete_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "退出时自动清理缓存",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "应用关闭时自动清理网络图片与临时缓存文件",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: autoClearCache,
                  onChanged: (val) async {
                    HapticFeedbackUtil.light();
                    await storageService.setAutoClearCacheOnExit(val);
                    setState(() {});
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    Icons.cleaning_services_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    "立即清理缓存",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "清除本地网络图片与磁盘缓存，释放存储空间",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    HapticFeedbackUtil.medium();
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    await clearDiskCachedImages();
                    clearMemoryImageCache();
                    if (context.mounted) {
                      AppToast.show(context, "已成功清理全部临时缓存文件");
                    }
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

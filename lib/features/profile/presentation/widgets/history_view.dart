import "dart:convert";
import "package:extended_image/extended_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/storage/storage_service.dart";
import "../../../../core/utils/app_dialog.dart";
import "../../../../core/utils/app_toast.dart";
import "../../../../core/utils/spring_page_route.dart";
import "../../../feed/data/models/tieba_thread_model.dart";
import "../../../feed/presentation/widgets/tieba_card.dart";
import "../../../forum/data/forum_repository.dart";
import "../../../forum/data/models/forum_model.dart";
import "../../../forum/presentation/forum_view.dart";
import "../../../my_forums/presentation/my_forums_controller.dart";

class ForumHistoryItem {
  final String name;
  final String avatar;
  final int time;

  const ForumHistoryItem({
    required this.name,
    this.avatar = "",
    this.time = 0,
  });

  factory ForumHistoryItem.fromJson(Map<String, dynamic> json) {
    return ForumHistoryItem(
      name: json["name"]?.toString() ?? "",
      avatar: json["avatar"]?.toString() ?? "",
      time: int.tryParse(json["time"]?.toString() ?? "0") ?? 0,
    );
  }
}

class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<TiebaThreadModel> _threadHistory = [];
  List<ForumHistoryItem> _forumHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAllHistory() {
    final storage = ref.read(storageServiceProvider);

    // 1. 加载帖子记录
    final rawThreads = storage.getStringList(StorageService.keyBrowsingHistory);
    final tList = <TiebaThreadModel>[];
    for (var item in rawThreads) {
      try {
        tList.add(TiebaThreadModel.fromJson(jsonDecode(item)));
      } catch (_) {}
    }

    // 2. 加载经过贴吧并尝试用已关注吧补充头像
    final followedForums = ref.read(myForumsControllerProvider).forums;
    final Map<String, String> avatarMap = {};
    for (var f in followedForums) {
      if (f.avatar.isNotEmpty) {
        avatarMap[f.name] = f.avatar;
      }
    }

    final rawForums =
        storage.getStringList(StorageService.keyForumBrowsingHistory);
    final fList = <ForumHistoryItem>[];
    bool hasMissingAvatar = false;
    bool needsStorageUpdate = false;

    for (var item in rawForums) {
      try {
        var parsed = ForumHistoryItem.fromJson(jsonDecode(item));
        if (parsed.avatar.isEmpty && avatarMap.containsKey(parsed.name)) {
          parsed = ForumHistoryItem(
            name: parsed.name,
            avatar: avatarMap[parsed.name]!,
            time: parsed.time,
          );
          needsStorageUpdate = true;
        }
        if (parsed.avatar.isEmpty) {
          hasMissingAvatar = true;
        }
        fList.add(parsed);
      } catch (_) {}
    }

    if (needsStorageUpdate) {
      storage.setStringList(
        StorageService.keyForumBrowsingHistory,
        fList
            .map((e) => jsonEncode({
                  "name": e.name,
                  "avatar": e.avatar,
                  "time": e.time,
                }))
            .toList(),
      );
    }

    setState(() {
      _threadHistory = tList.reversed.toList();
      _forumHistory = fList;
      _isLoading = false;
    });

    // 3. 若有缺失头像的贴吧，在后台异步获取详情并补全持久化
    if (hasMissingAvatar) {
      _fetchMissingAvatars();
    }
  }

  void _fetchMissingAvatars() {
    Future.microtask(() async {
      if (!mounted) return;
      final repo = ref.read(forumRepositoryProvider);
      bool anyUpdated = false;
      final updatedList = List<ForumHistoryItem>.from(_forumHistory);

      for (int i = 0; i < updatedList.length; i++) {
        if (updatedList[i].avatar.isEmpty) {
          try {
            final pageData =
                await repo.getForumPage(forumName: updatedList[i].name, page: 1);
            final detail = pageData['forum'] as ForumDetailModel?;
            if (detail != null && detail.avatar.isNotEmpty) {
              updatedList[i] = ForumHistoryItem(
                name: updatedList[i].name,
                avatar: detail.avatar,
                time: updatedList[i].time,
              );
              anyUpdated = true;
            }
          } catch (_) {}
        }
      }

      if (anyUpdated && mounted) {
        setState(() {
          _forumHistory = updatedList;
        });
        final storage = ref.read(storageServiceProvider);
        await storage.setStringList(
          StorageService.keyForumBrowsingHistory,
          updatedList
              .map((e) => jsonEncode({
                    "name": e.name,
                    "avatar": e.avatar,
                    "time": e.time,
                  }))
              .toList(),
        );
      }
    });
  }

  void _clearThreadHistory() async {
    final confirm = await AppDialog.confirm(
      context,
      title: "清空帖子浏览记录",
      content: "确定要清空全部看过的帖子历史吗？",
      confirmText: "清空",
      isDanger: true,
    );
    if (confirm != true) return;

    final storage = ref.read(storageServiceProvider);
    await storage.setStringList(StorageService.keyBrowsingHistory, []);
    _loadAllHistory();
    if (mounted) {
      AppToast.show(context, "帖子浏览记录已清空");
    }
  }

  void _clearForumHistory() async {
    final confirm = await AppDialog.confirm(
      context,
      title: "清空经过贴吧足迹",
      content: "确定要清空全部进入过的贴吧历史吗？",
      confirmText: "清空",
      isDanger: true,
    );
    if (confirm != true) return;

    final storage = ref.read(storageServiceProvider);
    await storage.setStringList(StorageService.keyForumBrowsingHistory, []);
    _loadAllHistory();
    if (mounted) {
      AppToast.show(context, "经过贴吧足迹已清空");
    }
  }

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return "";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return "刚刚";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} 分钟前";
    } else if (diff.inHours < 24 && date.day == now.day) {
      return "今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays < 2) {
      return "昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.month}月${date.day}日";
    }
  }

  Widget _buildForumFallback(String name, ColorScheme colorScheme) {
    final char = name.isNotEmpty ? name.characters.first : "吧";
    return Center(
      child: Text(
        char,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("浏览记录", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: "清空当前记录",
            onPressed: () {
              if (_tabController.index == 0) {
                if (_threadHistory.isNotEmpty) _clearThreadHistory();
              } else {
                if (_forumHistory.isNotEmpty) _clearForumHistory();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "帖子记录"),
            Tab(text: "经过贴吧"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildThreadHistoryTab(colorScheme),
                _buildForumHistoryTab(colorScheme),
              ],
            ),
    );
  }

  Widget _buildThreadHistoryTab(ColorScheme colorScheme) {
    if (_threadHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded,
                size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text("暂无帖子浏览记录",
                style: TextStyle(color: colorScheme.outline, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _threadHistory.length,
      itemBuilder: (context, index) {
        final thread = _threadHistory[index];
        return TiebaCard(thread: thread);
      },
    );
  }

  Widget _buildForumHistoryTab(ColorScheme colorScheme) {
    if (_forumHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined,
                size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text("暂无经过贴吧足迹",
                style: TextStyle(color: colorScheme.outline, fontSize: 15)),
            const SizedBox(height: 6),
            Text("逛过的贴吧都会自动记录在这里",
                style: TextStyle(
                    color: colorScheme.outline.withValues(alpha: 0.7),
                    fontSize: 12.5)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _forumHistory.length,
      itemBuilder: (context, index) {
        final item = _forumHistory[index];
        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 8),
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                SpringPageRoute(page: ForumView(forumName: item.name)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: colorScheme.surfaceContainerHighest,
                      child: item.avatar.isNotEmpty
                          ? ExtendedImage.network(
                              item.avatar,
                              fit: BoxFit.cover,
                              cache: true,
                              loadStateChanged: (state) {
                                if (state.extendedImageLoadState ==
                                    LoadState.completed) {
                                  return null;
                                }
                                return _buildForumFallback(item.name, colorScheme);
                              },
                            )
                          : _buildForumFallback(item.name, colorScheme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${item.name}吧",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.time > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            "最近经过：${_formatTime(item.time)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: colorScheme.outline.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/utils/haptic_feedback_util.dart";
import "../../../core/utils/spring_page_route.dart";
import "../../../core/widgets/app_avatar.dart";
import "../../feed/presentation/widgets/tieba_card.dart";
import "../../forum/presentation/forum_view.dart";
import "../../profile/presentation/user_profile_page.dart";
import "../data/models/tieba_search_model.dart";
import "search_controller.dart";

class SearchView extends ConsumerStatefulWidget {
  final String? forumName;

  const SearchView({super.key, this.forumName});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  TabController? _tabController;

  bool get _isForumSearch =>
      widget.forumName != null && widget.forumName!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_isForumSearch) {
      _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _onSearch({int? sortMode, int? onlyThread}) {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      HapticFeedbackUtil.light();
      ref.read(searchControllerProvider.notifier).search(
            keyword: text,
            sortMode: sortMode,
            onlyThread: onlyThread,
            forumName: widget.forumName,
          );
    }
  }

  void _showPostSortBottomSheet() {
    HapticFeedbackUtil.selection();
    final searchState = ref.read(searchControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "搜帖排序方式",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSortOption(
                  title: "新贴在前",
                  subtitle: "按发帖与最新回复时间倒序排列",
                  isSelected: searchState.sortMode == 1,
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(searchControllerProvider.notifier)
                        .changePostSort(1);
                  },
                ),
                _buildSortOption(
                  title: "旧贴在前",
                  subtitle: "按发帖时间正序排列",
                  isSelected: searchState.sortMode == 2,
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(searchControllerProvider.notifier)
                        .changePostSort(2);
                  },
                ),
                _buildSortOption(
                  title: "相关度",
                  subtitle: "按贴子与搜索关键词的相关程度综合排序",
                  isSelected: searchState.sortMode == 0,
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(searchControllerProvider.notifier)
                        .changePostSort(0);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colorScheme.outline),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedbackUtil.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color:
                selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final searchState = ref.watch(searchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _onSearch(),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: _isForumSearch
                ? "在 ${widget.forumName} 吧内搜索..."
                : "搜索吧、贴子或吧友...",
            hintStyle: TextStyle(fontSize: 14, color: colorScheme.outline),
            border: InputBorder.none,
            prefixIcon: _isForumSearch
                ? Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forum_outlined,
                            size: 14, color: colorScheme.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          widget.forumName!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: "搜索",
            onPressed: () => _onSearch(),
          ),
        ],
        bottom: _isForumSearch
            ? null
            : TabBar(
                controller: _tabController,
                onTap: (index) {
                  // 如果已经在“搜帖”（索引1）再次点击，弹出排序选项选择
                  if (index == 1 && _tabController?.previousIndex == 1) {
                    _showPostSortBottomSheet();
                  }
                },
                tabs: const [
                  Tab(text: "搜吧"),
                  Tab(text: "搜帖"),
                  Tab(text: "搜人"),
                ],
              ),
      ),
      body: _isForumSearch
          ? _buildForumSearchBody(searchState, colorScheme, theme)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSearchForumTab(searchState, colorScheme),
                _buildSearchPostTab(searchState, colorScheme),
                _buildSearchUserTab(searchState, colorScheme),
              ],
            ),
    );
  }

  /// 吧内专属贴子搜索视图
  Widget _buildForumSearchBody(
    SearchState searchState,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterPill(
                    label: "相关性",
                    selected: searchState.sortMode == 0,
                    onTap: () {
                      if (searchState.sortMode != 0) {
                        _onSearch(sortMode: 0);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: "时间倒序",
                    selected: searchState.sortMode == 1,
                    onTap: () {
                      if (searchState.sortMode != 1) {
                        _onSearch(sortMode: 1);
                      }
                    },
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterPill(
                    label: "全部",
                    selected: searchState.onlyThread == 0,
                    onTap: () {
                      if (searchState.onlyThread != 0) {
                        _onSearch(onlyThread: 0);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: "只看主题贴",
                    selected: searchState.onlyThread == 1,
                    onTap: () {
                      if (searchState.onlyThread != 1) {
                        _onSearch(onlyThread: 1);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: searchState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : searchState.results.isEmpty
                  ? Center(
                      child: Text(
                        searchState.keyword.isEmpty
                            ? "输入关键字在 ${widget.forumName} 吧内搜索"
                            : "未找到相关贴子",
                        style: TextStyle(
                            color: colorScheme.outline, fontSize: 13.5),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: searchState.results.length,
                      itemBuilder: (context, index) {
                        final item = searchState.results[index];
                        return TiebaCard(thread: item.toThreadModel());
                      },
                    ),
        ),
      ],
    );
  }

  /// 全局搜索 - 搜吧 Tab
  Widget _buildSearchForumTab(SearchState searchState, ColorScheme colorScheme) {
    if (searchState.isLoadingForums) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchState.keyword.isEmpty) {
      return Center(
        child: Text(
          "输入关键字搜索贴吧",
          style: TextStyle(color: colorScheme.outline, fontSize: 13.5),
        ),
      );
    }
    if (searchState.forumResult.isEmpty) {
      return Center(
        child: Text(
          "未找到相关贴吧",
          style: TextStyle(color: colorScheme.outline, fontSize: 13.5),
        ),
      );
    }

    final exact = searchState.forumResult.exactMatch;
    final fuzzy = searchState.forumResult.fuzzyMatch;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      children: [
        if (exact != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.verified_rounded,
                    size: 15, color: colorScheme.primary),
                const SizedBox(width: 5),
                Text(
                  "推荐贴吧",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          _buildForumCard(exact, colorScheme, isFeatured: true),
          const SizedBox(height: 16),
        ],
        if (fuzzy.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "相关贴吧",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...fuzzy.map((f) => _buildForumCard(f, colorScheme)),
        ],
      ],
    );
  }

  Widget _buildForumCard(SearchForumItem item, ColorScheme colorScheme,
      {bool isFeatured = false}) {
    return Card(
      elevation: isFeatured ? 1.5 : 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      color: isFeatured
          ? colorScheme.primaryContainer.withValues(alpha: 0.25)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isFeatured
            ? BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedbackUtil.light();
          Navigator.push(
            context,
            SpringPageRoute(page: ForumView(forumName: item.forumName)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppAvatar(
                url: item.avatar,
                size: isFeatured ? 52 : 44,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "${item.forumName}吧",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFeatured) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "精准匹配",
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.slogan.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.slogan,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      "关注 ${item.concernNum}  •  帖子 ${item.postNum}",
                      style:
                          TextStyle(fontSize: 11.5, color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: colorScheme.outline.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  /// 全局搜索 - 搜帖 Tab
  Widget _buildSearchPostTab(SearchState searchState, ColorScheme colorScheme) {
    return Column(
      children: [
        // 顶部排序切换条：新贴在前 / 旧贴在前 / 相关度
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                "排序：",
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              _buildFilterPill(
                label: "新贴在前",
                selected: searchState.sortMode == 1,
                onTap: () {
                  ref.read(searchControllerProvider.notifier).changePostSort(1);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: "旧贴在前",
                selected: searchState.sortMode == 2,
                onTap: () {
                  ref.read(searchControllerProvider.notifier).changePostSort(2);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: "相关度",
                selected: searchState.sortMode == 0,
                onTap: () {
                  ref.read(searchControllerProvider.notifier).changePostSort(0);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: searchState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : searchState.keyword.isEmpty
                  ? Center(
                      child: Text(
                        "输入关键字搜索贴子",
                        style: TextStyle(
                            color: colorScheme.outline, fontSize: 13.5),
                      ),
                    )
                  : searchState.results.isEmpty
                      ? Center(
                          child: Text(
                            "未找到相关贴子",
                            style: TextStyle(
                                color: colorScheme.outline, fontSize: 13.5),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: searchState.results.length,
                          itemBuilder: (context, index) {
                            final item = searchState.results[index];
                            return TiebaCard(thread: item.toThreadModel());
                          },
                        ),
        ),
      ],
    );
  }

  /// 全局搜索 - 搜人 Tab
  Widget _buildSearchUserTab(SearchState searchState, ColorScheme colorScheme) {
    if (searchState.isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchState.keyword.isEmpty) {
      return Center(
        child: Text(
          "输入关键字搜索吧友",
          style: TextStyle(color: colorScheme.outline, fontSize: 13.5),
        ),
      );
    }
    if (searchState.userResult.isEmpty) {
      return Center(
        child: Text(
          "未找到相关用户",
          style: TextStyle(color: colorScheme.outline, fontSize: 13.5),
        ),
      );
    }

    final exact = searchState.userResult.exactMatch;
    final fuzzy = searchState.userResult.fuzzyMatch;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      children: [
        if (exact != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.verified_rounded,
                    size: 15, color: colorScheme.primary),
                const SizedBox(width: 5),
                Text(
                  "推荐用户",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          _buildUserCard(exact, colorScheme, isFeatured: true),
          const SizedBox(height: 16),
        ],
        if (fuzzy.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "相关用户",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...fuzzy.map((u) => _buildUserCard(u, colorScheme)),
        ],
      ],
    );
  }

  Widget _buildUserCard(SearchUserItem item, ColorScheme colorScheme,
      {bool isFeatured = false}) {
    return Card(
      elevation: isFeatured ? 1.5 : 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      color: isFeatured
          ? colorScheme.primaryContainer.withValues(alpha: 0.25)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isFeatured
            ? BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedbackUtil.light();
          Navigator.push(
            context,
            SpringPageRoute(
              page: UserProfilePage(user: item.toAuthorModel()),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppAvatar(
                portrait: item.portrait.startsWith("tb.1.") ? item.portrait : null,
                url: item.portrait.startsWith("http") ? item.portrait : null,
                size: isFeatured ? 52 : 44,
                radius: isFeatured ? 26 : 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFeatured) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "精准匹配",
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.name.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        "贴吧账号：${item.name}",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (item.intro.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.intro,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      "粉丝 ${item.fansNum}",
                      style:
                          TextStyle(fontSize: 11.5, color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: colorScheme.outline.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/services/link_routing_service.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../auth/presentation/login_page.dart';
import '../../search/presentation/search_view.dart';
import '../data/models/hot_topic_model.dart';
import 'feed_controller.dart';
import 'widgets/tieba_card.dart';

class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Default to '推荐' tab (index 1)
    _tabController = TabController(length: 3, initialIndex: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '动态',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.push(context, SpringPageRoute(page: const SearchView()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: '关注'),
            Tab(text: '推荐'),
            Tab(text: '热榜'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FollowFeedTab(),
          _RecommendFeedTab(),
          _HotTopicTab(),
        ],
      ),
    );
  }
}

/// 关注分栏
class _FollowFeedTab extends ConsumerStatefulWidget {
  const _FollowFeedTab();

  @override
  ConsumerState<_FollowFeedTab> createState() => _FollowFeedTabState();
}

class _FollowFeedTabState extends ConsumerState<_FollowFeedTab> with AutomaticKeepAliveClientMixin {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authStateProvider);
    final followState = ref.watch(followFeedControllerProvider);

    if (authState.activeAccount == null || !authState.activeAccount!.isLogin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline_rounded, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              const Text(
                '登录后查看关注的人动态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '登录百度贴吧账号，随时掌握关注好友的最新发布',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('立即登录'),
                onPressed: () {
                  Navigator.push(context, SpringPageRoute(page: const LoginPage()));
                },
              ),
            ],
          ),
        ),
      );
    }

    return EasyRefresh(
      controller: _refreshController,
      onRefresh: () async {
        await ref.read(followFeedControllerProvider.notifier).refresh();
        _refreshController.finishRefresh();
      },
      onLoad: () async {
        await ref.read(followFeedControllerProvider.notifier).loadMore();
        _refreshController.finishLoad(
          followState.hasMore ? IndicatorResult.success : IndicatorResult.noMore,
        );
      },
      child: CustomScrollView(
        slivers: [
          if (followState.errorMessage != null && followState.threads.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 48, color: colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(followState.errorMessage!, style: TextStyle(color: colorScheme.outline)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => _refreshController.callRefresh(),
                      child: const Text('刷新'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final thread = followState.threads[index];
                    return TiebaCard(thread: thread);
                  },
                  childCount: followState.threads.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 推荐分栏
class _RecommendFeedTab extends ConsumerStatefulWidget {
  const _RecommendFeedTab();

  @override
  ConsumerState<_RecommendFeedTab> createState() => _RecommendFeedTabState();
}

class _RecommendFeedTabState extends ConsumerState<_RecommendFeedTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final scrollNotifier = ref.read(timelineScrollProvider.notifier);
    scrollNotifier.animateToCallback = (offset) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    };
    scrollNotifier.refreshCallback = () {
      _refreshController.callRefresh();
    };
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      ref.read(timelineScrollProvider.notifier).updateOffset(_scrollController.offset);

      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.65) {
        ref.read(feedControllerProvider.notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final feedState = ref.watch(feedControllerProvider);

    return EasyRefresh(
      controller: _refreshController,
      onRefresh: () async {
        await ref.read(feedControllerProvider.notifier).refresh();
        _refreshController.finishRefresh();
      },
      onLoad: () async {
        await ref.read(feedControllerProvider.notifier).loadMore();
        _refreshController.finishLoad(
          feedState.hasMore ? IndicatorResult.success : IndicatorResult.noMore,
        );
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          if (feedState.errorMessage != null && feedState.threads.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
                    const SizedBox(height: 12),
                    Text(feedState.errorMessage!, style: TextStyle(color: colorScheme.outline)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => _refreshController.callRefresh(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final thread = feedState.threads[index];
                    return TiebaCard(thread: thread);
                  },
                  childCount: feedState.threads.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 热榜分栏
class _HotTopicTab extends ConsumerStatefulWidget {
  const _HotTopicTab();

  @override
  ConsumerState<_HotTopicTab> createState() => _HotTopicTabState();
}

class _HotTopicTabState extends ConsumerState<_HotTopicTab> with AutomaticKeepAliveClientMixin {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hotState = ref.watch(hotTopicControllerProvider);

    return EasyRefresh(
      controller: _refreshController,
      onRefresh: () async {
        await ref.read(hotTopicControllerProvider.notifier).refresh();
        _refreshController.finishRefresh();
      },
      child: CustomScrollView(
        slivers: [
          if (hotState.errorMessage != null && hotState.topics.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
                    const SizedBox(height: 12),
                    Text(hotState.errorMessage!, style: TextStyle(color: colorScheme.outline)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => _refreshController.callRefresh(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final topic = hotState.topics[index];
                    return _HotTopicItem(topic: topic, rank: index + 1);
                  },
                  childCount: hotState.topics.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 热榜单项卡片
class _HotTopicItem extends StatelessWidget {
  final TiebaHotTopicModel topic;
  final int rank;

  const _HotTopicItem({required this.topic, required this.rank});

  Color _getRankColor(ColorScheme colorScheme) {
    switch (rank) {
      case 1:
        return const Color(0xFFE53935);
      case 2:
        return const Color(0xFFFF6D00);
      case 3:
        return const Color(0xFFFBC02D);
      default:
        return colorScheme.outline.withValues(alpha: 0.65);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rankColor = _getRankColor(colorScheme);
    final hasImage = topic.topicPic.isNotEmpty || topic.topicAvatar.isNotEmpty;
    final imageUrl = topic.topicPic.isNotEmpty ? topic.topicPic : topic.topicAvatar;

    return InkWell(
      onTap: () {
        HapticFeedbackUtil.light();
        if (topic.topicUrl.isNotEmpty) {
          LinkRoutingService.openUrl(context, topic.topicUrl);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 排名序号
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: rankColor,
                  fontStyle: rank <= 3 ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 标题与摘要与热度
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.topicName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topic.topicDesc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      topic.topicDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.outline,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 15,
                        color: Colors.deepOrangeAccent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        topic.formattedDiscussNum,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 配图
            if (hasImage) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 76,
                  height: 56,
                  child: AppNetworkImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


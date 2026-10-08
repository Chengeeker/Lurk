import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../feed/presentation/feed_view.dart';
import '../../my_forums/presentation/my_forums_view.dart';
import '../../notification/presentation/notification_view.dart';
import '../../profile/presentation/profile_view.dart';
import '../../settings/presentation/providers/habit_settings_provider.dart';

final mainScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  DateTime? _lastTimelineTapTime;
  Timer? _timelineSingleTapTimer;
  late final AnimationController _tabTransitionController;
  late final CurvedAnimation _tabTransitionCurve;
  late Animation<Offset> _tabIncomingTransition;
  late Animation<Offset> _tabOutgoingTransition;
  int _previousIndex = 1;
  bool _isTabTransitioning = false;

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _tabTransitionCurve = CurvedAnimation(
      parent: _tabTransitionController,
      curve: Curves.easeOutCubic,
    );
    _tabIncomingTransition = const AlwaysStoppedAnimation(Offset.zero);
    _tabOutgoingTransition = const AlwaysStoppedAnimation(Offset.zero);
    final habitState = ref.read(habitSettingsProvider);
    _currentIndex = (habitState.initialTabIndex >= 0 && habitState.initialTabIndex < 4)
        ? habitState.initialTabIndex
        : 1;
    _previousIndex = _currentIndex;
    _tabTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isTabTransitioning && mounted) {
        setState(() => _isTabTransitioning = false);
      }
    });
  }

  @override
  void dispose() {
    _timelineSingleTapTimer?.cancel();
    _tabTransitionCurve.dispose();
    _tabTransitionController.dispose();
    super.dispose();
  }

  final List<Widget> _pages = const [
    MyForumsView(),
    FeedView(),
    NotificationView(),
    ProfileView(),
  ];

  void _onNavigationItemSelected(int index) {
    HapticFeedbackUtil.light();
    if (index != _currentIndex) {
      _timelineSingleTapTimer?.cancel();
      _lastTimelineTapTime = null;
      if (MediaQuery.disableAnimationsOf(context)) {
        _tabTransitionController.stop();
        setState(() {
          _previousIndex = index;
          _currentIndex = index;
          _isTabTransitioning = false;
          _tabIncomingTransition = const AlwaysStoppedAnimation(Offset.zero);
          _tabOutgoingTransition = const AlwaysStoppedAnimation(Offset.zero);
        });
        _tabTransitionController.value = 1;
        return;
      }

      final currentOffset = _isTabTransitioning
          ? _tabIncomingTransition.value
          : Offset.zero;
      var direction = index > _currentIndex ? 1.0 : -1.0;
      if (Directionality.of(context) == TextDirection.rtl) direction *= -1;
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
        _isTabTransitioning = true;
        _tabIncomingTransition = Tween<Offset>(
          begin: Offset(direction, 0),
          end: Offset.zero,
        ).animate(_tabTransitionCurve);
        _tabOutgoingTransition = Tween<Offset>(
          begin: currentOffset,
          end: Offset(-direction, 0),
        ).animate(_tabTransitionCurve);
      });
      _tabTransitionController.forward(from: 0);
      return;
    }

    if (index == 1) {
      final now = DateTime.now();
      if (_lastTimelineTapTime != null &&
          now.difference(_lastTimelineTapTime!) < const Duration(milliseconds: 300)) {
        _timelineSingleTapTimer?.cancel();
        _timelineSingleTapTimer = null;
        _lastTimelineTapTime = null;
        ref.read(timelineScrollProvider.notifier).handleDoubleTap();
      } else {
        _lastTimelineTapTime = now;
        _timelineSingleTapTimer?.cancel();
        _timelineSingleTapTimer = Timer(const Duration(milliseconds: 300), () {
          ref.read(timelineScrollProvider.notifier).handleSingleTap();
          _lastTimelineTapTime = null;
        });
      }
    }
  }

  Widget _buildTabContent() {
    final pageOrder = List<int>.generate(_pages.length, (index) => index)
      ..sort((a, b) => _tabPageLayer(a).compareTo(_tabPageLayer(b)));

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final index in pageOrder)
          Positioned.fill(
            key: ValueKey(index),
            child: Offstage(
              offstage: index != _currentIndex &&
                  (!_isTabTransitioning || index != _previousIndex),
              child: TickerMode(
                enabled: index == _currentIndex ||
                    (_isTabTransitioning && index == _previousIndex),
                child: IgnorePointer(
                  ignoring: index != _currentIndex,
                  child: SlideTransition(
                    position: index == _currentIndex
                        ? _tabIncomingTransition
                        : index == _previousIndex && _isTabTransitioning
                        ? _tabOutgoingTransition
                        : const AlwaysStoppedAnimation(Offset.zero),
                    child: _pages[index],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _tabPageLayer(int index) {
    if (_isTabTransitioning && index == _previousIndex) return 1;
    if (index == _currentIndex) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final useFloating = themeState.useFloatingNavBar;
    final scaffoldKey = ref.watch(mainScaffoldKeyProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final standardNavBar = NavigationBar(
      selectedIndex: _currentIndex,
      elevation: 0,
      height: 80,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      indicatorColor: isDark ? colorScheme.secondaryContainer : colorScheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: _onNavigationItemSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum_rounded),
          label: '进吧',
        ),
        NavigationDestination(
          icon: Icon(Icons.dynamic_feed_outlined),
          selectedIcon: Icon(Icons.dynamic_feed_rounded),
          label: '动态',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: '消息',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: '我的',
        ),
      ],
    );

    final floatingCapsuleBar = Container(
      width: 320,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222328) : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCapsuleItem(
            index: 0,
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
            label: '进吧',
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          _buildCapsuleItem(
            index: 1,
            icon: Icons.dynamic_feed_outlined,
            selectedIcon: Icons.dynamic_feed_rounded,
            label: '动态',
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          _buildCapsuleItem(
            index: 2,
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            label: '消息',
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          _buildCapsuleItem(
            index: 3,
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: '我的',
            isDark: isDark,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );

    return Scaffold(
      key: scaffoldKey,
      body: Stack(
        children: [
          _buildTabContent(),
          if (useFloating)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding > 0 ? bottomPadding + 8 : 16,
              child: Center(child: floatingCapsuleBar),
            ),
        ],
      ),
      bottomNavigationBar: useFloating ? null : standardNavBar,
    );
  }

  Widget _buildCapsuleItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _currentIndex == index;
    final activeBgColor = isDark ? colorScheme.secondaryContainer : colorScheme.primaryContainer;
    final activeTextColor = isDark ? colorScheme.onSecondaryContainer : colorScheme.onPrimaryContainer;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onNavigationItemSelected(index),
        child: Container(
          height: 56,
          decoration: isSelected
              ? BoxDecoration(
                  color: activeBgColor,
                  borderRadius: BorderRadius.circular(28),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 22,
                color: isSelected ? activeTextColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeTextColor : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

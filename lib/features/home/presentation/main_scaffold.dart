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

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 1;
  DateTime? _lastTimelineTapTime;
  Timer? _timelineSingleTapTimer;

  @override
  void initState() {
    super.initState();
    final habitState = ref.read(habitSettingsProvider);
    _currentIndex = (habitState.initialTabIndex >= 0 && habitState.initialTabIndex < 4)
        ? habitState.initialTabIndex
        : 1;
  }

  @override
  void dispose() {
    _timelineSingleTapTimer?.cancel();
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
      setState(() => _currentIndex = index);
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
      height: 65,
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
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
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

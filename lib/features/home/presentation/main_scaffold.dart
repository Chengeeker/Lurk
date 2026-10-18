import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart' show kTouchSlop, VelocityTracker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../feed/presentation/feed_view.dart';
import '../../my_forums/presentation/my_forums_view.dart';
import '../../notification/presentation/notification_view.dart';
import '../../profile/presentation/profile_view.dart';
import '../../settings/presentation/providers/habit_settings_provider.dart';

const _mainNavigationDestinations = <_MainNavigationDestination>[
  _MainNavigationDestination(
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum_rounded,
    label: '进吧',
  ),
  _MainNavigationDestination(
    icon: Icons.dynamic_feed_outlined,
    selectedIcon: Icons.dynamic_feed_rounded,
    label: '动态',
  ),
  _MainNavigationDestination(
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications_rounded,
    label: '消息',
  ),
  _MainNavigationDestination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: '我的',
  ),
];

double _floatingNavigationBarWidth(BuildContext context) =>
    math.min(440.0, MediaQuery.sizeOf(context).width - 40.0).toDouble() * 8 / 9;

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
    final useLiquidGlassNavigation = useFloating && themeState.useLiquidGlass;
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
      destinations: [
        for (final destination in _mainNavigationDestinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );

    final floatingCapsuleBar = Container(
      width: _floatingNavigationBarWidth(context),
      height: 56,
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
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(
                -1 +
                    2 * _currentIndex /
                        (_mainNavigationDestinations.length - 1),
                0,
              ),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / _mainNavigationDestinations.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var index = 0;
                  index < _mainNavigationDestinations.length;
                  index++)
                _buildCapsuleItem(
                  index: index,
                  destination: _mainNavigationDestinations[index],
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ],
      ),
    );

    final scaffold = Scaffold(
      key: scaffoldKey,
      extendBody: useLiquidGlassNavigation,
      body: Stack(
        children: [
          GlassBackgroundSource(
            enabled: useLiquidGlassNavigation,
            child: _buildTabContent(),
          ),
          if (useFloating && !useLiquidGlassNavigation)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding > 0 ? bottomPadding + 8 : 16,
              child: Center(child: floatingCapsuleBar),
            ),
        ],
      ),
      bottomNavigationBar: !useFloating
          ? standardNavBar
          : useLiquidGlassNavigation
          ? _LiquidGlassNavigationBar(
              selectedIndex: _currentIndex,
              onSelected: _onNavigationItemSelected,
            )
          : null,
    );

    if (!useLiquidGlassNavigation) return scaffold;
    return GlassAdaptiveScope(
      child: GlassPage(enableBackgroundSampling: true, child: scaffold),
    );
  }

  Widget _buildCapsuleItem({
    required int index,
    required _MainNavigationDestination destination,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _currentIndex == index;
    final activeTextColor = isDark ? colorScheme.onSecondaryContainer : colorScheme.onPrimaryContainer;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onNavigationItemSelected(index),
        child: Container(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: isSelected ? activeTextColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
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

class _MainNavigationDestination {
  const _MainNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _LiquidGlassNavigationBar extends StatefulWidget {
  const _LiquidGlassNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_LiquidGlassNavigationBar> createState() =>
      _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<_LiquidGlassNavigationBar> {
  static const _longPressThreshold = Duration(milliseconds: 500);
  static const _flickVelocityThreshold = 1000.0;

  int? _activePointer;
  VelocityTracker? _velocityTracker;
  Duration? _pointerDownAt;
  Offset? _pointerDownPosition;
  int _selectedIndexAtPointerDown = 0;
  int? _pendingIndex;
  bool _movedBeyondSlop = false;
  bool _draggedHorizontally = false;
  bool _cancelled = false;
  int _gestureId = 0;

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _pointerDownAt = event.timeStamp;
    _pointerDownPosition = event.position;
    _selectedIndexAtPointerDown = widget.selectedIndex;
    _pendingIndex = null;
    _movedBeyondSlop = false;
    _draggedHorizontally = false;
    _cancelled = false;
    _gestureId++;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final delta = event.position - _pointerDownPosition!;
    if (delta.distance > kTouchSlop) {
      _movedBeyondSlop = true;
      if (delta.dx.abs() > delta.dy.abs()) _draggedHorizontally = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) => _finishPointer(
    event.pointer,
    event.timeStamp,
    horizontalVelocity: _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0,
  );

  void _onPointerCancel(PointerCancelEvent event) =>
      _finishPointer(event.pointer, event.timeStamp, cancelled: true);

  void _finishPointer(
    int pointer,
    Duration releasedAt, {
    bool cancelled = false,
    double horizontalVelocity = 0,
  }) {
    if (pointer != _activePointer) return;
    _cancelled |= cancelled;
    final gestureId = _gestureId;
    scheduleMicrotask(() {
      if (!mounted || gestureId != _gestureId) return;

      final target = _pendingIndex;
      final wasLongPress = releasedAt - _pointerDownAt! >= _longPressThreshold;
      final wasDrag = _draggedHorizontally;
      final movedVertically = _movedBeyondSlop && !wasDrag;
      final wasCancelled = _cancelled;
      final startingIndex = _selectedIndexAtPointerDown;

      _activePointer = null;
      _velocityTracker = null;
      _pointerDownAt = null;
      _pointerDownPosition = null;
      _pendingIndex = null;
      _movedBeyondSlop = false;
      _draggedHorizontally = false;
      _cancelled = false;

      if (wasCancelled || movedVertically || target == null) return;
      final isFastFlick =
          wasDrag && horizontalVelocity.abs() >= _flickVelocityThreshold;
      final selectedTarget = isFastFlick
          ? target.clamp(startingIndex - 1, startingIndex + 1).toInt()
          : target;
      if ((wasDrag || wasLongPress) && selectedTarget == startingIndex) return;
      widget.onSelected(selectedTarget);
    });
  }

  void _onTabSelected(int index) {
    if (_activePointer != null) {
      _pendingIndex = index;
    } else {
      widget.onSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.only(bottom: 21),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: _floatingNavigationBarWidth(context),
        height: 56,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GlassTabBar.bottom(
            tabs: [
              for (final destination in _mainNavigationDestinations)
                GlassTab(
                  icon: Icon(destination.icon),
                  activeIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
            selectedIndex: widget.selectedIndex,
            onTabSelected: _onTabSelected,
            barHeight: 56,
            horizontalPadding: 0,
            verticalPadding: 0,
            barBorderRadius: 9999,
            indicatorBorderRadius: 9999,
            settings: const LiquidGlassSettings(
              glassColor: Color(0x66000000),
              bodyMode: GlassBodyMode.clear,
              thickness: 10,
              blur: 2.0,
              lightIntensity: 0.25,
              ambientStrength: 0,
              refractiveIndex: 1.19,
              chromaticAberration: 0.008,
              shadowElevation: 0,
            ),
            indicatorSettings: const LiquidGlassSettings(
              refractiveIndex: 1.18,
              chromaticAberration: 0.025,
            ),
            quality: GlassQuality.premium,
            backgroundQuality: GlassQuality.premium,
            indicatorColor: const Color(0x66000000),
            interactionGlowColor: const Color(0x20FFFFFF),
            indicatorPinchStrength: 0.7,
            innerBlur: 6,
            pressScale: 1.06,
            selectedIconColor: Colors.white,
            selectedLabelColor: Colors.white,
            unselectedIconColor: Colors.white,
            unselectedLabelColor: Colors.white,
          ),
        ),
      ),
    ),
  );
}

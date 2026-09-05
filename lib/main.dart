import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/display_mode_service.dart';
import 'core/services/link_routing_service.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/app_toast.dart';
import 'features/home/presentation/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  await DisplayModeService.init(storage);

  EasyRefresh.defaultHeaderBuilder = () => const ClassicHeader(
    dragText: '下拉刷新',
    armedText: '释放即可刷新',
    readyText: '正在刷新...',
    processingText: '正在刷新...',
    processedText: '刷新成功',
    noMoreText: '没有更多了',
    failedText: '刷新失败',
    messageText: '最后更新于 %T',
    showMessage: true,
  );

  EasyRefresh.defaultFooterBuilder = () => const ClassicFooter(
    dragText: '上拉加载',
    armedText: '释放加载更多',
    readyText: '正在加载...',
    processingText: '正在加载...',
    processedText: '加载完成',
    noMoreText: '没有更多内容了',
    failedText: '加载失败',
    messageText: '最后更新于 %T',
    showMessage: true,
  );

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const LurkApp(),
    ),
  );
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class LurkApp extends ConsumerStatefulWidget {
  const LurkApp({super.key});

  @override
  ConsumerState<LurkApp> createState() => _LurkAppState();
}

class _LurkAppState extends ConsumerState<LurkApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    LinkRoutingService.initDeepLinkListener(rootNavigatorKey);
    _lifecycleListener = AppLifecycleListener(
      onDetach: _handleAppExit,
      onHide: _handleAppExit,
      onPause: _handleAppExit,
    );
  }

  void _handleAppExit() {
    final storage = ref.read(storageServiceProvider);
    if (storage.getAutoClearCacheOnExit()) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      unawaited(clearDiskCachedImages());
      clearMemoryImageCache();
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme? lightScheme;
        ColorScheme? darkScheme;

        if (themeState.useDynamicColor) {
          lightScheme = lightDynamic;
          darkScheme = darkDynamic;
        }

        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: AppToast.scaffoldMessengerKey,
          title: 'Lurk',
          debugShowCheckedModeBanner: false,
          themeMode: themeState.themeMode,
          theme: AppTheme.lightTheme(
            dynamicColorScheme: lightScheme,
            colorIndex: themeState.themeColorIndex,
            fontWeightIndex: themeState.fontWeightIndex,
          ),
          darkTheme: AppTheme.darkTheme(
            dynamicColorScheme: darkScheme,
            colorIndex: themeState.themeColorIndex,
            isPureBlack: themeState.isPureBlackDark,
            fontWeightIndex: themeState.fontWeightIndex,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          home: const MainScaffold(),
        );
      },
    );
  }
}

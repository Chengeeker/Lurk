import 'dart:io';

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lurk/core/auth/auth_provider.dart';
import 'package:lurk/core/storage/storage_service.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/feed/presentation/widgets/tieba_card.dart';
import 'package:lurk/features/profile/data/profile_repository.dart';
import 'package:lurk/features/profile/data/models/tieba_profile_model.dart';
import 'package:lurk/features/profile/presentation/user_profile_page.dart';
import 'package:lurk/features/profile/presentation/widgets/user_posts_view.dart';
import 'package:lurk/core/widgets/app_avatar.dart';
import 'package:lurk/features/search/data/models/tieba_search_model.dart';
import 'package:lurk/features/search/data/search_repository.dart';
import 'package:lurk/features/search/presentation/search_controller.dart';
import 'package:lurk/features/search/presentation/search_view.dart';
import 'package:lurk/core/theme/app_theme.dart';
import 'package:lurk/features/profile/presentation/profile_view.dart';
import 'package:lurk/features/settings/presentation/settings_view.dart';
import 'package:lurk/features/settings/presentation/personalization_settings_page.dart';
import 'package:lurk/features/settings/presentation/block_settings_page.dart';
import 'package:lurk/features/settings/presentation/habit_settings_page.dart';
import 'package:lurk/features/settings/presentation/display_mode_settings_page.dart';
import 'package:lurk/features/settings/presentation/cache_management_page.dart';
import 'package:lurk/features/settings/presentation/storage_settings_page.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Search extends SearchController {
  _Search() : super(_Repository()) {
    state = const SearchState(
      keyword: 'fixture',
      forumResult: SearchForumResultModel(
        exactMatch: SearchForumItem(forumId: '1', forumName: '精确'),
        fuzzyMatch: [SearchForumItem(forumId: '2', forumName: '相关')],
      ),
      userResult: SearchUserResultModel(
        exactMatch: SearchUserItem(id: '1', name: '精确用户'),
        fuzzyMatch: [SearchUserItem(id: '2', name: '匹配吧友')],
      ),
    );
  }
  @override
  void reset() {}
}

class _Profiles extends ProfileRepository {
  _Profiles() : super(TiebaDioClient());
  @override
  Future<TiebaProfileModel?> getProfile({required String uid}) async => null;
  @override
  Future<List<TiebaThreadModel>> getUserPosts({
    required String uid,
    required int page,
  }) async => const [
    TiebaThreadModel(
      id: 'thread',
      title: 'fixture',
      author: TiebaAuthorModel(id: 'user', name: '吧友'),
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const cache = MethodChannel('com.lurk/cache');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(paths, (_) async => Directory.systemTemp.path)
      ..setMockMethodCallHandler(cache, (_) async => <String, int>{});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(paths, null)
      ..setMockMethodCallHandler(cache, null);
  });
  for (final scenario in [
    (360.0, 1.0, TextDirection.ltr),
    (420.0, 1.4, TextDirection.ltr),
    (360.0, 1.0, TextDirection.rtl),
  ]) {
    testWidgets('section headings follow content column $scenario', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(scenario.$1, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      Future<void> mount(Widget page) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              authStateProvider.overrideWith((ref) => _Auth()),
              searchControllerProvider.overrideWith((ref) => _Search()),
              profileRepositoryProvider.overrideWithValue(_Profiles()),
            ],
            child: MaterialApp(
              theme: scenario.$3 == TextDirection.rtl
                  ? AppTheme.darkTheme(fontWeightIndex: 4)
                  : AppTheme.lightTheme(),
              builder: (context, child) => Directionality(
                textDirection: scenario.$3,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scenario.$2)),
                  child: child!,
                ),
              ),
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      void aligned(String title, Finder content) {
        final text = find.text(title);
        final heading = tester.getRect(
          title.startsWith('推荐')
              ? find.ancestor(of: text, matching: find.byType(Row)).first
              : text,
        );
        final item = tester.getRect(content);
        final a = scenario.$3 == TextDirection.ltr
            ? heading.left
            : heading.right;
        final b = scenario.$3 == TextDirection.ltr ? item.left : item.right;
        expect(a, closeTo(b, .1), reason: title);
      }

      TextStyle style(String label) =>
          tester.renderObject<RenderParagraph>(find.text(label)).text.style!;
      late TextStyle standard;
      void sameRowStyle(String label) {
        final actual = style(label);
        expect(
          (
            actual.fontFamily,
            actual.fontSize,
            actual.fontWeight,
            actual.letterSpacing,
            actual.height,
          ),
          (
            standard.fontFamily,
            standard.fontSize,
            standard.fontWeight,
            standard.letterSpacing,
            standard.height,
          ),
          reason: 'same function typography: $label',
        );
      }

      await mount(const SettingsView());
      standard = style('个性化');
      expect(standard.fontSize, 16);
      expect(
        standard.fontWeight,
        scenario.$3 == TextDirection.rtl ? FontWeight.w900 : FontWeight.w500,
      );
      aligned('偏好与功能', find.byIcon(Icons.palette_outlined));
      aligned('账号设置', find.byIcon(Icons.login_rounded));
      aligned('关于与支持', find.byIcon(Icons.info_outline_rounded));
      await mount(const PersonalizationSettingsPage());
      aligned('明暗模式', find.byType(Radio<ThemeMode>).first);
      for (final label in [
        '跟随系统',
        '浅色模式',
        '深色模式',
        '纯黑深色模式 (OLED 省电)',
        '自定义应用字体粗细',
      ]) {
        sameRowStyle(label);
      }
      aligned('色彩方案', find.byIcon(Icons.auto_awesome_outlined));
      aligned('字体粗细', find.byIcon(Icons.format_bold_rounded));
      await mount(const BlockSettingsPage());
      aligned('内容过滤与屏蔽', find.byIcon(Icons.filter_alt_outlined));
      sameRowStyle('屏蔽词管理');
      await mount(const HabitSettingsPage());
      aligned('启动与偏好', find.byIcon(Icons.home_outlined));
      sameRowStyle('启动首选页');
      aligned('浏览与交互偏好', find.byIcon(Icons.autorenew_rounded));
      await mount(const ProfileView());
      aligned('快捷功能', find.byIcon(Icons.bookmark_outline_rounded));
      await mount(const DisplayModeSettingsPage());
      aligned('没有生效？重启app试试', find.text('自动'));
      sameRowStyle('自动');
      await mount(const CacheManagementPage());
      aligned('自动清理规则', find.byIcon(Icons.auto_delete_outlined));
      sameRowStyle('自动清理缓存阈值');
      sameRowStyle('退出时自动清理缓存');
      aligned(
        '清理范围',
        find.byWidgetPredicate(
          (w) => w is Text && w.data?.startsWith('清理范围包括') == true,
        ),
      );
      await mount(const StorageSettingsPage());
      sameRowStyle('图片存储路径');
      sameRowStyle('视频存储路径');
      await mount(const SearchView());
      aligned('推荐贴吧', find.byType(AppAvatar).first);
      aligned('相关贴吧', find.byType(AppAvatar).last);
      await tester.tap(find.text('搜人'));
      await tester.pumpAndSettle();
      aligned('推荐用户', find.byType(AppAvatar).first);
      aligned('相关用户', find.byType(AppAvatar).last);
      for (final page in <Widget>[
        const UserProfilePage(
          user: TiebaAuthorModel(id: 'user', name: '吧友'),
        ),
        const UserPostsView(
          user: TiebaAuthorModel(id: 'user', name: '吧友'),
        ),
      ]) {
        await mount(page);
        aligned(
          'TA 的发帖与动态',
          find
              .descendant(
                of: find.byType(TiebaCard),
                matching: find.byType(AppAvatar),
              )
              .first,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

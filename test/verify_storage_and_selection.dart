// ignore_for_file: avoid_print
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:lurk/core/storage/storage_service.dart";
import "package:lurk/features/settings/presentation/storage_settings_page.dart";
import "package:lurk/features/settings/presentation/settings_view.dart";

void main() {
  test("StorageService correctly stores and retrieves storage settings", () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    expect(storage.getImageSavePathType(), 0);
    expect(storage.getVideoSavePathType(), 0);
    expect(storage.getAutoClearCacheOnExit(), false);

    await storage.setImageSavePathType(1);
    await storage.setVideoSavePathType(2);
    await storage.setAutoClearCacheOnExit(true);

    expect(storage.getImageSavePathType(), 1);
    expect(storage.getVideoSavePathType(), 2);
    expect(storage.getAutoClearCacheOnExit(), true);
  });

  testWidgets("StorageSettingsPage displays all required options", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: StorageSettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text("存储设置"), findsOneWidget);
    expect(find.text("图片存储路径"), findsOneWidget);
    expect(find.text("视频存储路径"), findsOneWidget);
    expect(find.text("退出时自动清理缓存"), findsOneWidget);
    expect(find.text("立即清理缓存"), findsOneWidget);
  });

  testWidgets("SettingsView contains 存储设置 and 关于 Lurk with AboutDialog", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: SettingsView(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text("存储设置"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("关于 Lurk"),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text("关于 Lurk"), findsOneWidget);

    // Tap 关于 Lurk to open dialog
    await tester.tap(find.text("关于 Lurk"));
    await tester.pumpAndSettle();

    expect(find.text("Lurk"), findsOneWidget);
    expect(find.text("纯原生 Material You 极简贴吧客户端"), findsOneWidget);
    expect(find.text("GitHub 开源地址"), findsOneWidget);
    expect(find.text("我知道了"), findsOneWidget);

    // Tap 我知道了 to dismiss
    await tester.tap(find.text("我知道了"));
    await tester.pumpAndSettle();
    expect(find.text("我知道了"), findsNothing);
  });
}

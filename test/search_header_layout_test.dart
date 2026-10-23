import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/widgets/lurk_frosted_app_bar.dart';
import 'package:lurk/features/search/data/search_repository.dart';
import 'package:lurk/features/search/presentation/search_controller.dart';
import 'package:lurk/features/search/presentation/search_view.dart';

class _Repository implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [360.0, 420.0]) {
    testWidgets('forum header layout and clear at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [searchControllerProvider.overrideWith((ref) => SearchController(_Repository()))],
        child: const MaterialApp(home: SearchView(forumName: '原神内容讨论')),
      ));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(LurkFrostedAppBar), matching: find.text('时间倒序')), findsOneWidget);
      await tester.enterText(find.byType(TextField), '测试搜索文字');
      await tester.pump();
      final field = tester.getRect(find.byType(TextField));
      final clear = tester.getRect(find.byTooltip('清除'));
      expect(field.width, greaterThanOrEqualTo(96));
      expect((field.center.dy - clear.center.dy).abs(), lessThan(2));
      expect(clear.left, greaterThanOrEqualTo(field.right));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('清除'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}


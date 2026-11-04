import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/theme/app_theme.dart';
import 'package:lurk/core/utils/haptic_feedback_util.dart';

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey boundaryKey) async {
  return (await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final mode in ['light', 'dark', 'oled']) {
    testWidgets(
      '$mode controls do not paint pressed ink and still handle input',
      (tester) async {
        final enabled = HapticFeedbackUtil.isEnabled;
        HapticFeedbackUtil.isEnabled = false;
        addTearDown(() => HapticFeedbackUtil.isEnabled = enabled);
        final theme = mode == 'light'
            ? AppTheme.lightTheme()
            : AppTheme.darkTheme(isPureBlack: mode == 'oled');
        var taps = 0, holds = 0;
        void tap() => taps++;
        void hold() => holds++;
        final boundary = GlobalKey();
        await tester.binding.setSurfaceSize(const Size(400, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: Material(
                  color: theme.colorScheme.surface,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: tap,
                        onLongPress: hold,
                        child: const SizedBox(
                          height: 48,
                          width: 320,
                          child: Center(child: Text('普通行')),
                        ),
                      ),
                      TextButton(
                        onPressed: tap,
                        onLongPress: hold,
                        child: const Text('文字按钮'),
                      ),
                      FilledButton(onPressed: tap, child: const Text('填充按钮')),
                      OutlinedButton(onPressed: tap, child: const Text('描边按钮')),
                      IconButton(
                        key: const ValueKey('icon'),
                        onPressed: tap,
                        icon: const Icon(Icons.add),
                      ),
                      ListTile(
                        title: const Text('列表项'),
                        onTap: tap,
                        onLongPress: hold,
                      ),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('分段一')),
                          ButtonSegment(value: 1, label: Text('分段二')),
                        ],
                        selected: const {0},
                        onSelectionChanged: (_) => tap(),
                      ),
                      Checkbox(
                        key: const ValueKey('check'),
                        value: false,
                        onChanged: (_) => tap(),
                      ),
                      NavigationBar(
                        onDestinationSelected: (_) => tap(),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.home),
                            label: '首页',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person),
                            label: '我的',
                          ),
                        ],
                      ),
                      DefaultTabController(
                        length: 2,
                        child: TabBar(
                          onTap: (_) => tap(),
                          tabs: const [
                            Tab(text: '页签一'),
                            Tab(text: '页签二'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final target in [
          find.text('普通行'),
          find.text('文字按钮'),
          find.text('填充按钮'),
          find.text('描边按钮'),
          find.byKey(const ValueKey('icon')),
          find.text('列表项'),
          find.text('分段二'),
          find.byKey(const ValueKey('check')),
          find.text('我的'),
          find.text('页签二'),
        ]) {
          final before = await _pixels(tester, boundary);
          final count = taps;
          final gesture = await tester.startGesture(tester.getCenter(target));
          await tester.pump(const Duration(milliseconds: 120));
          expect(
            listEquals(before, await _pixels(tester, boundary)),
            isTrue,
            reason:
                '$mode: $target should not paint a ripple or pressed overlay',
          );
          await gesture.up();
          await tester.pumpAndSettle();
          expect(taps, count + 1);
        }
        final before = await _pixels(tester, boundary);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('普通行')),
        );
        await tester.pump(const Duration(milliseconds: 650));
        expect(holds, 1);
        expect(
          listEquals(before, await _pixels(tester, boundary)),
          isTrue,
          reason: 'long press must not paint ink',
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 10);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('ordinary tap retains one haptic when enabled', (tester) async {
    final enabled = HapticFeedbackUtil.isEnabled;
    HapticFeedbackUtil.isEnabled = true;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      HapticFeedbackUtil.isEnabled = enabled;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: InkWell(
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 60, child: Text('点击')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('点击'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(calls.length, 1);
    expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
  });
}

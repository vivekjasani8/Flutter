import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/features/mine/mining_animation.dart';
import 'package:idle_miner_sim/state/haptics_controller.dart';
import 'package:idle_miner_sim/state/theme_mode_controller.dart';

import 'support/app_harness.dart';
import 'support/fixtures.dart';

const tabs = ['Mine', 'Shop', 'Rewards', 'Stats', 'Settings'];

/// A mid-game save: some rigs, a streak, an achievement, earnings history.
Map<String, Object> midGame() {
  final s = tick(
    stateWith(rigLevels: {'cpu': 5, 'gpu': 2}, coins: 450)
        .copyWith(lastClaimDay: dayKey(t0 - dayMs), streak: 3),
    t0 + 3 * hourMs,
  );
  return savedGame(s);
}

/// A small phone (360 x 780 dp) with the given font scale.
void useSmallPhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Scroll the current tab to the bottom so every item is built and laid out.
Future<void> scrollToEnd(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollables.first, const Offset(0, -600));
    await tester.pumpAndSettle();
  }
}

/// Records HapticFeedback calls sent to the platform.
List<String> recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock(t0 + 3 * hourMs));

  group('accessibility guidelines', () {
    for (final mode in ['light', 'dark']) {
      for (final tab in tabs) {
        testWidgets(
            '$tab ($mode) meets tap-target, label and contrast guidelines',
            (tester) async {
          final semantics = tester.ensureSemantics();
          useSmallPhone(tester);
          await pumpApp(tester, clock,
              saved: {...midGame(), ThemeModeController.key: mode});
          await openTab(tester, tab);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }
    }
  });

  group('appearance', () {
    ThemeMode appMode(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

    testWidgets('follows the phone by default', (tester) async {
      await pumpApp(tester, clock);
      expect(appMode(tester), ThemeMode.system);
    });

    testWidgets('Settings switch changes the theme and remembers it',
        (tester) async {
      final prefs = await pumpApp(tester, clock);
      await openTab(tester, 'Settings');

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(appMode(tester), ThemeMode.dark);
      expect(Theme.of(tester.element(find.text('Dark'))).brightness,
          Brightness.dark);
      expect(prefs.getString(ThemeModeController.key), 'dark');

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(appMode(tester), ThemeMode.light);
      expect(prefs.getString(ThemeModeController.key), 'light');
    });

    testWidgets('a saved choice is used on the next launch', (tester) async {
      await pumpApp(tester, clock, saved: {ThemeModeController.key: 'dark'});
      expect(appMode(tester), ThemeMode.dark);
    });
  });

  group('large text', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('every tab lays out at ${scale}x font on a small phone',
          (tester) async {
        useSmallPhone(tester, textScale: scale);
        await pumpApp(tester, clock, saved: midGame());
        for (final tab in tabs) {
          await openTab(tester, tab);
          await scrollToEnd(tester);
        }
        // Any RenderFlex overflow would have failed the test already.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dialogs fit at 2x font too', (tester) async {
      useSmallPhone(tester, textScale: 2);
      clock.advance(const Duration(hours: 12)); // long absence: capped dialog
      await pumpApp(tester, clock, saved: midGame());
      expect(find.text('While you were away'), findsOneWidget);
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();
      // The one-time reminder prompt follows.
      expect(find.text('Want a reminder?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('haptics', () {
    testWidgets('buying, claiming and unlocking give feedback', (tester) async {
      final calls = recordHaptics(tester);
      await pumpApp(tester, clock);
      await openTab(tester, 'Shop');
      calls.clear(); // ignore the tab switch

      await tester.tap(find.byKey(const ValueKey('buy-cpu')));
      await tester.pumpAndSettle();
      expect(calls, contains('HapticFeedbackType.lightImpact'));
      expect(calls, contains('HapticFeedbackType.heavyImpact'),
          reason: 'first rig unlocks "Booting Up"');

      await openTab(tester, 'Rewards');
      calls.clear();
      await tester.tap(find.byKey(const ValueKey('claim-daily')));
      await tester.pumpAndSettle();
      expect(calls, contains('HapticFeedbackType.mediumImpact'));
    });

    testWidgets('switching tabs clicks; the Settings switch silences all',
        (tester) async {
      final calls = recordHaptics(tester);
      final prefs = await pumpApp(tester, clock);
      await openTab(tester, 'Shop');
      expect(calls, ['HapticFeedbackType.selectionClick']);

      await openTab(tester, 'Settings');
      await tester.tap(find.byKey(const ValueKey('haptics-switch')));
      await tester.pumpAndSettle();
      expect(prefs.getBool(HapticsController.key), isFalse);

      calls.clear();
      await openTab(tester, 'Shop');
      await tester.tap(find.byKey(const ValueKey('buy-cpu')));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });
  });

  group('mining animation', () {
    double turns(WidgetTester tester) => tester
        .widget<RotationTransition>(
            find.byKey(const ValueKey('mining-spinner')))
        .turns
        .value;

    testWidgets('spins while rigs are mining', (tester) async {
      await pumpApp(tester, clock,
          saved: midGame(), animations: true, settle: false);
      final before = turns(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(turns(tester), isNot(before));
    });

    testWidgets('stays still with no rigs', (tester) async {
      await pumpApp(tester, clock, animations: true, settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(turns(tester), 0);
      expect(find.bySemanticsLabel('Rigs idle'), findsOneWidget);
    });

    testWidgets('stays still when the OS asks for no animations',
        (tester) async {
      await pumpApp(tester, clock, saved: midGame()); // animations off
      await tester.pump(const Duration(milliseconds: 300));
      expect(turns(tester), 0);
    });

    test('spins faster as hash rate grows, within sane limits', () {
      final speeds = [1.0, 10.0, 100.0, 1000.0, 1e6]
          .map(MiningAnimation.periodFor)
          .toList();
      for (var i = 1; i < speeds.length; i++) {
        expect(speeds[i], lessThan(speeds[i - 1]));
      }
      expect(
          MiningAnimation.periodFor(1e12), const Duration(milliseconds: 500));
      expect(MiningAnimation.periodFor(0), const Duration(seconds: 4));
    });
  });

  group('rolling balance', () {
    Future<void> show(WidgetTester tester, double value) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(body: RollingNumber(value: value)),
        ));

    testWidgets('rolls up smoothly to a higher value', (tester) async {
      await show(tester, 100);
      expect(find.text('100'), findsOneWidget);
      await show(tester, 200);
      await tester.pump(const Duration(milliseconds: 450));
      final mid = double.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(mid, inExclusiveRange(100, 200));
      await tester.pumpAndSettle();
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets('drops instantly when spending', (tester) async {
      await show(tester, 200);
      await show(tester, 50);
      expect(find.text('50'), findsOneWidget);
    });
  });
}

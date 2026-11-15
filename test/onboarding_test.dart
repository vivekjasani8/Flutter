import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/onboarding_controller.dart';

import 'support/app_harness.dart';
import 'support/fixtures.dart';

Finder get next => find.byKey(const ValueKey('onboarding-next'));
Finder get skip => find.byKey(const ValueKey('onboarding-skip'));
Finder get disclaimerPage =>
    find.byKey(const ValueKey('onboarding-disclaimer'));

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String buttonLabel(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: next, matching: find.byType(Text)))
    .data!;

void useSmallPhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock(t0));

  testWidgets('first launch shows the intro, not the game', (tester) async {
    await pumpApp(tester, clock, onboarded: false);
    expect(find.text('Build a virtual mining empire'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
  });

  testWidgets('Next walks through every page and ends on the disclaimer',
      (tester) async {
    final prefs = await pumpApp(tester, clock, onboarded: false);

    expect(buttonLabel(tester), 'Next');
    await tapAndSettle(tester, next);
    expect(find.text('Your rigs never sleep'), findsOneWidget);
    expect(find.textContaining('up to 8h'), findsOneWidget);

    await tapAndSettle(tester, next);
    expect(disclaimerPage, findsOneWidget);
    expect(find.textContaining(appDisclaimer), findsOneWidget);
    expect(skip, findsNothing, reason: 'nothing left to skip');
    expect(buttonLabel(tester), 'I understand, start mining');

    await tapAndSettle(tester, next);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('balance')), findsOneWidget);
    expect(prefs.getBool(OnboardingController.key), isTrue);
  });

  testWidgets('Skip jumps to the disclaimer instead of past it',
      (tester) async {
    await pumpApp(tester, clock, onboarded: false);
    await tapAndSettle(tester, skip);
    expect(disclaimerPage, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing,
        reason: 'the disclaimer must still be accepted');
  });

  testWidgets('swiping works too', (tester) async {
    await pumpApp(tester, clock, onboarded: false);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Your rigs never sleep'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
  });

  testWidgets('once finished, the intro never shows on launch again',
      (tester) async {
    await pumpApp(tester, clock,
        onboarded: false, saved: {OnboardingController.key: true});
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Build a virtual mining empire'), findsNothing);
  });

  testWidgets('a returning player sees "while you were away" after the intro',
      (tester) async {
    clock.advance(const Duration(hours: 2));
    await pumpApp(tester, clock,
        onboarded: false, saved: savedGame(stateWith(rigLevels: {'cpu': 1})));
    expect(find.text('While you were away'), findsNothing,
        reason: 'not on top of the intro');

    await tapAndSettle(tester, skip);
    await tapAndSettle(tester, next);
    expect(find.text('While you were away'), findsOneWidget);
    expect(find.text('+${formatNumber(cpuRate * 7200)} $coinName'),
        findsOneWidget);
  });

  testWidgets('Settings → How to play reopens it and returns to Settings',
      (tester) async {
    await pumpApp(tester, clock);
    await openTab(tester, 'Settings');
    await tapAndSettle(tester, find.byKey(const ValueKey('how-to-play')));
    expect(find.text('Build a virtual mining empire'), findsOneWidget);

    await tapAndSettle(tester, skip);
    await tapAndSettle(tester, next);
    expect(find.byKey(const ValueKey('how-to-play')), findsOneWidget,
        reason: 'back on Settings');
  });

  group('accessibility', () {
    for (var page = 0; page < 3; page++) {
      testWidgets('page ${page + 1} meets the guidelines', (tester) async {
        final semantics = tester.ensureSemantics();
        useSmallPhone(tester);
        await pumpApp(tester, clock, onboarded: false);
        for (var i = 0; i < page; i++) {
          await tapAndSettle(tester, next);
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }

    testWidgets('every page fits at 2x font on a small phone', (tester) async {
      useSmallPhone(tester, textScale: 2);
      await pumpApp(tester, clock, onboarded: false);
      for (var i = 0; i < 2; i++) {
        await tapAndSettle(tester, next);
      }
      // The long disclaimer page scrolls rather than overflowing.
      await tester.drag(disclaimerPage, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, next);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}

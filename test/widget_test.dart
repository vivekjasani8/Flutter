import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/app_harness.dart';
import 'support/fixtures.dart';

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock(t0));

  testWidgets('boots to Mine with the bottom navigation and disclaimer',
      (tester) async {
    await pumpApp(tester, clock);

    for (final tab in ['Mine', 'Shop', 'Rewards', 'Stats', 'Settings']) {
      expect(navTab(tab), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('balance')), findsOneWidget);
    expect(find.text(formatNumber(startingCoins)), findsOneWidget);
    expect(find.text('While you were away'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Go to Shop'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text(appDisclaimer),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('buying and upgrading rigs in the Shop', (tester) async {
    final prefs = await pumpApp(tester, clock,
        saved: savedGame(stateWith(
          coins: 500,
        )));
    await openTab(tester, 'Shop');

    Text level(String id) =>
        tester.widget<Text>(find.byKey(ValueKey('level-$id')));
    FilledButton buyButton(String id) =>
        tester.widget<FilledButton>(find.byKey(ValueKey('buy-$id')));

    expect(level('cpu').data, 'Lv 0');
    await tester.tap(find.byKey(const ValueKey('buy-cpu')));
    await tester.pump();
    expect(level('cpu').data, 'Lv 1');
    expect(liveGame(tester).coins, 450);

    // Second level: an upgrade at the higher price.
    expect(find.textContaining('Upgrade'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('buy-cpu')));
    await tester.pump();
    expect(level('cpu').data, 'Lv 2');
    expect(liveGame(tester).coins, 450 - rigCost('cpu', 1));
    expect(storedGame(prefs)!.rigs['cpu'], 2, reason: 'saved after buying');

    // Too expensive: the Quantum Farm button is disabled.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('buy-farm')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(buyButton('farm').onPressed, isNull);

    await openTab(tester, 'Mine');
    expect(find.text('CPU Rack'), findsOneWidget);
    expect(find.text('Lv 2'), findsOneWidget);
  });

  testWidgets('earnings tick every second and autosave', (tester) async {
    final prefs = await pumpApp(tester, clock,
        saved: savedGame(stateWith(
          rigLevels: {'cpu': 1},
        )));

    for (var i = 0; i < 10; i++) {
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(liveGame(tester).coins, closeTo(startingCoins + cpuRate * 10, 1e-9));
    expect(storedGame(prefs)!.lastTick, clock.now, reason: 'autosaved');
  });

  testWidgets('shows "While you were away" on launch after a long absence',
      (tester) async {
    clock.advance(const Duration(hours: 2)); // save is from t0
    await pumpApp(tester, clock,
        saved: savedGame(stateWith(
          rigLevels: {'cpu': 1},
        )));

    const earned = cpuRate * 7200;
    expect(find.text('While you were away'), findsOneWidget);
    expect(find.text('+${formatNumber(earned)} $coinName'), findsOneWidget);
    expect(find.textContaining('2h'), findsOneWidget);

    await tester.tap(find.text('Collect'));
    await tester.pumpAndSettle();
    expect(find.text('While you were away'), findsNothing);
    expect(liveGame(tester).coins, closeTo(startingCoins + earned, 1e-6));
  });

  testWidgets('the away dialog explains the 8 h cap', (tester) async {
    clock.advance(const Duration(hours: 12));
    await pumpApp(tester, clock,
        saved: savedGame(stateWith(
          rigLevels: {'cpu': 1},
        )));
    expect(find.textContaining('only store 8h'), findsOneWidget);
  });

  testWidgets('returning from the background shows what was earned',
      (tester) async {
    await pumpApp(tester, clock,
        saved: savedGame(stateWith(
          rigLevels: {'cpu': 1},
        )));
    expect(find.text('While you were away'), findsNothing);

    await backgroundFor(tester, clock, const Duration(hours: 3));
    expect(find.text('While you were away'), findsOneWidget);
    expect(
      find.text('+${formatNumber(cpuRate * 10800)} $coinName'),
      findsOneWidget,
    );
  });

  testWidgets('Stats shows the 24 h chart once there are earnings',
      (tester) async {
    await pumpApp(tester, clock);
    await openTab(tester, 'Stats');
    expect(find.byType(BarChart), findsNothing);
    expect(find.textContaining('No earnings yet'), findsOneWidget);
  });

  testWidgets('Stats chart renders for a player with history', (tester) async {
    final played = tick(stateWith(rigLevels: {'cpu': 3}), t0 + 3 * hourMs);
    clock.now = played.lastTick;
    await pumpApp(tester, clock, saved: savedGame(played));
    await openTab(tester, 'Stats');
    expect(find.byType(BarChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Achievements'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 / ${achievements.length}'), findsOneWidget);
  });

  testWidgets('Settings: rename the player and reset progress', (tester) async {
    final prefs = await pumpApp(tester, clock,
        saved: savedGame(stateWith(
          rigLevels: {'cpu': 4},
          coins: 999,
        )));
    await openTab(tester, 'Settings');
    await tester.scrollUntilVisible(find.text(appDisclaimer), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle(); // back to the top for the steps below

    await tester.tap(find.byKey(const ValueKey('edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('name-field')), '  Rig Runner ');
    await tester.tap(find.byKey(const ValueKey('save-name')));
    await tester.pumpAndSettle();
    expect(find.text('Rig Runner'), findsOneWidget);
    expect(storedGame(prefs)!.playerName, 'Rig Runner');

    // Cancelling the reset keeps everything.
    await tester.tap(find.byKey(const ValueKey('reset-progress')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(liveGame(tester).coins, 999);

    await tester.tap(find.byKey(const ValueKey('reset-progress')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-reset')));
    await tester.pumpAndSettle();
    expect(liveGame(tester).coins, startingCoins);
    expect(liveGame(tester).rigs['cpu'], 0);
    expect(storedGame(prefs)!.rigs['cpu'], 0);
    expect(find.textContaining('Progress reset'), findsOneWidget);
  });
}

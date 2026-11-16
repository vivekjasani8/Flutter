import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/app_harness.dart';
import 'support/fixtures.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock(t0));

  testWidgets('Mine shows total hash rate and income', (tester) async {
    // 5 CPU racks (1 TH/s each) + 2 GPU rigs (4 TH/s each) = 13 TH/s.
    final s = stateWith(rigLevels: {'cpu': 5, 'gpu': 2});
    await pumpApp(tester, clock, saved: savedGame(s));

    expect(totalHash(s), 13);
    expect(textOf(tester, 'total-hash'), '13 TH/s');
    expect(
        textOf(tester, 'income'), '${formatNumber(13 * coinsPerThSecond)}/s');
    expect(find.text('+${formatNumber(13 * coinsPerThSecond * 3600)} per hour'),
        findsOneWidget);
  });

  testWidgets('a new game shows 0 TH/s', (tester) async {
    await pumpApp(tester, clock);
    expect(textOf(tester, 'total-hash'), '0 TH/s');
  });

  testWidgets('the Shop shows the total and it rises when you buy',
      (tester) async {
    await pumpApp(tester, clock, saved: savedGame(stateWith(coins: 1000)));
    await openTab(tester, 'Shop');
    expect(textOf(tester, 'total-hash'), '0 TH/s');

    await tester.tap(find.byKey(const ValueKey('buy-gpu')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'total-hash'), '4 TH/s');

    await openTab(tester, 'Mine');
    expect(textOf(tester, 'total-hash'), '4 TH/s');
  });

  testWidgets('screen readers hear label and value together', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, clock,
        saved: savedGame(stateWith(rigLevels: {'cpu': 3})));
    expect(find.bySemanticsLabel(RegExp(r'Total hash rate\s+3 TH/s')),
        findsOneWidget);
    semantics.dispose();
  });
}

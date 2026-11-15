import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/main.dart';

void main() {
  testWidgets('app boots to the mine screen with the disclaimer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const IdleMinerApp());

    expect(find.text('Idle Miner Sim'), findsOneWidget);
    expect(find.text('$coinName balance'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text(appDisclaimer), findsOneWidget);
  });

  testWidgets('buying a CPU rack raises its level', (WidgetTester tester) async {
    await tester.pumpWidget(const IdleMinerApp());

    expect(find.textContaining('Lv 0'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('Lv 1'), findsOneWidget);
  });
}

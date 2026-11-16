import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';
import 'support/cloud_fakes.dart';
import 'support/fixtures.dart';

void main() {
  late FakeClock clock;
  late FakeCloudAuth auth;
  late FakeCloudStore store;
  late FakeLeaderboard board;

  setUp(() {
    clock = FakeClock(t0);
    auth = FakeCloudAuth();
    store = FakeCloudStore();
    board = FakeLeaderboard(auth);
  });

  final me = stateWith(rigLevels: {'cpu': 3})
      .copyWith(lifetimeCoins: 1000, playerName: 'Rig Runner');

  Future<void> openLeaderboard(WidgetTester tester, {bool cloud = true}) async {
    await pumpApp(tester, clock,
        saved: savedGame(me),
        cloudAuth: cloud ? auth : null,
        cloudStore: cloud ? store : null,
        leaderboard: cloud ? board : null);
    await openTab(tester, 'Stats');
    await tester.tap(find.byKey(const ValueKey('open-leaderboard')));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, Finder f) => tester
      .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
      .map((t) => t.data)
      .join(' | ');

  testWidgets('shows the top players, highlights me, and my rank',
      (tester) async {
    board.scores['rival'] = (name: 'Rival', score: 900000);
    board.scores['newbie'] = (name: 'Newbie', score: 50);
    await openLeaderboard(tester);

    expect(board.submits, 1, reason: 'my save went through the server check');
    expect(text(tester, find.byKey(const ValueKey('my-standing'))),
        contains('Your rank: #2'));
    expect(
        text(tester, find.byKey(const ValueKey('rank-1'))), contains('Rival'));
    expect(text(tester, find.byKey(const ValueKey('rank-2'))),
        contains('Rig Runner (you)'));
    expect(
        text(tester, find.byKey(const ValueKey('rank-3'))), contains('Newbie'));
  });

  testWidgets('outside the top 100, my rank is pinned at the bottom',
      (tester) async {
    for (var i = 0; i < 120; i++) {
      board.scores['p$i'] = (name: 'Player $i', score: 100000 + i);
    }
    await openLeaderboard(tester);

    expect(text(tester, find.byKey(const ValueKey('my-standing'))),
        contains('#121'));
    final pinned = find.byKey(const ValueKey('rank-121'));
    await tester.scrollUntilVisible(pinned, 400,
        scrollable: find.byType(Scrollable).first);
    expect(text(tester, pinned), contains('You'));
    expect(find.byKey(const ValueKey('rank-101')), findsNothing);
  });

  testWidgets('pull to refresh submits again', (tester) async {
    await openLeaderboard(tester);
    expect(board.submits, 1);
    await tester.fling(
        find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(board.submits, 2);
  });

  testWidgets('offline: explains, and Try again works', (tester) async {
    board.online = false;
    await openLeaderboard(tester);
    expect(find.byKey(const ValueKey('leaderboard-error')), findsOneWidget);
    expect(find.text('No internet connection.'), findsOneWidget);

    board.online = true;
    await tester.tap(find.byKey(const ValueKey('leaderboard-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-standing')), findsOneWidget);
  });

  testWidgets('without cloud save it says the leaderboard is unavailable',
      (tester) async {
    await openLeaderboard(tester, cloud: false);
    expect(find.textContaining('not available on this device'), findsOneWidget);
  });

  testWidgets('meets the accessibility guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    board.scores['rival'] = (name: 'Rival', score: 900000);
    await openLeaderboard(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}

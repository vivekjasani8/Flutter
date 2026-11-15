import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/reminders.dart';
import 'package:idle_miner_sim/state/reminders_controller.dart';

import 'support/app_harness.dart';
import 'support/fixtures.dart';

/// 10:00 UTC on 2023-11-15, so "next reward in" is a round 14h.
final int tenAm = DateTime.utc(2023, 11, 15, 10).millisecondsSinceEpoch;

/// A save that is current (no "while you were away"), with the given claim.
Map<String, Object> savedClaim({required int daysAgo, required int streak}) =>
    savedGame(GameState.newGame(tenAm).copyWith(
      lastClaimDay: dayKey(tenAm - daysAgo * dayMs),
      streak: streak,
    ));

String streakText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('streak'))).data!;

Future<void> claim(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('claim-daily')));
  await tester.pumpAndSettle();
}

Future<void> dismissReminderPromptIfShown(WidgetTester tester) async {
  if (find.text('Want a reminder?').evaluate().isEmpty) return;
  await tester.tap(find.text('Not now'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeClock clock;
  late FakeReminderScheduler os;
  setUp(() {
    clock = FakeClock(tenAm);
    os = FakeReminderScheduler();
  });

  group('daily streak', () {
    testWidgets(
        'first claim pays day 1, then offers reminders once and asks the OS',
        (tester) async {
      await pumpApp(tester, clock, reminders: os);
      expect(os.permissionRequests, 0, reason: 'nothing asked on launch');
      await openTab(tester, 'Rewards');
      expect(streakText(tester), 'No streak yet');

      await claim(tester);
      expect(liveGame(tester).coins, startingCoins + streakReward(1));
      expect(find.textContaining('day 1 streak'), findsOneWidget);

      expect(find.text('Want a reminder?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('enable-reminders')));
      await tester.pumpAndSettle();
      expect(os.permissionRequests, 1);
      expect(remindersOn(tester), isTrue);

      expect(streakText(tester), '1-day streak');
      expect(find.text('Next reward in 14h'), findsOneWidget);
      final button = tester
          .widget<ButtonStyleButton>(find.byKey(const ValueKey('claim-daily')));
      expect(button.onPressed, isNull, reason: 'one claim per day');
    });

    testWidgets('a streak from yesterday grows and pays more', (tester) async {
      await pumpApp(tester, clock,
          reminders: os, saved: savedClaim(daysAgo: 1, streak: 3));
      await openTab(tester, 'Rewards');
      expect(streakText(tester), '3-day streak');
      expect(find.textContaining('Claim +${formatNumber(streakReward(4))}'),
          findsOneWidget);

      await claim(tester);
      await dismissReminderPromptIfShown(tester);
      expect(streakText(tester), '4-day streak');
      expect(liveGame(tester).coins, startingCoins + streakReward(4));
    });

    testWidgets('a missed day resets the streak to day 1', (tester) async {
      await pumpApp(tester, clock,
          reminders: os, saved: savedClaim(daysAgo: 2, streak: 5));
      await openTab(tester, 'Rewards');
      expect(streakText(tester), 'No streak yet', reason: 'streak was broken');

      await claim(tester);
      await dismissReminderPromptIfShown(tester);
      expect(streakText(tester), '1-day streak');
      expect(liveGame(tester).streak, 1);
      expect(liveGame(tester).coins, startingCoins + streakReward(1));
    });

    testWidgets('the reminder prompt is never shown twice', (tester) async {
      final prefs = await pumpApp(tester, clock,
          reminders: os, saved: savedClaim(daysAgo: 1, streak: 1));
      await prefs.setBool(RemindersController.promptedKey, true);
      await openTab(tester, 'Rewards');
      await claim(tester);
      expect(find.text('Want a reminder?'), findsNothing);
      expect(os.permissionRequests, 0);
    });
  });

  group('achievements', () {
    testWidgets('grid shows locked and unlocked achievements', (tester) async {
      await pumpApp(tester, clock,
          reminders: os,
          saved: savedGame(stateWith(rigLevels: {'cpu': 1})
              .copyWith(lastTick: tenAm, achievements: ['first_rig'])));
      await openTab(tester, 'Rewards');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('achievement-count')))
            .data,
        '1 / ${achievements.length}',
      );
      for (final a in achievements) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('achievement-${a.id}')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
      }
      expect(find.bySemanticsLabel(RegExp('^Booting Up, unlocked')),
          findsOneWidget);
      expect(
          find.bySemanticsLabel(RegExp('^Full Stack, locked')), findsOneWidget);
    });

    testWidgets('buying a first rig announces the achievement', (tester) async {
      await pumpApp(tester, clock, reminders: os);
      await openTab(tester, 'Shop');
      await tester.tap(find.byKey(const ValueKey('buy-cpu')));
      await tester.pumpAndSettle(); // let the snackbar finish sliding in
      expect(find.text('Achievement unlocked: Booting Up'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('achievement-count')), findsOneWidget);
    });
  });

  group('reminders', () {
    testWidgets('going to the background schedules them; returning cancels',
        (tester) async {
      await pumpApp(tester, clock, reminders: os, saved: {
        ...savedGame(stateWith(rigLevels: {'cpu': 1}).copyWith(
          lastTick: tenAm,
          lastClaimDay: dayKey(tenAm),
          streak: 2,
        )),
        RemindersController.enabledKey: true,
      });

      await sendToBackground(tester);
      expect(os.pending.keys, unorderedEquals(ReminderIds.planned));
      expect(os.pending[ReminderIds.storageFull]!.at,
          tenAm + offlineCapSeconds * 1000);

      await bringToForeground(tester);
      expect(os.pending, isEmpty);
    });

    testWidgets('nothing is scheduled while reminders are off', (tester) async {
      await pumpApp(tester, clock,
          reminders: os, saved: savedGame(stateWith(rigLevels: {'cpu': 1})));
      await sendToBackground(tester);
      expect(os.pending, isEmpty);
    });

    testWidgets('Settings switch turns reminders on and off', (tester) async {
      await pumpApp(tester, clock, reminders: os);
      await openTab(tester, 'Settings');

      await tester.tap(find.byKey(const ValueKey('reminders-switch')));
      await tester.pumpAndSettle();
      expect(remindersOn(tester), isTrue);

      await tester.tap(find.byKey(const ValueKey('reminders-switch')));
      await tester.pumpAndSettle();
      expect(remindersOn(tester), isFalse);
    });

    testWidgets('a blocked permission explains what to do', (tester) async {
      os.grant = false;
      await pumpApp(tester, clock, reminders: os);
      await openTab(tester, 'Settings');
      await tester.tap(find.byKey(const ValueKey('reminders-switch')));
      await tester.pumpAndSettle();
      expect(remindersOn(tester), isFalse);
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    });

    testWidgets('debug test reminder is scheduled 10 s out', (tester) async {
      await pumpApp(tester, clock, reminders: os);
      await openTab(tester, 'Settings');
      await tester.tap(find.byKey(const ValueKey('test-reminder')));
      await tester.pumpAndSettle();
      expect(os.pending[ReminderIds.test]!.at, tenAm + 10000);
    });
  });
}

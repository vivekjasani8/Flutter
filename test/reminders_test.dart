import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/reminders.dart';

import 'support/fixtures.dart';

final int midnight = DateTime.utc(2023, 11, 15).millisecondsSinceEpoch;

Reminder? byId(List<Reminder> rs, int id) {
  for (final r in rs) {
    if (r.id == id) return r;
  }
  return null;
}

void main() {
  group('planReminders', () {
    test('a brand-new game plans nothing', () {
      expect(planReminders(GameState.newGame(t0), t0), isEmpty);
    });

    test('with rigs: "storage full" when the 8 h cap is reached', () {
      final s = stateWith(rigLevels: {'cpu': 2});
      final storage = byId(planReminders(s, t0), ReminderIds.storageFull)!;
      expect(storage.at, t0 + offlineCapSeconds * 1000);
      expect(storage.title, 'Storage full');
      // The amount shown is what 8 h of 2 CPU racks earns.
      expect(storage.body,
          contains(formatNumber(2 * cpuRate * offlineCapSeconds)));
    });

    test('no "storage full" if it would already be in the past', () {
      final s = stateWith(rigLevels: {'cpu': 1});
      expect(byId(planReminders(s, t0 + 9 * hourMs), ReminderIds.storageFull),
          isNull);
    });

    test('with a streak: warn 4 h before it breaks', () {
      // Claimed at 10:00 UTC on day D: breaks at 00:00 on D+2.
      final s = GameState.newGame(midnight)
          .copyWith(lastClaimDay: dayKey(midnight + 10 * hourMs), streak: 3);
      final warn = byId(
          planReminders(s, midnight + 11 * hourMs), ReminderIds.streakAtRisk)!;
      expect(warn.at, midnight + 2 * dayMs - 4 * hourMs);
      expect(warn.title, contains('3-day streak'));
      // By then the next claim is open (it opened at 00:00 on D+1).
      final atWarn = s.copyWith(lastTick: warn.at);
      expect(canClaimDaily(atWarn, warn.at), isTrue);
    });

    test('no streak warning without a streak or once it is too late', () {
      expect(
          byId(planReminders(GameState.newGame(t0), t0),
              ReminderIds.streakAtRisk),
          isNull);
      final s = GameState.newGame(midnight)
          .copyWith(lastClaimDay: dayKey(midnight), streak: 2);
      expect(
          byId(planReminders(s, midnight + 2 * dayMs - hourMs),
              ReminderIds.streakAtRisk),
          isNull);
    });

    test('ids are stable so rescheduling replaces, never duplicates', () {
      final s = stateWith(rigLevels: {'cpu': 1})
          .copyWith(lastClaimDay: dayKey(t0), streak: 1);
      final ids = planReminders(s, t0).map((r) => r.id).toList();
      expect(ids, unorderedEquals(ReminderIds.planned));
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('never promises real money', () {
      final s = stateWith(rigLevels: {'cpu': 1})
          .copyWith(lastClaimDay: dayKey(t0), streak: 1);
      for (final r in planReminders(s, t0)) {
        final text = '${r.title} ${r.body}'.toLowerCase();
        for (final banned in ['withdraw', 'cash out', 'usdt', 'bitcoin']) {
          expect(text, isNot(contains(banned)), reason: r.title);
        }
      }
    });
  });
}

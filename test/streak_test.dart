import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

/// 2023-11-15T00:00:00Z — a UTC midnight, so day arithmetic is easy to read.
final int midnight = DateTime.utc(2023, 11, 15).millisecondsSinceEpoch;

GameState claimedOn(int ms, {int streak = 1}) =>
    GameState.newGame(ms).copyWith(lastClaimDay: dayKey(ms), streak: streak);

void main() {
  group('activeStreak', () {
    test('is 0 before the first claim', () {
      expect(activeStreak(GameState.newGame(t0), t0), 0);
    });

    test('holds on the claim day and the day after', () {
      final s = claimedOn(midnight + 10 * hourMs, streak: 4);
      expect(activeStreak(s, midnight + 23 * hourMs), 4);
      expect(activeStreak(s, midnight + dayMs + 23 * hourMs), 4);
    });

    test('drops to 0 once a whole day was missed', () {
      final s = claimedOn(midnight + 10 * hourMs, streak: 4);
      expect(activeStreak(s, midnight + 2 * dayMs), 0);
      expect(activeStreak(s, midnight + 9 * dayMs), 0);
    });
  });

  group('nextClaimStreak', () {
    test('extends a streak claimed yesterday', () {
      final s = claimedOn(midnight, streak: 3);
      expect(nextClaimStreak(s, midnight + dayMs + hourMs), 4);
    });

    test('restarts at 1 after a missed day or on the first claim', () {
      expect(
          nextClaimStreak(claimedOn(midnight, streak: 3), midnight + 2 * dayMs),
          1);
      expect(nextClaimStreak(GameState.newGame(t0), t0), 1);
    });

    test('matches what claimDaily actually does', () {
      var s = GameState.newGame(midnight);
      for (var day = 0; day < 9; day++) {
        final at = midnight + day * dayMs + 5 * hourMs;
        final expected = nextClaimStreak(s, at);
        s = claimDaily(s, at)!;
        expect(s.streak, expected);
      }
      // Skip a day: the streak resets.
      final afterGap = midnight + 10 * dayMs + 5 * hourMs;
      expect(nextClaimStreak(s, afterGap), 1);
      expect(claimDaily(s, afterGap)!.streak, 1);
    });

    test('the day-7 reward is the cap', () {
      expect(
          streakReward(nextClaimStreak(
              claimedOn(midnight, streak: 6), midnight + dayMs)),
          700);
      expect(
          streakReward(nextClaimStreak(
              claimedOn(midnight, streak: 30), midnight + dayMs)),
          700);
    });
  });

  group('day timing', () {
    test('msUntilNextDay counts down to 00:00 UTC', () {
      expect(msUntilNextDay(midnight), dayMs);
      expect(msUntilNextDay(midnight + 20 * hourMs), 4 * hourMs);
      expect(msUntilNextDay(midnight + dayMs - 1), 1);
    });

    test('streakDeadline is the end of the day after the last claim', () {
      expect(streakDeadline(GameState.newGame(t0)), isNull);
      final s = claimedOn(midnight + 18 * hourMs);
      expect(streakDeadline(s), midnight + 2 * dayMs);
      // Just before the deadline the streak is alive; at it, gone.
      expect(activeStreak(s.copyWith(streak: 2), midnight + 2 * dayMs - 1), 2);
      expect(activeStreak(s.copyWith(streak: 2), midnight + 2 * dayMs), 0);
    });

    test('storageFullAt is the last settle plus the offline cap', () {
      final s = GameState.newGame(t0);
      expect(storageFullAt(s), t0 + offlineCapSeconds * 1000);
      expect(offlineCapped(s, storageFullAt(s)), isFalse);
      expect(offlineCapped(s, storageFullAt(s) + 1), isTrue);
    });
  });
}

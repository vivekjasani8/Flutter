import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

void main() {
  group('offlineEarnings', () {
    test('equals rate x elapsed time for a short absence', () {
      final s = stateWith(rigLevels: {'cpu': 3});
      expect(offlineEarnings(s, t0 + 10 * minuteMs),
          closeTo(3 * cpuRate * 600, 1e-9));
    });

    test('is zero with no rigs', () {
      expect(offlineEarnings(GameState.newGame(t0), t0 + 5 * hourMs), 0);
    });

    test('is capped at the 8 h offline window', () {
      final s = stateWith(rigLevels: {'cpu': 1});
      final capped = cpuRate * offlineCapSeconds;
      expect(offlineEarnings(s, t0 + 8 * hourMs), closeTo(capped, 1e-6));
      expect(offlineEarnings(s, t0 + 10 * hourMs), closeTo(capped, 1e-6));
      expect(offlineEarnings(s, t0 + 30 * dayMs), closeTo(capped, 1e-6));
    });

    test('matches what tick actually pays', () {
      final s = stateWith(rigLevels: {'cpu': 2, 'gpu': 1});
      const now = t0 + 5 * hourMs + 123;
      expect(
          offlineEarnings(s, now), closeTo(tick(s, now).coins - s.coins, 1e-9));
    });

    test('counts the boosted part of the absence at 2x', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      s = activateBoost(s, t0); // 30 min boost
      final expected =
          cpuRate * 1800 * boostMultiplier + cpuRate * 1800; // 30 min each
      expect(offlineEarnings(s, t0 + hourMs), closeTo(expected, 1e-6));
    });

    test('does not change the state it is given', () {
      final s = stateWith(rigLevels: {'cpu': 1});
      final before = s.toJson();
      offlineEarnings(s, t0 + hourMs);
      expect(s.toJson(), before);
    });
  });

  group('clock rollback', () {
    test('offlineEarnings is zero when the clock goes backwards', () {
      final s = stateWith(rigLevels: {'cpu': 1});
      expect(offlineEarnings(s, t0 - hourMs), 0);
      expect(offlineEarnings(s, t0), 0);
    });

    test('rolling back then forward never pays the same time twice', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      s = tick(s, t0 - 6 * hourMs); // clock jumps back 6 h: no change
      expect(s.lastTick, t0);
      s = tick(s, t0 + 10 * secondMs); // back to real time + 10 s
      expect(s.coins - startingCoins, closeTo(cpuRate * 10, 1e-9));
    });

    test('buying with a backwards clock earns nothing and keeps lastTick', () {
      final s = stateWith(rigLevels: {'cpu': 1});
      final after = buyRig(s, 'cpu', t0 - hourMs)!;
      expect(after.lastTick, t0);
      expect(after.coins, s.coins - rigCost('cpu', 1));
    });

    test('daily reward cannot be re-claimed by setting the clock back a day',
        () {
      final day1 = claimDaily(GameState.newGame(t0), t0)!;
      expect(claimDaily(day1, t0 - dayMs), isNull);
      expect(claimDaily(day1, t0 - 30 * dayMs), isNull);
    });

    test('toggling the clock between two days cannot farm the streak', () {
      var s = claimDaily(GameState.newGame(t0), t0)!; // day D
      s = claimDaily(s, t0 + dayMs)!; // day D+1, streak 2
      final coins = s.coins;
      for (var i = 0; i < 5; i++) {
        expect(claimDaily(s, t0), isNull); // back to D
        expect(claimDaily(s, t0 + dayMs), isNull); // D+1 again
      }
      expect(s.streak, 2);
      expect(s.coins, coins);
    });
  });

  group('earnings history', () {
    test('keeps at most the last 24 hour buckets', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      for (var h = 1; h <= 40; h++) {
        s = tick(s, t0 + h * hourMs);
      }
      expect(s.hourly.length, lessThanOrEqualTo(historyHours));
      final newest = s.hourly.keys.reduce((a, b) => a > b ? a : b);
      final oldest = s.hourly.keys.reduce((a, b) => a < b ? a : b);
      expect(newest - oldest, (historyHours - 1) * hourMs);
    });
  });
}

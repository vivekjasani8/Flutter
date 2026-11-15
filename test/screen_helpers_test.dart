import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

void main() {
  group('canAfford', () {
    test('compares the balance with the next level price', () {
      expect(canAfford(stateWith(coins: 50), 'cpu'), isTrue);
      expect(canAfford(stateWith(coins: 49), 'cpu'), isFalse);
      // Level 1 -> 2 costs ceil(50 * 1.15) = 58.
      expect(canAfford(stateWith(rigLevels: {'cpu': 1}, coins: 57), 'cpu'),
          isFalse);
      expect(canAfford(stateWith(rigLevels: {'cpu': 1}, coins: 58), 'cpu'),
          isTrue);
    });
  });

  group('offlineCapped', () {
    test('is true only past the 8 h cap', () {
      final s = GameState.newGame(t0);
      expect(offlineCapped(s, t0 + 8 * hourMs), isFalse);
      expect(offlineCapped(s, t0 + 8 * hourMs + 1), isTrue);
      expect(offlineCapped(s, t0 - hourMs), isFalse);
    });
  });

  group('earningsHistory', () {
    test('always returns 24 hourly buckets, oldest first, zero-filled', () {
      final h = earningsHistory(GameState.newGame(t0), t0);
      expect(h, hasLength(historyHours));
      expect(h.every((e) => e.coins == 0), isTrue);
      const currentHour = t0 ~/ hourMs * hourMs;
      expect(h.last.hourStart, currentHour);
      expect(h.first.hourStart, currentHour - (historyHours - 1) * hourMs);
      for (var i = 1; i < h.length; i++) {
        expect(h[i].hourStart - h[i - 1].hourStart, hourMs);
      }
    });

    test('matches what tick recorded per hour and sums to lifetime coins', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      const now = t0 + 5 * hourMs;
      s = tick(s, now);
      final h = earningsHistory(s, now);
      final total = h.fold<double>(0, (sum, e) => sum + e.coins);
      expect(total, closeTo(s.lifetimeCoins, 1e-6));
      expect(h.where((e) => e.coins > 0).length, inInclusiveRange(5, 6));
    });
  });

  group('formatDuration', () {
    test('uses at most two units', () {
      expect(formatDuration(0), '0s');
      expect(formatDuration(45), '45s');
      expect(formatDuration(60), '1m');
      expect(formatDuration(1000), '16m 40s');
      expect(formatDuration(3600), '1h');
      expect(formatDuration(20000), '5h 33m');
      expect(formatDuration(8 * 3600), '8h');
      expect(formatDuration(2 * 86400 + 4 * 3600 + 59), '2d 4h');
    });

    test('rounds down and treats bad input as zero', () {
      expect(formatDuration(59.9), '59s');
      expect(formatDuration(-5), '0s');
      expect(formatDuration(double.infinity), '0s');
      expect(formatDuration(double.nan), '0s');
    });
  });
}

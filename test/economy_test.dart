import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

void main() {
  const t0 = 1700000000000; // fixed epoch ms for deterministic tests

  group('new game', () {
    test('starts with the configured balance and no rigs', () {
      final s = GameState.newGame(t0);
      expect(s.coins, startingCoins);
      expect(s.lifetimeCoins, 0);
      expect(totalHash(s), 0);
      expect(s.rigs.values.every((l) => l == 0), isTrue);
    });
  });

  group('rig cost', () {
    test('level 1 equals the base cost', () {
      expect(rigCost('cpu', 0), 50);
      expect(rigCost('gpu', 0), 400);
    });

    test('grows by the cost-growth factor per level', () {
      expect(rigCost('cpu', 1), (50 * costGrowth).ceilToDouble());
      expect(rigCost('cpu', 2), (50 * costGrowth * costGrowth).ceilToDouble());
    });

    test('unknown rig throws', () {
      expect(() => rigCost('nope', 0), throwsArgumentError);
    });
  });

  group('earnings tick', () {
    test('no rigs earns nothing', () {
      final s = GameState.newGame(t0);
      final after = tick(s, t0 + 10000);
      expect(after.coins, startingCoins);
    });

    test('one CPU rack earns rate x elapsed seconds', () {
      var s = GameState.newGame(t0);
      s = buyRig(s, 'cpu', t0)!; // costs 50, leaves 50, 1 TH/s
      final after = tick(s, s.lastTick + 10000); // 10 seconds
      final expected = 1 * coinsPerThSecond * 10;
      expect(after.coins, closeTo(s.coins + expected, 1e-9));
    });

    test('a backwards clock earns nothing and keeps lastTick', () {
      var s = GameState.newGame(t0);
      s = buyRig(s, 'cpu', t0)!;
      final after = tick(s, s.lastTick - 60000);
      expect(after.coins, s.coins);
      expect(after.lastTick, s.lastTick);
    });

    test('offline earnings are capped at the offline window', () {
      var s = GameState.newGame(t0);
      s = buyRig(s, 'cpu', t0)!;
      final start = s.coins;
      const tenHours = t0 + 10 * 3600 * 1000;
      final after = tick(s, tenHours);
      final capped = 1 * coinsPerThSecond * offlineCapSeconds;
      expect(after.coins - start, closeTo(capped, 1e-6));
    });

    test('boost doubles earnings only while active', () {
      var s = GameState.newGame(t0);
      s = buyRig(s, 'cpu', t0)!;
      s = activateBoost(s, s.lastTick); // 30 min boost from now
      final start = s.coins;
      // Run for one hour: 30 min boosted (2x) + 30 min plain.
      final after = tick(s, s.lastTick + 3600 * 1000);
      final boosted = 1 * coinsPerThSecond * 1800 * boostMultiplier;
      final plain = 1 * coinsPerThSecond * 1800;
      expect(after.coins - start, closeTo(boosted + plain, 1e-6));
    });
  });

  group('buying rigs', () {
    test('returns null when unaffordable', () {
      final s = GameState.newGame(t0);
      expect(buyRig(s, 'farm', t0), isNull); // farm costs 200000
    });

    test('deducts cost and raises the level and hash rate', () {
      final s = GameState.newGame(t0);
      final after = buyRig(s, 'cpu', t0)!;
      expect(after.rigs['cpu'], 1);
      expect(after.coins, startingCoins - 50);
      expect(totalHash(after), 1);
    });
  });

  group('daily streak', () {
    test('first claim sets streak 1 and pays the reward', () {
      final s = GameState.newGame(t0);
      final after = claimDaily(s, t0)!;
      expect(after.streak, 1);
      expect(after.coins, startingCoins + streakReward(1));
    });

    test('claiming again the same day is rejected', () {
      final s = GameState.newGame(t0);
      final once = claimDaily(s, t0)!;
      expect(claimDaily(once, t0), isNull);
    });

    test('consecutive days extend the streak', () {
      final s = GameState.newGame(t0);
      final day1 = claimDaily(s, t0)!;
      final day2 = claimDaily(day1, t0 + 24 * 3600 * 1000)!;
      expect(day2.streak, 2);
    });

    test('a missed day resets the streak to 1', () {
      final s = GameState.newGame(t0);
      final day1 = claimDaily(s, t0)!;
      final later = claimDaily(day1, t0 + 48 * 3600 * 1000)!;
      expect(later.streak, 1);
    });

    test('streak reward is capped at day 7', () {
      expect(streakReward(7), streakReward(10));
    });
  });

  group('achievements', () {
    test('first rig unlocks the Booting Up achievement', () {
      final s = GameState.newGame(t0);
      final after = buyRig(s, 'cpu', t0)!;
      expect(after.achievements, contains('first_rig'));
    });
  });

  group('formatNumber', () {
    test('formats magnitudes with unit suffixes', () {
      expect(formatNumber(950), '950');
      expect(formatNumber(12500), '12.5K');
      expect(formatNumber(2000000), '2.0M');
    });
  });
}

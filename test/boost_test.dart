import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

void main() {
  group('boost stacking', () {
    test('a single boost lasts the configured duration', () {
      final s = activateBoost(stateWith(), t0);
      expect(s.boostUntil, t0 + boostDurationMs);
      expect(isBoosted(s, t0 + boostDurationMs - 1), isTrue);
      expect(isBoosted(s, t0 + boostDurationMs), isFalse);
    });

    test('two boosts at once run end to end, not overlapping', () {
      var s = activateBoost(stateWith(), t0);
      s = activateBoost(s, t0);
      expect(s.boostUntil, t0 + 2 * boostDurationMs);
    });

    test('a boost bought mid-boost extends from the current end', () {
      var s = activateBoost(stateWith(), t0);
      s = activateBoost(s, t0 + 10 * minuteMs);
      expect(s.boostUntil, t0 + 2 * boostDurationMs);
    });

    test('a boost bought after the last one expired starts from now', () {
      var s = activateBoost(stateWith(), t0);
      const later = t0 + 2 * hourMs;
      s = activateBoost(s, later);
      expect(s.boostUntil, later + boostDurationMs);
    });

    test('the multiplier never stacks above 2x', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      s = activateBoost(s, t0);
      s = activateBoost(s, t0);
      s = activateBoost(s, t0);
      // 10 s inside the stacked window earns exactly 2x, not 6x.
      final after = tick(s, t0 + 10 * secondMs);
      expect(after.coins - s.coins, closeTo(cpuRate * 10 * boostMultiplier, 1e-9));
    });

    test('stacked boosts pay 2x for their combined length, then 1x', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      s = activateBoost(s, t0);
      s = activateBoost(s, t0); // 60 min boosted in total
      final after = tick(s, t0 + 90 * minuteMs);
      const expected = cpuRate * 3600 * boostMultiplier + cpuRate * 1800;
      expect(after.coins - s.coins, closeTo(expected, 1e-6));
    });

    test('a boost that ended before the 8 h offline window adds nothing', () {
      var s = stateWith(rigLevels: {'cpu': 1});
      s = activateBoost(s, t0); // boosted t0 .. t0 + 30 min
      // 10 h later only the last 8 h count, all of it unboosted.
      final earned = offlineEarnings(s, t0 + 10 * hourMs);
      expect(earned, closeTo(cpuRate * offlineCapSeconds, 1e-6));
    });
  });
}

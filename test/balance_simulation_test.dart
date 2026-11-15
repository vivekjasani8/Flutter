import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

/// Simulate a player who owns one level of [id] and nothing else, starting at
/// 0 coins, ticking every [stepSeconds] until the rig has earned back its
/// level-1 price. Returns the simulated seconds.
int simulatePaybackSeconds(String id, {int stepSeconds = 10}) {
  final price = rigCost(id, 0);
  var s = stateWith(rigLevels: {id: 1}, coins: 0);
  var elapsed = 0;
  while (s.coins < price) {
    s = tick(s, s.lastTick + stepSeconds * secondMs);
    elapsed += stepSeconds;
  }
  return elapsed;
}

void main() {
  group('balance simulation: rig payback', () {
    test('CPU Rack pays for itself in about 17 minutes', () {
      final minutes = simulatePaybackSeconds('cpu') / 60;
      expect(minutes, inInclusiveRange(16, 18));
    });

    test('Quantum Farm pays for itself in about 5.6 hours', () {
      final hours = simulatePaybackSeconds('farm') / 3600;
      expect(hours, inInclusiveRange(5.5, 5.7));
    });

    test('each higher tier takes longer to pay back than the one below', () {
      final times = [for (final r in rigs) simulatePaybackSeconds(r.id)];
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]),
            reason:
                '${rigs[i].id} should pay back slower than ${rigs[i - 1].id}');
      }
    });

    test('the simulation agrees with paybackSeconds for every rig', () {
      const step = 10;
      for (final r in rigs) {
        final simulated = simulatePaybackSeconds(r.id, stepSeconds: step);
        expect(simulated, closeTo(paybackSeconds(r.id, 0), step), reason: r.id);
      }
    });

    test("a rig's payback stays well inside one offline window", () {
      // Every rig must be able to earn back its price within the 8 h cap,
      // otherwise an idle player could never afford the next one offline.
      for (final r in rigs) {
        expect(paybackSeconds(r.id, 0), lessThan(offlineCapSeconds),
            reason: r.id);
      }
    });
  });
}

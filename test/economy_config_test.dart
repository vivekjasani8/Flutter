import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

void main() {
  tearDown(() => useEconomy(EconomyConfig.defaults));

  group('defaults', () {
    test('are the shipped balance', () {
      const d = EconomyConfig.defaults;
      expect(d.costGrowth, 1.15);
      expect(d.coinsPerThSecond, 0.05);
      expect(d.offlineCapSeconds, 8 * 3600);
      expect(d.boostMultiplier, 2);
      expect(d.boostDurationMs, 30 * 60 * 1000);
      expect(d.startingCoins, 100);
      expect(d.streakRewardPerDay, 100);
      expect(d.streakRewardMaxDays, 7);
      expect(d.rigs.map((r) => r.id),
          ['cpu', 'gpu', 'asic_mini', 'asic_pro', 'farm']);
    });

    test('the Remote Config template matches the built-in defaults', () {
      final template =
          jsonDecode(File('remoteconfig.template.json').readAsStringSync())
              as Map<String, dynamic>;
      final param = (template['parameters'] as Map)['economy'] as Map;
      expect(param['valueType'], 'JSON');
      final value = (param['defaultValue'] as Map)['value'] as String;
      expect(jsonDecode(value), EconomyConfig.defaults.toJson());
    });

    test('survive a JSON round trip', () {
      final json = jsonEncode(EconomyConfig.defaults.toJson());
      expect(
          EconomyConfig.parse(json).toJson(), EconomyConfig.defaults.toJson());
    });
  });

  group('overrides', () {
    test('valid values are applied, everything else keeps its default', () {
      final c = EconomyConfig.parse(jsonEncode({
        'costGrowth': 1.2,
        'offlineCapSeconds': 12 * 3600,
        'rigs': {
          'cpu': {'baseCost': 40},
        },
      }));
      expect(c.costGrowth, 1.2);
      expect(c.offlineCapSeconds, 12 * 3600);
      expect(c.rigs.first.baseCost, 40);
      expect(c.rigs.first.baseHash, 1, reason: 'not overridden');
      expect(c.coinsPerThSecond, 0.05);
      expect(c.rigs[1].baseCost, 400);
    });

    test('out-of-range, wrong-type and unknown values are ignored', () {
      final c = EconomyConfig.parse(jsonEncode({
        'costGrowth': 50, // too steep
        'coinsPerThSecond': -1,
        'offlineCapSeconds': 1.5, // not whole
        'boostMultiplier': 'lots',
        'startingCoins': double.maxFinite,
        'streakRewardMaxDays': 0,
        'brandNewSetting': 3,
        'rigs': {
          'cpu': {'baseCost': 0, 'baseHash': 'x'},
          'unknown_rig': {'baseCost': 1},
        },
      }));
      expect(c.toJson(), EconomyConfig.defaults.toJson());
      expect(c.rigs.map((r) => r.id).toList(), hasLength(5));
    });

    test('unreadable JSON gives the defaults', () {
      for (final bad in ['', 'not json', '[1,2]', '42', '{"rigs": 7}']) {
        expect(
            EconomyConfig.parse(bad).toJson(), EconomyConfig.defaults.toJson(),
            reason: bad);
      }
    });
  });

  group('the engine follows the live economy', () {
    test('rig prices, payback, offline cap and daily rewards', () {
      useEconomy(EconomyConfig.parse(jsonEncode({
        'costGrowth': 1.5,
        'coinsPerThSecond': 0.1,
        'offlineCapSeconds': 2 * 3600,
        'streakRewardPerDay': 50,
        'streakRewardMaxDays': 3,
        'rigs': {
          'cpu': {'baseCost': 10},
        },
      })));

      expect(rigCost('cpu', 0), 10);
      expect(rigCost('cpu', 1), 15);
      expect(paybackSeconds('cpu', 0), 10 / (1 * 0.1));

      final s = stateWith(rigLevels: {'cpu': 1});
      expect(offlineEarnings(s, t0 + 10 * hourMs), closeTo(0.1 * 7200, 1e-6),
          reason: '2 h cap');

      expect(streakReward(1), 50);
      expect(streakReward(3), 150);
      expect(streakReward(10), 150, reason: 'capped at day 3');
    });

    test('a new game starts with the tuned balance', () {
      useEconomy(EconomyConfig.parse('{"startingCoins": 250}'));
      expect(GameState.newGame(t0).coins, 250);
    });
  });
}

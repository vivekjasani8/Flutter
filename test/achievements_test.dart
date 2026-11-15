import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

List<String> earnedBy(GameState s) => withAchievements(s).achievements;

void main() {
  group('achievements', () {
    test('a new game has none', () {
      expect(earnedBy(GameState.newGame(t0)), isEmpty);
    });

    test('hash_100 unlocks at exactly 100 TH/s, not before', () {
      expect(earnedBy(stateWith(rigLevels: {'cpu': 99})),
          isNot(contains('hash_100')));
      expect(
          earnedBy(stateWith(rigLevels: {'cpu': 100})), contains('hash_100'));
    });

    test('hash_1000 unlocks at 1,000 TH/s', () {
      // 5 farms = 1,000 TH/s.
      expect(earnedBy(stateWith(rigLevels: {'farm': 4})),
          isNot(contains('hash_1000')));
      expect(
          earnedBy(stateWith(rigLevels: {'farm': 5})), contains('hash_1000'));
    });

    test('coins_10k and coins_1m track lifetime coins, not the balance', () {
      final rich = stateWith().copyWith(coins: 0, lifetimeCoins: 10000);
      expect(earnedBy(rich), contains('coins_10k'));
      expect(earnedBy(rich), isNot(contains('coins_1m')));

      final millionaire = rich.copyWith(lifetimeCoins: 1000000);
      expect(earnedBy(millionaire), containsAll(['coins_10k', 'coins_1m']));

      // A big balance with low lifetime earnings unlocks nothing.
      expect(earnedBy(stateWith(coins: 2000000)), isEmpty);
    });

    test('earning past a threshold during a tick unlocks it', () {
      final s = stateWith(rigLevels: {'farm': 1})
          .copyWith(lifetimeCoins: 9990); // farm earns 10 coins/s
      expect(tick(s, t0 + 2 * secondMs).achievements, contains('coins_10k'));
    });

    test('streak_7 unlocks on the 7th consecutive daily claim', () {
      var s = GameState.newGame(t0);
      for (var day = 0; day < 6; day++) {
        s = claimDaily(s, t0 + day * dayMs)!;
      }
      expect(s.streak, 6);
      expect(s.achievements, isNot(contains('streak_7')));
      s = claimDaily(s, t0 + 6 * dayMs)!;
      expect(s.streak, 7);
      expect(s.achievements, contains('streak_7'));
    });

    test('all_rigs needs at least one of every rig', () {
      final allButOne = {for (final r in rigs.skip(1)) r.id: 1};
      expect(earnedBy(stateWith(rigLevels: allButOne)),
          isNot(contains('all_rigs')));
      final all = {for (final r in rigs) r.id: 1};
      expect(earnedBy(stateWith(rigLevels: all)), contains('all_rigs'));
    });

    test('every configured achievement can be unlocked', () {
      final maxed = stateWith(rigLevels: {for (final r in rigs) r.id: 10})
          .copyWith(lifetimeCoins: 1e9, streak: 7);
      expect(earnedBy(maxed), unorderedEquals(achievements.map((a) => a.id)));
    });

    test('are never duplicated and keep the order they were earned in', () {
      var s = GameState.newGame(t0).copyWith(coins: 1e6);
      s = buyRig(s, 'cpu', t0)!; // first_rig
      s = buyRig(s, 'farm', t0)!; // hash_100
      s = buyRig(s, 'cpu', t0)!; // nothing new
      s = withAchievements(withAchievements(s));
      expect(s.achievements, ['first_rig', 'hash_100']);
    });
  });
}

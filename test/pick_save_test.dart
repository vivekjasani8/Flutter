import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

GameState save({required double lifetime, double coins = 0, int at = t0}) =>
    GameState.newGame(at).copyWith(lifetimeCoins: lifetime, coins: coins);

void main() {
  group('pickSave', () {
    test('keeps the save with more lifetime coins', () {
      final local = save(lifetime: 500);
      final cloud = save(lifetime: 900);
      expect(pickSave(local, cloud), same(cloud));
      expect(pickSave(cloud, local), same(cloud));
    });

    test('lifetime coins win over a bigger balance', () {
      // The local player spent a lot on rigs; the cloud copy is older but
      // hoarded coins. Lifetime earnings decide, not the balance.
      final local = save(lifetime: 10000, coins: 50);
      final cloud = save(lifetime: 8000, coins: 8000);
      expect(pickSave(local, cloud), same(local));
    });

    test('on a tie the more recent save wins', () {
      final older = save(lifetime: 500, at: t0);
      final newer = save(lifetime: 500, at: t0 + 60000);
      expect(pickSave(older, newer), same(newer));
      expect(pickSave(newer, older), same(newer));
    });

    test('on a full tie the local save is kept', () {
      final local = save(lifetime: 500);
      final cloud = save(lifetime: 500);
      expect(pickSave(local, cloud), same(local));
    });

    test('a fresh game never replaces real progress', () {
      final progress = save(lifetime: 1);
      final fresh = GameState.newGame(t0 + 999999);
      expect(pickSave(progress, fresh), same(progress));
      expect(pickSave(fresh, progress), same(progress));
    });
  });
}

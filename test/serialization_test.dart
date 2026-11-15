import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/fixtures.dart';

/// Encode to a JSON string and back, the way shared_preferences will store it.
GameState roundTrip(GameState s) => GameState.fromJson(
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

/// A state with every field away from its default.
GameState playedState() {
  var s = stateWith(coins: 5000);
  s = buyRig(s, 'cpu', t0)!;
  s = buyRig(s, 'gpu', t0)!;
  s = activateBoost(s, t0);
  s = claimDaily(s, t0)!;
  s = tick(s, t0 + 3 * hourMs + 17 * secondMs);
  return s.copyWith(playerName: 'Rig Runner');
}

void main() {
  group('JSON round-trip', () {
    test('a new game survives encode/decode unchanged', () {
      final s = GameState.newGame(t0);
      expect(roundTrip(s).toJson(), s.toJson());
    });

    test('a played game survives encode/decode unchanged', () {
      final s = playedState();
      expect(s.hourly, isNotEmpty);
      expect(s.achievements, isNotEmpty);
      expect(s.boostUntil, greaterThan(0));

      final back = roundTrip(s);
      expect(back.toJson(), s.toJson());
      expect(back.coins, s.coins);
      expect(back.lifetimeCoins, s.lifetimeCoins);
      expect(back.rigs, s.rigs);
      expect(back.lastTick, s.lastTick);
      expect(back.boostUntil, s.boostUntil);
      expect(back.streak, s.streak);
      expect(back.lastClaimDay, s.lastClaimDay);
      expect(back.achievements, s.achievements);
      expect(back.hourly, s.hourly);
      expect(back.playerName, s.playerName);
    });

    test('a restored game keeps earning exactly like the original', () {
      final s = playedState();
      final later = s.lastTick + 2 * hourMs;
      expect(tick(roundTrip(s), later).toJson(), tick(s, later).toJson());
    });

    test('toJson output is plain JSON with a schema version', () {
      final json = playedState().toJson();
      expect(json['v'], GameState.schemaVersion);
      // Hour buckets become string keys; jsonEncode would throw otherwise.
      expect((json['hourly'] as Map<String, dynamic>).keys,
          everyElement(isA<String>()));
      expect(() => jsonEncode(json), returnsNormally);
    });
  });

  group('fromJson tolerance', () {
    test('whole-number doubles stored as ints are read back as doubles', () {
      final json = GameState.newGame(t0).toJson()
        ..['coins'] = 150
        ..['lifetimeCoins'] = 0
        ..['hourly'] = {'${t0 ~/ hourMs * hourMs}': 3};
      final s = GameState.fromJson(json);
      expect(s.coins, 150.0);
      expect(s.hourly.values.single, 3.0);
    });

    test('rigs missing from an old save default to level 0', () {
      final json = GameState.newGame(t0).toJson()..['rigs'] = {'cpu': 4};
      final s = GameState.fromJson(json);
      expect(s.rigs['cpu'], 4);
      expect(s.rigs.keys, containsAll(rigs.map((r) => r.id)));
      expect(s.rigs['farm'], 0);
    });

    test('rig ids no longer in the config are dropped', () {
      final json = GameState.newGame(t0).toJson()
        ..['rigs'] = {'cpu': 2, 'retired_rig': 9};
      final s = GameState.fromJson(json);
      expect(s.rigs.containsKey('retired_rig'), isFalse);
      expect(s.rigs['cpu'], 2);
    });

    test('optional fields fall back to new-game defaults', () {
      final s = GameState.fromJson({
        'coins': 10,
        'lifetimeCoins': 20,
        'lastTick': t0,
      });
      expect(s.boostUntil, 0);
      expect(s.streak, 0);
      expect(s.lastClaimDay, '');
      expect(s.achievements, isEmpty);
      expect(s.hourly, isEmpty);
      expect(s.playerName, 'Player');
      expect(s.rigs.values, everyElement(0));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/game_storage.dart';

import '../support/app_harness.dart';
import '../support/fixtures.dart';

void main() {
  test('load returns null when nothing is saved', () async {
    final prefs = await mockPrefs();
    expect(GameStorage(prefs).load(), isNull);
  });

  test('save then load gives back the same game', () async {
    final prefs = await mockPrefs();
    final storage = GameStorage(prefs);
    final s = buyRig(GameState.newGame(t0), 'cpu', t0)!;
    await storage.save(s);
    expect(storage.load()!.toJson(), s.toJson());
  });

  test('an unreadable save loads as null and is kept aside, not lost',
      () async {
    final prefs = await mockPrefs({GameStorage.key: '{not json'});
    expect(GameStorage(prefs).load(), isNull);
    expect(prefs.getString(GameStorage.corruptKey), '{not json');
    expect(prefs.getString(GameStorage.key), isNull);
  });

  test('valid JSON with the wrong shape is treated as unreadable', () async {
    for (final raw in ['[1, 2, 3]', '{"coins": "lots"}', '42']) {
      final prefs = await mockPrefs({GameStorage.key: raw});
      expect(GameStorage(prefs).load(), isNull, reason: raw);
      expect(prefs.getString(GameStorage.corruptKey), raw);
    }
  });

  test('clear removes the save', () async {
    final prefs = await mockPrefs(savedGame(GameState.newGame(t0)));
    await GameStorage(prefs).clear();
    expect(GameStorage(prefs).load(), isNull);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/game_controller.dart';
import 'package:idle_miner_sim/state/game_storage.dart';
import 'package:idle_miner_sim/state/providers.dart';

import '../support/app_harness.dart';
import '../support/fixtures.dart';

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock(t0));

  GameController controllerOf(ProviderContainer c) =>
      c.read(gameControllerProvider.notifier);

  test('starts and saves a new game when there is no save', () async {
    final prefs = await mockPrefs();
    final c = gameContainer(prefs, clock);
    final s = c.read(gameControllerProvider);
    expect(s.coins, startingCoins);
    expect(s.lastTick, t0);
    expect(storedGame(prefs)!.toJson(), s.toJson());
    expect(c.read(gameControllerProvider.notifier).takeAwayReport(), isNull);
  });

  test('buy upgrades a rig and saves; returns false when unaffordable',
      () async {
    final prefs = await mockPrefs();
    final c = gameContainer(prefs, clock);
    final game = c.read(gameControllerProvider.notifier);

    expect(game.buy('cpu'), isTrue);
    expect(c.read(gameControllerProvider).rigs['cpu'], 1);
    expect(c.read(gameControllerProvider).coins, startingCoins - 50);
    expect(storedGame(prefs)!.rigs['cpu'], 1);

    expect(game.buy('farm'), isFalse);
    expect(c.read(gameControllerProvider).rigs['farm'], 0);
  });

  test('closing and reopening restores coins, rigs and offline earnings',
      () async {
    var prefs = await mockPrefs();
    final first = gameContainer(prefs, clock, autoDispose: false);
    expect(first.read(gameControllerProvider.notifier).buy('cpu'), isTrue);
    final before = first.read(gameControllerProvider);
    first.dispose(); // app closed

    // Only what reached disk survives a restart.
    prefs = await mockPrefs({
      GameStorage.key: prefs.getString(GameStorage.key)!,
    });
    clock.advance(const Duration(hours: 1));
    final second = gameContainer(prefs, clock);
    final after = second.read(gameControllerProvider);

    expect(after.rigs, before.rigs);
    expect(after.coins, closeTo(before.coins + cpuRate * 3600, 1e-6));
    expect(after.lifetimeCoins, closeTo(cpuRate * 3600, 1e-6));
    expect(after.achievements, contains('first_rig'));

    final game = second.read(gameControllerProvider.notifier);
    final report = game.takeAwayReport()!;
    expect(report.coins, closeTo(cpuRate * 3600, 1e-6));
    expect(report.away, const Duration(hours: 1));
    expect(report.capped, isFalse);
    expect(game.takeAwayReport(), isNull, reason: 'shown only once');
  });

  test('a long absence pays the 8 h cap and says so', () async {
    final prefs = await mockPrefs(savedGame(stateWith(rigLevels: {'cpu': 1})));
    clock.advance(const Duration(hours: 10));
    final c = gameContainer(prefs, clock);
    final report = c.read(gameControllerProvider.notifier).takeAwayReport()!;
    expect(report.coins, closeTo(cpuRate * offlineCapSeconds, 1e-6));
    expect(report.capped, isTrue);
    expect(report.away, const Duration(hours: 10));
  });

  test('a short absence still pays but shows no report', () async {
    final prefs = await mockPrefs(savedGame(stateWith(rigLevels: {'cpu': 1})));
    clock.advance(const Duration(seconds: 30));
    final c = gameContainer(prefs, clock);
    expect(c.read(gameControllerProvider).coins,
        closeTo(startingCoins + cpuRate * 30, 1e-9));
    expect(c.read(gameControllerProvider.notifier).takeAwayReport(), isNull);
  });

  test('no rigs means no report, however long the absence', () async {
    final prefs = await mockPrefs(savedGame(GameState.newGame(t0)));
    clock.advance(const Duration(days: 3));
    final c = gameContainer(prefs, clock);
    expect(c.read(gameControllerProvider.notifier).takeAwayReport(), isNull);
  });

  test('a corrupt save starts a new game instead of crashing', () async {
    final prefs = await mockPrefs({GameStorage.key: 'garbage'});
    final c = gameContainer(prefs, clock);
    expect(c.read(gameControllerProvider).coins, startingCoins);
    expect(prefs.getString(GameStorage.corruptKey), 'garbage');
  });

  group('app lifecycle', () {
    test('pause settles and saves; resume pays the background time once',
        () async {
      final prefs = await mockPrefs(savedGame(stateWith(rigLevels: {
        'cpu': 1,
      })));
      final c = gameContainer(prefs, clock);
      final game = controllerOf(c);
      c.read(gameControllerProvider);

      clock.advance(const Duration(seconds: 5));
      game.onPaused();
      expect(storedGame(prefs)!.lastTick, clock.now, reason: 'saved on pause');
      game.onPaused(); // repeated pause is harmless

      clock.advance(const Duration(hours: 2));
      final report = game.onResumed()!;
      expect(report.coins, closeTo(cpuRate * 7200, 1e-6));
      expect(report.away, const Duration(hours: 2));
      expect(c.read(gameControllerProvider).lastTick, clock.now);
      expect(storedGame(prefs)!.lastTick, clock.now, reason: 'saved on resume');

      expect(game.onResumed(), isNull, reason: 'resume without a pause');
    });

    test('a quick trip to the background shows no report', () async {
      final prefs = await mockPrefs(savedGame(stateWith(rigLevels: {
        'cpu': 1,
      })));
      final c = gameContainer(prefs, clock);
      final game = controllerOf(c);
      c.read(gameControllerProvider);
      game.onPaused();
      clock.advance(const Duration(seconds: 20));
      expect(game.onResumed(), isNull);
      expect(c.read(gameControllerProvider).coins,
          closeTo(startingCoins + cpuRate * 20, 1e-9));
    });
  });

  group('settings actions', () {
    test('setPlayerName trims, caps the length and ignores blanks', () async {
      final prefs = await mockPrefs();
      final c = gameContainer(prefs, clock);
      final game = c.read(gameControllerProvider.notifier);

      game.setPlayerName('  Rig Runner  ');
      expect(c.read(gameControllerProvider).playerName, 'Rig Runner');
      expect(storedGame(prefs)!.playerName, 'Rig Runner');

      game.setPlayerName('   ');
      expect(c.read(gameControllerProvider).playerName, 'Rig Runner');

      game.setPlayerName('x' * 50);
      expect(c.read(gameControllerProvider).playerName,
          hasLength(GameController.maxPlayerNameLength));
    });

    test('resetProgress starts over and overwrites the save', () async {
      final prefs = await mockPrefs();
      final c = gameContainer(prefs, clock);
      final game = c.read(gameControllerProvider.notifier);
      game.buy('cpu');
      clock.advance(const Duration(minutes: 5));
      await game.resetProgress();

      final s = c.read(gameControllerProvider);
      expect(s.coins, startingCoins);
      expect(s.rigs.values, everyElement(0));
      expect(s.lastTick, clock.now);
      expect(storedGame(prefs)!.rigs['cpu'], 0);
    });
  });
}

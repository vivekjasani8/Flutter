import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/cloud/cloud_auth.dart';
import 'package:idle_miner_sim/state/cloud/cloud_sync_controller.dart';
import 'package:idle_miner_sim/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/cloud_fakes.dart';
import '../support/fixtures.dart';

void main() {
  late FakeClock clock;
  late FakeCloudAuth auth;
  late FakeCloudStore store;
  late SharedPreferences prefs;

  setUp(() {
    clock = FakeClock(t0);
    auth = FakeCloudAuth();
    store = FakeCloudStore();
  });

  Future<ProviderContainer> open({
    GameState? local,
    bool start = true,
  }) async {
    prefs = await mockPrefs(local == null ? const {} : savedGame(local));
    final c = gameContainer(prefs, clock, cloudAuth: auth, cloudStore: store);
    c.read(cloudSyncProvider); // start listening to the game
    if (start) await c.read(cloudSyncProvider.notifier).start();
    return c;
  }

  CloudSyncState sync(ProviderContainer c) => c.read(cloudSyncProvider);
  GameState game(ProviderContainer c) => c.read(gameControllerProvider);
  CloudSyncController cloud(ProviderContainer c) =>
      c.read(cloudSyncProvider.notifier);

  /// Real progress on another device, with more lifetime coins than any
  /// local test save.
  final bigProgress = stateWith(rigLevels: {'farm': 2, 'cpu': 9})
      .copyWith(lifetimeCoins: 500000, coins: 1234);

  group('connecting', () {
    test('first start signs in a guest and backs up the local game', () async {
      final c = await open(local: stateWith(rigLevels: {'cpu': 1}));
      expect(sync(c).phase, CloudPhase.ready);
      expect(sync(c).user!.isAnonymous, isTrue);
      final uid = sync(c).user!.uid;
      expect(store.docs[uid]!.rigs['cpu'], 1);
      expect(sync(c).lastSyncedAt, t0);
    });

    test('a cloud copy with more progress replaces the local game', () async {
      auth = FakeCloudAuth(
          signedIn: const CloudUser(uid: 'u1', isAnonymous: true));
      store.docs['u1'] = bigProgress;
      final c = await open(local: stateWith(rigLevels: {'cpu': 1}));

      expect(game(c).rigs['farm'], 2);
      expect(game(c).lifetimeCoins, 500000);
      expect(storedGame(prefs)!.rigs['farm'], 2, reason: 'saved on device');
    });

    test('local progress beats an older cloud copy and overwrites it',
        () async {
      auth = FakeCloudAuth(
          signedIn: const CloudUser(uid: 'u1', isAnonymous: true));
      store.docs['u1'] = stateWith().copyWith(lifetimeCoins: 10);
      final c = await open(
          local: stateWith(rigLevels: {'gpu': 3}).copyWith(lifetimeCoins: 999));

      expect(game(c).rigs['gpu'], 3);
      expect(store.docs['u1']!.lifetimeCoins, 999);
    });

    test('offline at start never uploads, then merges once back online',
        () async {
      auth = FakeCloudAuth(
          signedIn: const CloudUser(uid: 'u1', isAnonymous: true));
      store.docs['u1'] = bigProgress;
      store.online = false;
      final c = await open(local: stateWith(coins: 500));

      expect(sync(c).phase, CloudPhase.offline);
      game(c); // keep playing offline
      c.read(gameControllerProvider.notifier).buy('cpu');
      expect(store.saves, 0, reason: 'must not overwrite the real progress');
      expect(store.docs['u1']!.lifetimeCoins, 500000);

      store.online = true;
      await cloud(c).start();
      expect(sync(c).phase, CloudPhase.ready);
      expect(game(c).lifetimeCoins, 500000, reason: 'cloud had more');
    });

    test('no internet on the very first launch: retries on next start',
        () async {
      auth.online = false;
      final c = await open();
      expect(sync(c).phase, CloudPhase.offline);
      expect(sync(c).user, isNull);

      auth.online = true;
      await cloud(c).start();
      expect(sync(c).phase, CloudPhase.ready);
      expect(sync(c).user!.isAnonymous, isTrue);
    });

    test('without a cloud the game just keeps saving on the device', () async {
      prefs = await mockPrefs();
      final c = gameContainer(prefs, clock); // default: unavailable
      await c.read(cloudSyncProvider.notifier).start();
      expect(c.read(cloudSyncProvider).phase, CloudPhase.unavailable);
      expect(c.read(gameControllerProvider.notifier).buy('cpu'), isTrue);
      expect(storedGame(prefs)!.rigs['cpu'], 1);
    });
  });

  group('uploading', () {
    test('at most once a minute while playing, and right away on flush',
        () async {
      final c = await open(local: stateWith(coins: 5000));
      final game = c.read(gameControllerProvider.notifier);
      final uid = sync(c).user!.uid;
      expect(store.saves, 1, reason: 'initial backup');

      game.buy('cpu');
      clock.advance(const Duration(seconds: 30));
      game.buy('cpu');
      expect(store.saves, 1, reason: 'throttled');

      clock.advance(const Duration(seconds: 31));
      game.buy('cpu');
      await pumpEventQueue();
      expect(store.saves, 2);
      expect(store.docs[uid]!.rigs['cpu'], 3);

      game.buy('cpu');
      expect(store.saves, 2);
      await cloud(c).flush(); // app paused
      expect(store.saves, 3);
      expect(store.docs[uid]!.rigs['cpu'], 4);
    });

    test('a failed upload marks offline and is retried later', () async {
      final c = await open(local: stateWith(coins: 5000));
      store.online = false;
      c.read(gameControllerProvider.notifier).buy('gpu');
      await cloud(c).flush();
      expect(sync(c).phase, CloudPhase.offline);

      store.online = true;
      await cloud(c).flush();
      expect(sync(c).phase, CloudPhase.ready);
      expect(store.docs[sync(c).user!.uid]!.rigs['gpu'], 1);
    });
  });

  group('Google sign-in', () {
    test('connecting Google keeps the same player and progress', () async {
      final c = await open(local: stateWith(rigLevels: {'cpu': 4}));
      final guestUid = sync(c).user!.uid;

      final message = await cloud(c).signInWithGoogle();
      expect(message, contains('player@example.com'));
      expect(sync(c).user!.isAnonymous, isFalse);
      expect(sync(c).user!.uid, guestUid);
      expect(store.docs[guestUid]!.rigs['cpu'], 4);
    });

    test(
        'a Google account from another phone: switch, keep the better save, '
        'remove the leftover guest', () async {
      store.docs['phone-1'] = bigProgress;
      auth.googleOwners['player@example.com'] = 'phone-1';
      final c = await open(local: stateWith(rigLevels: {'cpu': 1}));
      final guestUid = sync(c).user!.uid;

      final message = await cloud(c).signInWithGoogle();
      expect(message, contains('most progress'));
      expect(sync(c).user!.uid, 'phone-1');
      expect(game(c).rigs['farm'], 2, reason: 'that account had more');
      expect(store.docs.containsKey(guestUid), isFalse);
      expect(auth.deletedUids, contains(guestUid));
    });

    test('...and if this phone had more progress, it is kept and uploaded',
        () async {
      store.docs['phone-1'] = stateWith().copyWith(lifetimeCoins: 5);
      auth.googleOwners['player@example.com'] = 'phone-1';
      final c = await open(local: bigProgress);

      await cloud(c).signInWithGoogle();
      expect(game(c).lifetimeCoins, 500000);
      expect(store.docs['phone-1']!.lifetimeCoins, 500000);
    });

    test('cancelling the Google picker changes nothing', () async {
      auth.googleCancels = true;
      final c = await open();
      expect(await cloud(c).signInWithGoogle(), isNull);
      expect(sync(c).user!.isAnonymous, isTrue);
      expect(sync(c).busy, isFalse);
    });

    test('an error is reported in plain words', () async {
      final c = await open();
      auth.online = false;
      expect(await cloud(c).signInWithGoogle(), 'No internet connection.');
      expect(sync(c).busy, isFalse);
    });
  });

  group('sign-out and deletion', () {
    test('signing out starts a fresh guest game; Google keeps the progress',
        () async {
      final c = await open(local: stateWith(rigLevels: {'cpu': 6}));
      await cloud(c).signInWithGoogle();
      final googleUid = sync(c).user!.uid;

      await cloud(c).signOut();
      expect(game(c).coins, startingCoins);
      expect(game(c).rigs['cpu'], 0);
      expect(sync(c).user!.isAnonymous, isTrue);
      expect(sync(c).user!.uid, isNot(googleUid));
      expect(store.docs[googleUid]!.rigs['cpu'], 6);
    });

    test('deleting the account removes its cloud save and resets the game',
        () async {
      final c = await open(local: stateWith(rigLevels: {'cpu': 6}));
      await cloud(c).signInWithGoogle();
      final uid = sync(c).user!.uid;

      expect(await cloud(c).deleteAccount(), isNull);
      expect(store.docs.containsKey(uid), isFalse);
      expect(auth.deletedUids, contains(uid));
      expect(game(c).rigs['cpu'], 0);
      expect(sync(c).user!.uid, isNot(uid), reason: 'new guest');
    });

    test('deleting while offline fails safely and keeps progress', () async {
      final c = await open(local: stateWith(rigLevels: {'cpu': 6}));
      final uid = sync(c).user!.uid;
      store.online = false;

      expect(await cloud(c).deleteAccount(), isNotNull);
      expect(game(c).rigs['cpu'], 6);
      expect(sync(c).user!.uid, uid);
      expect(sync(c).busy, isFalse);
    });
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/economy.dart';
import '../providers.dart';
import 'cloud_auth.dart';
import 'cloud_store.dart';

enum CloudPhase {
  /// Signing in / reading the cloud copy.
  connecting,

  /// Signed in and the cloud copy has been reconciled.
  ready,

  /// Couldn't reach the cloud; the game keeps saving on the device and will
  /// sync when back online.
  offline,

  /// No cloud on this device (Firebase didn't start).
  unavailable,
}

class CloudSyncState {
  const CloudSyncState({
    required this.phase,
    this.user,
    this.lastSyncedAt,
    this.busy = false,
  });

  final CloudPhase phase;
  final CloudUser? user;

  /// ms since epoch of the last confirmed upload.
  final int? lastSyncedAt;

  /// A sign-in, sign-out or deletion is in progress.
  final bool busy;

  CloudSyncState copyWith({
    CloudPhase? phase,
    CloudUser? user,
    bool clearUser = false,
    int? lastSyncedAt,
    bool? busy,
  }) =>
      CloudSyncState(
        phase: phase ?? this.phase,
        user: clearUser ? null : (user ?? this.user),
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        busy: busy ?? this.busy,
      );
}

/// Keeps the local game and its cloud copy in step.
///
/// Rules, in order of importance:
/// 1. Never upload before this player's cloud copy has been read, so a phone
///    that starts offline can't overwrite real progress with a fresh game.
/// 2. When both exist, keep the one with more progress ([pickSave]).
/// 3. Upload at most once per [uploadInterval], plus on app pause; Firestore
///    queues writes while offline.
class CloudSyncController extends Notifier<CloudSyncState> {
  static const Duration uploadInterval = Duration(minutes: 1);
  static const Duration uploadTimeout = Duration(seconds: 20);

  CloudAuth get _auth => ref.read(cloudAuthProvider);
  CloudSaveStore get _store => ref.read(cloudStoreProvider);
  int _now() => ref.read(clockProvider)();

  bool _cloudChecked = false;
  bool _dirty = false;
  int _lastUploadAt = 0;
  Future<void>? _connecting;

  @override
  CloudSyncState build() {
    final auth = ref.watch(cloudAuthProvider);
    ref.listen<GameState>(gameControllerProvider, (_, __) => _onGameChanged());
    return CloudSyncState(
      phase: auth.available ? CloudPhase.connecting : CloudPhase.unavailable,
      user: auth.currentUser,
    );
  }

  /// Connect: on app start and whenever the app returns to the foreground.
  /// Safe to call repeatedly.
  Future<void> start() => _connecting ??= _connect().whenComplete(() {
        _connecting = null;
      });

  /// App going to the background: upload now if anything changed.
  Future<void> flush() async {
    if (_dirty) await _upload();
  }

  /// Connect Google so progress follows the player to any phone. Returns a
  /// message to show, or null if there's nothing to say (e.g. cancelled).
  Future<String?> signInWithGoogle() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      if (state.user == null) await start();
      if (state.user == null) {
        return 'Could not connect. Please check your internet and try again.';
      }
      switch (await _auth.linkGoogle()) {
        case GoogleLinkResult.cancelled:
          return null;
        case GoogleLinkResult.linked:
          final user = _auth.currentUser;
          state = state.copyWith(user: user);
          _dirty = true;
          await _upload();
          return 'Signed in as ${_name(user)}. Your progress now follows you '
              'to any phone.';
        case GoogleLinkResult.alreadyInUse:
          // That Google account already has its own progress (e.g. from
          // another phone). Move to it, keep whichever save has more
          // progress, and remove the leftover guest account and its data.
          final guestUid = state.user!.uid;
          await _tryQuietly(() => _store.delete(guestUid));
          await _tryQuietly(_auth.deleteUser);
          final user = await _auth.switchToPendingGoogleAccount();
          state = state.copyWith(user: user);
          _cloudChecked = false;
          await _reconcile(user.uid);
          return 'Signed in as ${_name(user)}. Kept the save with the most '
              'progress.';
      }
    } on CloudException catch (e) {
      return e.message;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// Sign out of Google. The account keeps its progress in the cloud; this
  /// device starts a new guest game until the player signs in again.
  Future<String?> signOut() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      await flush();
      await _auth.signOut();
      await _startOver();
      return 'Signed out. Sign in with Google again to continue that game.';
    } on CloudException catch (e) {
      return e.message;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// Permanently delete the cloud save and the account, and reset the game
  /// on this device. Returns an error message, or null on success.
  Future<String?> deleteAccount() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final uid = state.user?.uid;
      if (uid != null) await _store.delete(uid);
      await _auth.deleteUser();
      await _startOver();
      return null;
    } on CloudException catch (e) {
      return e.message;
    } on Object {
      return 'Could not delete the account. Please check your internet and '
          'try again.';
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  // --- internals ---

  Future<void> _connect() async {
    if (!_auth.available) {
      state = state.copyWith(phase: CloudPhase.unavailable);
      return;
    }
    try {
      final user = _auth.currentUser ?? await _auth.signInAnonymously();
      state = state.copyWith(user: user);
      if (!_cloudChecked) await _reconcile(user.uid);
      state = state.copyWith(phase: CloudPhase.ready);
      if (_dirty) await _upload();
    } on Object {
      state = state.copyWith(phase: CloudPhase.offline);
    }
  }

  /// Read this player's cloud copy, keep the better save, upload the result.
  Future<void> _reconcile(String uid) async {
    final cloud = await _store.load(uid); // throws when offline: rule 1
    final local = ref.read(gameControllerProvider);
    if (cloud != null && !identical(pickSave(local, cloud), local)) {
      ref.read(gameControllerProvider.notifier).replaceWith(cloud);
    }
    _cloudChecked = true;
    _dirty = true;
    await _upload();
  }

  void _onGameChanged() {
    _dirty = true;
    if (state.phase == CloudPhase.ready &&
        _cloudChecked &&
        _now() - _lastUploadAt >= uploadInterval.inMilliseconds) {
      unawaited(_upload());
    }
  }

  Future<void> _upload() async {
    final uid = state.user?.uid;
    if (uid == null || !_cloudChecked) return;
    _dirty = false;
    _lastUploadAt = _now();
    try {
      await _store
          .save(uid, ref.read(gameControllerProvider))
          .timeout(uploadTimeout);
      state = state.copyWith(phase: CloudPhase.ready, lastSyncedAt: _now());
    } on Object {
      // Firestore keeps the write queued; we'll also retry on the next
      // change, pause or resume.
      _dirty = true;
      state = state.copyWith(phase: CloudPhase.offline);
    }
  }

  /// After sign-out or deletion: fresh game, fresh guest account.
  Future<void> _startOver() async {
    _cloudChecked = false;
    _dirty = false;
    state = state.copyWith(clearUser: true, phase: CloudPhase.connecting);
    await ref.read(gameControllerProvider.notifier).resetProgress();
    await start();
  }

  static Future<void> _tryQuietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Best-effort clean-up; never block the player on it.
    }
  }

  static String _name(CloudUser? u) =>
      u?.email ?? u?.displayName ?? 'your Google account';
}

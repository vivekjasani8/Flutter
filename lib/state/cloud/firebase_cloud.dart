import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../engine/economy.dart';
import '../../firebase_options.dart';
import 'cloud_auth.dart';
import 'cloud_store.dart';
import 'firebase_services.dart';
import 'leaderboard_service.dart';

/// Start Firebase, crash reporting and tuned balance. If Firebase fails (no
/// config, unsupported platform), the game still runs: it gets the
/// "unavailable" cloud, built-in balance, and saves on-device only.
///
/// Runs before the game loads, so Remote Config balance is in place before
/// the first save is read.
Future<
    ({
      CloudAuth auth,
      CloudSaveStore store,
      LeaderboardService leaderboard,
    })> startCloud() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await startCrashReporting();
    await loadRemoteEconomy();
    return (
      auth: FirebaseCloudAuth(FirebaseAuth.instance),
      store: FirestoreCloudSaveStore(FirebaseFirestore.instance),
      leaderboard: FirebaseLeaderboardService(FirebaseFirestore.instance),
    );
  } on Object catch (e) {
    debugPrint('Cloud save disabled: $e');
    return (
      auth: const UnavailableCloudAuth(),
      store: const UnavailableCloudSaveStore(),
      leaderboard: const UnavailableLeaderboardService(),
    );
  }
}

/// Guest (anonymous) accounts plus Google sign-in, via Firebase Auth.
class FirebaseCloudAuth implements CloudAuth {
  FirebaseCloudAuth(this._auth);

  final FirebaseAuth _auth;
  bool _googleReady = false;

  /// Google credential kept after "already in use", for the switch.
  AuthCredential? _pending;

  @override
  bool get available => true;

  @override
  CloudUser? get currentUser => _toCloudUser(_auth.currentUser);

  static CloudUser? _toCloudUser(User? u) => u == null
      ? null
      : CloudUser(
          uid: u.uid,
          isAnonymous: u.isAnonymous,
          email: u.email,
          displayName: u.displayName,
        );

  @override
  Future<CloudUser> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      return _toCloudUser(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw _friendly(e);
    }
  }

  /// Show the Google account picker. Null if the player cancelled.
  Future<AuthCredential?> _googleCredential() async {
    final google = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        // On Android the web client id comes from google-services.json.
        await google.initialize();
        _googleReady = true;
      }
      if (!google.supportsAuthenticate()) {
        throw const CloudException(
            'Google sign-in is not supported on this device.');
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const CloudException(
            'Google did not return a sign-in token. Please try again.');
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw CloudException('Google sign-in failed (${e.code.name}).');
    }
  }

  @override
  Future<GoogleLinkResult> linkGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return GoogleLinkResult.cancelled;
    final user = _auth.currentUser;
    try {
      if (user == null) {
        await _auth.signInWithCredential(credential);
      } else {
        await user.linkWithCredential(credential);
      }
      return GoogleLinkResult.linked;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        _pending = e.credential ?? credential;
        return GoogleLinkResult.alreadyInUse;
      }
      throw _friendly(e);
    }
  }

  @override
  Future<CloudUser> switchToPendingGoogleAccount() async {
    final credential = _pending;
    if (credential == null) {
      throw const CloudException('Please sign in with Google again.');
    }
    _pending = null;
    try {
      final result = await _auth.signInWithCredential(credential);
      return _toCloudUser(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw _friendly(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }

  @override
  Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final wasGoogle = !user.isAnonymous;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login' || !wasGoogle) throw _friendly(e);
      // Firebase wants a fresh sign-in before deleting: confirm with Google.
      final credential = await _googleCredential();
      if (credential == null) {
        throw const CloudException('Account deletion was cancelled.');
      }
      try {
        await user.reauthenticateWithCredential(credential);
        await user.delete();
      } on FirebaseAuthException catch (e) {
        throw _friendly(e);
      }
    }
    if (wasGoogle && _googleReady) {
      try {
        await GoogleSignIn.instance.disconnect();
      } on Object {
        // Already deleted on our side; revoking Google access is best-effort.
      }
    }
  }

  static CloudException _friendly(FirebaseAuthException e) =>
      CloudException(switch (e.code) {
        'network-request-failed' =>
          'No internet connection. Please try again when you are online.',
        'operation-not-allowed' ||
        'admin-restricted-operation' =>
          'This sign-in method is turned off in the Firebase console.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        _ => 'Something went wrong (${e.code}). Please try again.',
      });
}

/// Leaderboard via the validateSync Cloud Function (writes) and the
/// read-only `scores` collection (reads).
class FirebaseLeaderboardService implements LeaderboardService {
  FirebaseLeaderboardService(this._db);

  final FirebaseFirestore _db;

  /// Same region as the function and the database (Mumbai).
  static const String region = 'asia-south1';

  @override
  Future<MyStanding> submit(GameState save) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: region)
          .httpsCallable('validateSync')
          .call<Map<String, dynamic>>({'save': save.toJson()});
      final data = result.data;
      return MyStanding(
        score: (data['score'] as num).toInt(),
        rank: (data['rank'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw CloudException(switch (e.code) {
        'not-found' => 'The leaderboard is not live yet.',
        'unauthenticated' => 'Sign in to join the leaderboard.',
        'unavailable' ||
        'deadline-exceeded' ||
        'internal' =>
          'Could not reach the leaderboard. Check your internet and try again.',
        _ => 'The leaderboard is unavailable (${e.code}).',
      });
    }
  }

  @override
  Future<List<LeaderboardEntry>> top({int limit = 100}) async {
    try {
      final snap = await _db
          .collection('scores')
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      return [
        for (final d in snap.docs)
          LeaderboardEntry(
            uid: d.id,
            name: (d.data()['name'] as String?) ?? 'Miner',
            score: ((d.data()['score'] as num?) ?? 0).toInt(),
          ),
      ];
    } on FirebaseException {
      throw const CloudException(
          'Could not load the leaderboard. Check your internet and try again.');
    }
  }
}

/// Saves live at `users/{uid}`; the security rules only let a player read,
/// write or delete their own document.
class FirestoreCloudSaveStore implements CloudSaveStore {
  FirestoreCloudSaveStore(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<GameState?> load(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    final save = snap.data()?['save'];
    if (save is! Map<String, dynamic>) return null;
    return GameState.fromJson(save);
  }

  @override
  Future<void> save(String uid, GameState s) => _doc(uid).set({
        'save': s.toJson(),
        // Top-level copy for the future server-side checks (M4).
        'lifetimeCoins': s.lifetimeCoins,
        'schemaVersion': GameState.schemaVersion,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

  @override
  Future<void> delete(String uid) => _doc(uid).delete();
}

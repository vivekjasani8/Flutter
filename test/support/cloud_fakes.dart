import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/cloud/cloud_auth.dart';
import 'package:idle_miner_sim/state/cloud/cloud_store.dart';

const _offline = CloudException('No internet connection.');

/// In-memory stand-in for Firebase Auth with guest + Google accounts.
class FakeCloudAuth implements CloudAuth {
  FakeCloudAuth({CloudUser? signedIn}) : _user = signedIn;

  bool online = true;

  /// The Google account the picker "returns".
  String googleEmail = 'player@example.com';
  bool googleCancels = false;

  /// Google accounts that already belong to a player: email -> uid.
  final Map<String, String> googleOwners = {};
  final List<String> deletedUids = [];

  CloudUser? _user;
  String? _pendingEmail;
  int _nextId = 1;

  @override
  bool get available => true;

  @override
  CloudUser? get currentUser => _user;

  @override
  Future<CloudUser> signInAnonymously() async {
    if (!online) throw _offline;
    return _user = CloudUser(uid: 'guest-${_nextId++}', isAnonymous: true);
  }

  @override
  Future<GoogleLinkResult> linkGoogle() async {
    if (!online) throw _offline;
    if (googleCancels) return GoogleLinkResult.cancelled;
    final owner = googleOwners[googleEmail];
    if (owner != null && owner != _user?.uid) {
      _pendingEmail = googleEmail;
      return GoogleLinkResult.alreadyInUse;
    }
    final uid = _user?.uid ?? 'google-${_nextId++}';
    _user = CloudUser(uid: uid, isAnonymous: false, email: googleEmail);
    googleOwners[googleEmail] = uid;
    return GoogleLinkResult.linked;
  }

  @override
  Future<CloudUser> switchToPendingGoogleAccount() async {
    final email = _pendingEmail!;
    _pendingEmail = null;
    return _user =
        CloudUser(uid: googleOwners[email]!, isAnonymous: false, email: email);
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteUser() async {
    final u = _user;
    if (u == null) return;
    if (!online) throw _offline;
    deletedUids.add(u.uid);
    googleOwners.removeWhere((_, uid) => uid == u.uid);
    _user = null;
  }
}

/// In-memory stand-in for Firestore `users/{uid}`.
class FakeCloudStore implements CloudSaveStore {
  bool online = true;
  final Map<String, GameState> docs = {};
  int saves = 0;

  @override
  Future<GameState?> load(String uid) async {
    if (!online) throw _offline;
    // Round-trip through JSON like the real store does.
    final s = docs[uid];
    return s == null ? null : GameState.fromJson(s.toJson());
  }

  @override
  Future<void> save(String uid, GameState s) async {
    if (!online) throw _offline;
    saves++;
    docs[uid] = GameState.fromJson(s.toJson());
  }

  @override
  Future<void> delete(String uid) async {
    if (!online) throw _offline;
    docs.remove(uid);
  }
}

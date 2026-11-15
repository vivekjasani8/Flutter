/// Accounts for cloud save, behind an interface so the game and its tests
/// never depend on Firebase directly. `FirebaseCloudAuth` is the real one.
library;

/// A signed-in player.
class CloudUser {
  const CloudUser({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
  });

  final String uid;

  /// A guest account: created automatically, tied to this device until the
  /// player connects Google.
  final bool isAnonymous;
  final String? email;
  final String? displayName;
}

/// A problem worth telling the player about, already in plain words.
class CloudException implements Exception {
  const CloudException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum GoogleLinkResult {
  /// Google is now connected to the current account (same player id).
  linked,

  /// The player closed the Google sign-in sheet.
  cancelled,

  /// That Google account already belongs to another player (e.g. created on
  /// another phone). Call [CloudAuth.switchToPendingGoogleAccount] to use it.
  alreadyInUse,
}

abstract class CloudAuth {
  /// False when the cloud couldn't start on this device; everything else
  /// then throws [CloudException] and the game stays device-only.
  bool get available;

  CloudUser? get currentUser;

  Future<CloudUser> signInAnonymously();

  /// Connect a Google account to the signed-in guest.
  Future<GoogleLinkResult> linkGoogle();

  /// After [GoogleLinkResult.alreadyInUse]: sign in to that Google account.
  Future<CloudUser> switchToPendingGoogleAccount();

  Future<void> signOut();

  /// Permanently delete the signed-in account. May ask the player to confirm
  /// with Google again first.
  Future<void> deleteUser();
}

/// Used when Firebase didn't start (and by default in tests).
class UnavailableCloudAuth implements CloudAuth {
  const UnavailableCloudAuth();

  static const _error =
      CloudException('Cloud save is not available on this device.');

  @override
  bool get available => false;

  @override
  CloudUser? get currentUser => null;

  @override
  Future<CloudUser> signInAnonymously() async => throw _error;

  @override
  Future<GoogleLinkResult> linkGoogle() async => throw _error;

  @override
  Future<CloudUser> switchToPendingGoogleAccount() async => throw _error;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteUser() async => throw _error;
}

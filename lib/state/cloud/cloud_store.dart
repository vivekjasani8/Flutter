import '../../engine/economy.dart';
import 'cloud_auth.dart';

/// One cloud copy of the [GameState] per player id. `FirestoreCloudSaveStore`
/// is the real one.
abstract class CloudSaveStore {
  /// The player's cloud save, or null if they have none yet. Throws when the
  /// cloud can't be reached, so callers never mistake "offline" for "empty".
  Future<GameState?> load(String uid);

  Future<void> save(String uid, GameState s);

  Future<void> delete(String uid);
}

class UnavailableCloudSaveStore implements CloudSaveStore {
  const UnavailableCloudSaveStore();

  static const _error =
      CloudException('Cloud save is not available on this device.');

  @override
  Future<GameState?> load(String uid) async => throw _error;

  @override
  Future<void> save(String uid, GameState s) async => throw _error;

  @override
  Future<void> delete(String uid) async => throw _error;
}

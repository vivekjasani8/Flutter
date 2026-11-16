import '../../engine/economy.dart';
import 'cloud_auth.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.score,
  });

  final String uid;
  final String name;
  final int score;
}

/// The player's own standing, as validated by the server.
class MyStanding {
  const MyStanding({required this.score, required this.rank});

  final int score;
  final int rank;
}

/// The global leaderboard. Scores are only ever written by the server's
/// validateSync function: [submit] sends the save there and gets back the
/// accepted score and rank. `FirebaseLeaderboardService` is the real one.
abstract class LeaderboardService {
  Future<MyStanding> submit(GameState save);

  Future<List<LeaderboardEntry>> top({int limit = 100});
}

class UnavailableLeaderboardService implements LeaderboardService {
  const UnavailableLeaderboardService();

  static const _error =
      CloudException('The leaderboard is not available on this device.');

  @override
  Future<MyStanding> submit(GameState save) async => throw _error;

  @override
  Future<List<LeaderboardEntry>> top({int limit = 100}) async => throw _error;
}

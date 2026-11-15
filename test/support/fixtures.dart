import 'package:idle_miner_sim/engine/config.dart';
import 'package:idle_miner_sim/engine/economy.dart';

/// Fixed epoch ms (2023-11-14T22:13:20Z) so every test is deterministic.
const int t0 = 1700000000000;

const int secondMs = 1000;
const int minuteMs = 60 * secondMs;
const int hourMs = 60 * minuteMs;
const int dayMs = 24 * hourMs;

/// A new game at [t0] with the given rig levels (others stay at 0) and,
/// optionally, a starting balance.
GameState stateWith({Map<String, int> rigLevels = const {}, double? coins}) {
  final s = GameState.newGame(t0);
  return s.copyWith(
    rigs: {...s.rigs, ...rigLevels},
    coins: coins,
  );
}

/// Coins per second for a single level of the CPU rack.
const double cpuRate = 1 * coinsPerThSecond;

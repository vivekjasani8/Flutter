/// Game balance and copy. These are the default values; later milestones move
/// them to Firebase Remote Config so they can be tuned without an app update.
library;

const String appDisclaimer =
    'Idle Miner Sim is a game. All coins, rigs and rankings are virtual. '
    'No real cryptocurrency is mined, earned or paid out, and nothing here is '
    'financial advice.';

const String coinName = 'SimCoin';

/// A type of mining rig the player can buy and level up.
class RigDef {
  const RigDef({
    required this.id,
    required this.name,
    required this.baseHash,
    required this.baseCost,
  });

  final String id;
  final String name;

  /// TH/s contributed per level.
  final double baseHash;

  /// SimCoin cost of level 1.
  final double baseCost;
}

const List<RigDef> rigs = [
  RigDef(id: 'cpu', name: 'CPU Rack', baseHash: 1, baseCost: 50),
  RigDef(id: 'gpu', name: 'GPU Rig', baseHash: 4, baseCost: 400),
  RigDef(id: 'asic_mini', name: 'ASIC Mini', baseHash: 14, baseCost: 3000),
  RigDef(id: 'asic_pro', name: 'ASIC Pro', baseHash: 55, baseCost: 25000),
  RigDef(id: 'farm', name: 'Quantum Farm', baseHash: 200, baseCost: 200000),
];

const double costGrowth = 1.15;
const double coinsPerThSecond = 0.05;
const int offlineCapSeconds = 8 * 3600;
const double boostMultiplier = 2;
const int boostDurationMs = 30 * 60 * 1000;
const int historyHours = 24;
const double startingCoins = 100;

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

const List<AchievementDef> achievements = [
  AchievementDef(
      id: 'first_rig', title: 'Booting Up', description: 'Buy your first rig'),
  AchievementDef(
      id: 'hash_100', title: 'Hash Hundred', description: 'Reach 100 TH/s'),
  AchievementDef(
      id: 'hash_1000', title: 'Terahash Club', description: 'Reach 1,000 TH/s'),
  AchievementDef(
      id: 'coins_10k',
      title: 'Ten Thousand',
      description: 'Earn 10,000 lifetime SimCoin'),
  AchievementDef(
      id: 'coins_1m',
      title: 'Simillionaire',
      description: 'Earn 1,000,000 lifetime SimCoin'),
  AchievementDef(
      id: 'streak_7', title: 'Week Warrior', description: 'Reach a 7 day streak'),
  AchievementDef(
      id: 'all_rigs', title: 'Full Stack', description: 'Own every rig type'),
];

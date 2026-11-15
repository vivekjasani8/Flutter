/// Game balance and copy.
///
/// Balance numbers live in an [EconomyConfig]. [EconomyConfig.defaults] holds
/// the shipped values; at startup the app may swap in a tuned copy from
/// Firebase Remote Config (`useEconomy`), so balance can change without an
/// app update. Every engine function reads the live values through the
/// getters at the bottom of this file. Copy, rig names and achievements are
/// fixed in the app.
library;

import 'dart:convert';

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

  RigDef copyWith({double? baseHash, double? baseCost}) => RigDef(
        id: id,
        name: name,
        baseHash: baseHash ?? this.baseHash,
        baseCost: baseCost ?? this.baseCost,
      );
}

/// Every tunable balance number.
class EconomyConfig {
  const EconomyConfig({
    required this.rigs,
    required this.costGrowth,
    required this.coinsPerThSecond,
    required this.offlineCapSeconds,
    required this.boostMultiplier,
    required this.boostDurationMs,
    required this.startingCoins,
    required this.streakRewardPerDay,
    required this.streakRewardMaxDays,
  });

  /// The shipped balance. The payback simulation tests pin these.
  static const EconomyConfig defaults = EconomyConfig(
    rigs: [
      RigDef(id: 'cpu', name: 'CPU Rack', baseHash: 1, baseCost: 50),
      RigDef(id: 'gpu', name: 'GPU Rig', baseHash: 4, baseCost: 400),
      RigDef(id: 'asic_mini', name: 'ASIC Mini', baseHash: 14, baseCost: 3000),
      RigDef(id: 'asic_pro', name: 'ASIC Pro', baseHash: 55, baseCost: 25000),
      RigDef(id: 'farm', name: 'Quantum Farm', baseHash: 200, baseCost: 200000),
    ],
    costGrowth: 1.15,
    coinsPerThSecond: 0.05,
    offlineCapSeconds: 8 * 3600,
    boostMultiplier: 2,
    boostDurationMs: 30 * 60 * 1000,
    startingCoins: 100,
    streakRewardPerDay: 100,
    streakRewardMaxDays: 7,
  );

  final List<RigDef> rigs;

  /// Each level costs this much more than the last.
  final double costGrowth;
  final double coinsPerThSecond;
  final int offlineCapSeconds;
  final double boostMultiplier;
  final int boostDurationMs;
  final double startingCoins;

  /// Daily reward = this x streak day, up to [streakRewardMaxDays].
  final double streakRewardPerDay;
  final int streakRewardMaxDays;

  /// [base] with any valid values from [json] applied.
  ///
  /// Defensive on purpose: this comes from a console a person types into.
  /// A missing, mistyped or out-of-range value keeps the [base] value, and
  /// unknown keys or rig ids are ignored, so a bad edit can never break the
  /// game.
  factory EconomyConfig.fromJson(
    Map<String, dynamic> json, {
    EconomyConfig base = defaults,
  }) {
    final rigOverrides = json['rigs'];
    return EconomyConfig(
      rigs: [
        for (final r in base.rigs)
          if (rigOverrides is Map && rigOverrides[r.id] is Map)
            r.copyWith(
              baseCost: _number(
                  (rigOverrides[r.id] as Map)['baseCost'], r.baseCost, 1, 1e12),
              baseHash: _number((rigOverrides[r.id] as Map)['baseHash'],
                  r.baseHash, 0.01, 1e9),
            )
          else
            r,
      ],
      costGrowth: _number(json['costGrowth'], base.costGrowth, 1.01, 2),
      coinsPerThSecond:
          _number(json['coinsPerThSecond'], base.coinsPerThSecond, 0.0001, 10),
      offlineCapSeconds: _whole(
          json['offlineCapSeconds'], base.offlineCapSeconds, 3600, 48 * 3600),
      boostMultiplier:
          _number(json['boostMultiplier'], base.boostMultiplier, 1, 10),
      boostDurationMs: _whole(json['boostDurationMs'], base.boostDurationMs,
          60 * 1000, 24 * 3600 * 1000),
      startingCoins: _number(json['startingCoins'], base.startingCoins, 0, 1e6),
      streakRewardPerDay:
          _number(json['streakRewardPerDay'], base.streakRewardPerDay, 1, 1e6),
      streakRewardMaxDays:
          _whole(json['streakRewardMaxDays'], base.streakRewardMaxDays, 1, 30),
    );
  }

  /// Like [EconomyConfig.fromJson] for a JSON string; anything unreadable
  /// gives [base] unchanged.
  static EconomyConfig parse(String source, {EconomyConfig base = defaults}) {
    try {
      final json = jsonDecode(source);
      if (json is Map<String, dynamic>) {
        return EconomyConfig.fromJson(json, base: base);
      }
    } on FormatException {
      // Fall through to the defaults.
    }
    return base;
  }

  Map<String, dynamic> toJson() => {
        'costGrowth': costGrowth,
        'coinsPerThSecond': coinsPerThSecond,
        'offlineCapSeconds': offlineCapSeconds,
        'boostMultiplier': boostMultiplier,
        'boostDurationMs': boostDurationMs,
        'startingCoins': startingCoins,
        'streakRewardPerDay': streakRewardPerDay,
        'streakRewardMaxDays': streakRewardMaxDays,
        'rigs': {
          for (final r in rigs)
            r.id: {'baseCost': r.baseCost, 'baseHash': r.baseHash},
        },
      };

  static double _number(Object? v, double fallback, double min, double max) =>
      v is num && v.isFinite && v >= min && v <= max ? v.toDouble() : fallback;

  static int _whole(Object? v, int fallback, int min, int max) =>
      v is num && v.isFinite && v == v.roundToDouble() && v >= min && v <= max
          ? v.toInt()
          : fallback;
}

EconomyConfig _economy = EconomyConfig.defaults;

/// The balance in effect.
EconomyConfig get economy => _economy;

/// Switch the balance. Call once at startup, before the game loads; tests
/// call it with [EconomyConfig.defaults] to reset.
void useEconomy(EconomyConfig config) => _economy = config;

// Live views of the current balance, so engine code reads naturally.
List<RigDef> get rigs => _economy.rigs;
double get costGrowth => _economy.costGrowth;
double get coinsPerThSecond => _economy.coinsPerThSecond;
int get offlineCapSeconds => _economy.offlineCapSeconds;
double get boostMultiplier => _economy.boostMultiplier;
int get boostDurationMs => _economy.boostDurationMs;
double get startingCoins => _economy.startingCoins;

/// Hours of earnings history kept for the Stats chart (not tunable).
const int historyHours = 24;

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
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Reach a 7 day streak'),
  AchievementDef(
      id: 'all_rigs', title: 'Full Stack', description: 'Own every rig type'),
];

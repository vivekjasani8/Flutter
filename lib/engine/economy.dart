import 'dart:math' as math;

import 'config.dart';

const int _hourMs = 3600 * 1000;

/// Immutable snapshot of a player's game state.
///
/// The engine is pure Dart with no Flutter imports, so it runs in unit tests
/// and can be ported to a Cloud Function that re-validates earnings server-side.
class GameState {
  const GameState({
    required this.coins,
    required this.lifetimeCoins,
    required this.rigs,
    required this.lastTick,
    required this.boostUntil,
    required this.streak,
    required this.lastClaimDay,
    required this.achievements,
    required this.hourly,
    required this.playerName,
  });

  final double coins;
  final double lifetimeCoins;

  /// rig id -> level.
  final Map<String, int> rigs;

  /// ms since epoch of the last settled earnings.
  final int lastTick;

  /// ms since epoch the boost runs until; 0 means none.
  final int boostUntil;
  final int streak;

  /// 'YYYY-MM-DD' (UTC) of the last daily claim, or '' if never.
  final String lastClaimDay;
  final List<String> achievements;

  /// hour-bucket (ms since epoch of the hour start) -> coins earned that hour.
  final Map<int, double> hourly;
  final String playerName;

  GameState copyWith({
    double? coins,
    double? lifetimeCoins,
    Map<String, int>? rigs,
    int? lastTick,
    int? boostUntil,
    int? streak,
    String? lastClaimDay,
    List<String>? achievements,
    Map<int, double>? hourly,
    String? playerName,
  }) {
    return GameState(
      coins: coins ?? this.coins,
      lifetimeCoins: lifetimeCoins ?? this.lifetimeCoins,
      rigs: rigs ?? this.rigs,
      lastTick: lastTick ?? this.lastTick,
      boostUntil: boostUntil ?? this.boostUntil,
      streak: streak ?? this.streak,
      lastClaimDay: lastClaimDay ?? this.lastClaimDay,
      achievements: achievements ?? this.achievements,
      hourly: hourly ?? this.hourly,
      playerName: playerName ?? this.playerName,
    );
  }

  static GameState newGame(int now) {
    return GameState(
      coins: startingCoins,
      lifetimeCoins: 0,
      rigs: _emptyRigs(),
      lastTick: now,
      boostUntil: 0,
      streak: 0,
      lastClaimDay: '',
      achievements: const [],
      hourly: const {},
      playerName: 'Player',
    );
  }

  /// Version of the [toJson] format. Bump it when the shape changes and teach
  /// [fromJson] to read the old version.
  static const int schemaVersion = 1;

  /// JSON-safe map (string keys, plain values), so it can go straight into
  /// `jsonEncode`, shared_preferences or a Firestore document.
  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'coins': coins,
        'lifetimeCoins': lifetimeCoins,
        'rigs': Map<String, int>.from(rigs),
        'lastTick': lastTick,
        'boostUntil': boostUntil,
        'streak': streak,
        'lastClaimDay': lastClaimDay,
        'achievements': List<String>.from(achievements),
        // JSON object keys must be strings.
        'hourly': {
          for (final e in hourly.entries) e.key.toString(): e.value,
        },
        'playerName': playerName,
      };

  /// Inverse of [toJson]. Tolerant of what JSON round-trips do to numbers
  /// (a whole double such as `150.0` can come back as the int `150`) and of
  /// saves made before a rig existed: every configured rig defaults to level 0,
  /// and ids no longer in the config are dropped.
  factory GameState.fromJson(Map<String, dynamic> json) {
    final savedRigs = (json['rigs'] as Map<String, dynamic>?) ?? const {};
    final rigLevels = _emptyRigs();
    for (final id in rigLevels.keys) {
      final level = savedRigs[id];
      if (level is num) rigLevels[id] = level.toInt();
    }

    final savedHourly = (json['hourly'] as Map<String, dynamic>?) ?? const {};
    final hourly = <int, double>{
      for (final e in savedHourly.entries)
        int.parse(e.key): (e.value as num).toDouble(),
    };

    final savedAchievements =
        (json['achievements'] as List<dynamic>?) ?? const [];

    return GameState(
      coins: (json['coins'] as num).toDouble(),
      lifetimeCoins: (json['lifetimeCoins'] as num).toDouble(),
      rigs: rigLevels,
      lastTick: (json['lastTick'] as num).toInt(),
      boostUntil: (json['boostUntil'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      lastClaimDay: (json['lastClaimDay'] as String?) ?? '',
      achievements: [for (final a in savedAchievements) a as String],
      hourly: hourly,
      playerName: (json['playerName'] as String?) ?? 'Player',
    );
  }
}

/// Every configured rig at level 0. Top-level so `rigs` resolves to the config
/// list rather than the [GameState.rigs] field.
Map<String, int> _emptyRigs() => {for (final r in rigs) r.id: 0};

RigDef _rigById(String id) {
  for (final r in rigs) {
    if (r.id == id) return r;
  }
  throw ArgumentError('Unknown rig: $id');
}

/// Cost to buy the next level (currentLevel -> currentLevel + 1).
double rigCost(String id, int currentLevel) {
  return (_rigById(id).baseCost * math.pow(costGrowth, currentLevel))
      .ceilToDouble();
}

double totalHash(GameState s) {
  var sum = 0.0;
  for (final r in rigs) {
    sum += r.baseHash * (s.rigs[r.id] ?? 0);
  }
  return sum;
}

double baseCoinsPerSecond(GameState s) => totalHash(s) * coinsPerThSecond;

bool isBoosted(GameState s, int now) => s.boostUntil > now;

/// Settle earnings from [s.lastTick] to [now].
///
/// - A clock moving backwards earns nothing and does not rewind lastTick.
/// - Elapsed time is capped at [offlineCapSeconds].
/// - The boost multiplier applies only to the part of the window it was active.
GameState tick(GameState s, int now) {
  if (now <= s.lastTick) return s;

  const capMs = offlineCapSeconds * 1000;
  final from = math.max(s.lastTick, now - capMs);
  final base = baseCoinsPerSecond(s);
  final hourly = Map<int, double>.from(s.hourly);

  var earned = 0.0;
  var cursor = from;
  while (cursor < now) {
    final bucket = (cursor ~/ _hourMs) * _hourMs;
    final end = math.min(now, bucket + _hourMs);
    final boostedMs = math.max(0, math.min(end, s.boostUntil) - cursor);
    final plainMs = end - cursor - boostedMs;
    final e = base * (plainMs / 1000 + (boostedMs / 1000) * boostMultiplier);
    earned += e;
    hourly[bucket] = (hourly[bucket] ?? 0) + e;
    cursor = end;
  }

  final minBucket = (now ~/ _hourMs) * _hourMs - (historyHours - 1) * _hourMs;
  hourly.removeWhere((k, _) => k < minBucket);

  return withAchievements(s.copyWith(
    coins: s.coins + earned,
    lifetimeCoins: s.lifetimeCoins + earned,
    lastTick: now,
    hourly: hourly,
  ));
}

/// Coins that settling to [now] would add, without changing [s]. This is the
/// "while you were away" figure: it follows exactly the same rules as [tick]
/// (offline cap, boost window, backwards clock earns 0).
double offlineEarnings(GameState s, int now) {
  if (now <= s.lastTick) return 0;
  return tick(s, now).lifetimeCoins - s.lifetimeCoins;
}

/// Seconds a rig's next level takes to pay for itself from its own output,
/// i.e. cost / (hash gained x coins per TH/s), ignoring boosts.
double paybackSeconds(String id, int currentLevel) {
  final rig = _rigById(id);
  return rigCost(id, currentLevel) / (rig.baseHash * coinsPerThSecond);
}

/// Buy one level of [id]. Returns null if the player cannot afford it.
GameState? buyRig(GameState s, String id, int now) {
  final settled = tick(s, now);
  final level = settled.rigs[id] ?? 0;
  final cost = rigCost(id, level);
  if (settled.coins < cost) return null;
  final nextRigs = Map<String, int>.from(settled.rigs)..[id] = level + 1;
  return withAchievements(settled.copyWith(
    coins: settled.coins - cost,
    rigs: nextRigs,
  ));
}

/// Start (or extend) a boost. Stacked boosts run end to end, never overlap.
GameState activateBoost(GameState s, int now) {
  final settled = tick(s, now);
  final start = math.max(now, settled.boostUntil);
  return settled.copyWith(boostUntil: start + boostDurationMs);
}

String dayKey(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
    .toIso8601String()
    .substring(0, 10);

double streakReward(int streak) => 100.0 * math.min(streak, 7);

/// True only on a UTC day *after* the last claim. Comparing (not just checking
/// "different day") stops a backwards clock from re-claiming: 'YYYY-MM-DD'
/// keys sort chronologically as strings.
bool canClaimDaily(GameState s, int now) =>
    s.lastClaimDay.isEmpty || dayKey(now).compareTo(s.lastClaimDay) > 0;

/// Claim the daily reward. Consecutive UTC days extend the streak; a gap resets
/// it to 1. Returns null if already claimed today, or if the clock reads a day
/// before the last claim.
GameState? claimDaily(GameState s, int now) {
  if (!canClaimDaily(s, now)) return null;
  final settled = tick(s, now);
  final yesterday = dayKey(now - 24 * _hourMs);
  final streak = settled.lastClaimDay == yesterday ? settled.streak + 1 : 1;
  final reward = streakReward(streak);
  return withAchievements(settled.copyWith(
    streak: streak,
    lastClaimDay: dayKey(now),
    coins: settled.coins + reward,
    lifetimeCoins: settled.lifetimeCoins + reward,
  ));
}

List<String> _earnedAchievements(GameState s) {
  final hash = totalHash(s);
  final checks = <String, bool>{
    'first_rig': s.rigs.values.any((l) => l > 0),
    'hash_100': hash >= 100,
    'hash_1000': hash >= 1000,
    'coins_10k': s.lifetimeCoins >= 10000,
    'coins_1m': s.lifetimeCoins >= 1000000,
    'streak_7': s.streak >= 7,
    'all_rigs': rigs.every((r) => (s.rigs[r.id] ?? 0) > 0),
  };
  return achievements
      .where((a) => checks[a.id] ?? false)
      .map((a) => a.id)
      .toList();
}

/// Return [s] with any newly earned achievements appended.
GameState withAchievements(GameState s) {
  final have = s.achievements.toSet();
  final next =
      _earnedAchievements(s).where((id) => !have.contains(id)).toList();
  if (next.isEmpty) return s;
  return s.copyWith(achievements: [...s.achievements, ...next]);
}

/// Score used for rankings: floored lifetime coins, stable to display.
int score(GameState s) => s.lifetimeCoins.floor();

/// Compact number formatting, e.g. 12_500 -> "12.5K", 2_000_000 -> "2.0M".
/// Plain values under 10 keep 2 decimals; suffixed values always show 1.
String formatNumber(double n) {
  final abs = n.abs();
  const units = ['', 'K', 'M', 'B', 'T'];
  var i = 0;
  var v = abs;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  final String out;
  if (i == 0) {
    out = v.toStringAsFixed(v < 10 && v % 1 != 0 ? 2 : 0);
  } else {
    out = v.toStringAsFixed(1);
  }
  return (n < 0 ? '-' : '') + out + units[i];
}

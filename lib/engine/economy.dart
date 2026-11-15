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

/// True when more time has passed since [GameState.lastTick] than the offline
/// cap pays for, i.e. the "while you were away" amount hit its limit.
bool offlineCapped(GameState s, int now) =>
    now - s.lastTick > offlineCapSeconds * 1000;

/// Whether the player can pay for the next level of [id] right now.
bool canAfford(GameState s, String id) =>
    s.coins >= rigCost(id, s.rigs[id] ?? 0);

/// Coins earned in each of the last [historyHours] clock hours, oldest first,
/// ending with the hour that contains [now]. Hours with no earnings are 0, so
/// the list always has exactly [historyHours] entries for a chart.
List<({int hourStart, double coins})> earningsHistory(GameState s, int now) {
  final current = (now ~/ _hourMs) * _hourMs;
  return [
    for (var i = historyHours - 1; i >= 0; i--)
      (
        hourStart: current - i * _hourMs,
        coins: s.hourly[current - i * _hourMs] ?? 0,
      ),
  ];
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
  final streak = nextClaimStreak(settled, now);
  final reward = streakReward(streak);
  return withAchievements(settled.copyWith(
    streak: streak,
    lastClaimDay: dayKey(now),
    coins: settled.coins + reward,
    lifetimeCoins: settled.lifetimeCoins + reward,
  ));
}

const int _dayMs = 24 * _hourMs;

/// Start (00:00 UTC) of the day containing [ms].
int _dayStart(int ms) => (ms ~/ _dayMs) * _dayMs;

/// The streak the player would have after claiming at [now]: one more if they
/// claimed yesterday (UTC), otherwise a fresh start at 1.
int nextClaimStreak(GameState s, int now) =>
    s.lastClaimDay == dayKey(now - _dayMs) ? s.streak + 1 : 1;

/// The streak as it stands at [now]. It survives while the last claim was
/// today or yesterday; after a missed day it reads 0 (the next claim starts
/// again at 1).
int activeStreak(GameState s, int now) {
  if (s.lastClaimDay.isEmpty) return 0;
  return s.lastClaimDay.compareTo(dayKey(now - _dayMs)) >= 0 ? s.streak : 0;
}

/// Milliseconds until the next UTC day starts, when a new claim opens.
int msUntilNextDay(int now) => _dayStart(now) + _dayMs - now;

/// When the rigs' offline storage is full: the last settle plus the cap.
int storageFullAt(GameState s) => s.lastTick + offlineCapSeconds * 1000;

/// When the streak breaks if the player doesn't claim: the end of the UTC day
/// after the last claim. Null if they have never claimed.
int? streakDeadline(GameState s) {
  if (s.lastClaimDay.isEmpty) return null;
  final claimed = DateTime.parse('${s.lastClaimDay}T00:00:00Z');
  return claimed.millisecondsSinceEpoch + 2 * _dayMs;
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

/// Which of two saves of the same player to keep when they meet (e.g. this
/// device's local save and the cloud copy from another phone).
///
/// The one with more **lifetime** coins wins, because that is progress that
/// was actually earned, whereas the balance drops when spending. On a tie the
/// more recent save wins; on a full tie, [local] is kept.
GameState pickSave(GameState local, GameState cloud) {
  if (cloud.lifetimeCoins > local.lifetimeCoins) return cloud;
  if (cloud.lifetimeCoins < local.lifetimeCoins) return local;
  return cloud.lastTick > local.lastTick ? cloud : local;
}

/// Score used for rankings: floored lifetime coins, stable to display.
int score(GameState s) => s.lifetimeCoins.floor();

/// Compact number formatting, e.g. 12_500 -> "12.5K", 2_000_000 -> "2.0M".
/// Plain values under 10 keep 2 decimals; suffixed values always show 1.
///
/// Always rounds **down**, so a balance never reads as more than the player
/// has: 99.5 shows "99" (not "100", which would look affordable for a
/// 100-coin rig) and 999_960 shows "999.9K" (not "1000.0K").
String formatNumber(double n) {
  if (!n.isFinite) return '0';
  const units = ['', 'K', 'M', 'B', 'T'];
  var i = 0;
  var v = n.abs();
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  final int decimals;
  if (i > 0) {
    decimals = 1;
  } else if (v < 10 && _floorTo(v, 2) % 1 != 0) {
    decimals = 2;
  } else {
    decimals = 0;
  }
  final out = _floorTo(v, decimals).toStringAsFixed(decimals);
  return (n < 0 ? '-' : '') + out + units[i];
}

/// [v] rounded down to [decimals] places. The tiny epsilon absorbs float
/// noise such as 0.29 * 100 == 28.999999999999996.
double _floorTo(double v, int decimals) {
  final f = math.pow(10, decimals);
  return (v * f + 1e-9).floor() / f;
}

/// Short human duration, two units at most: "45s", "16m 40s", "5h 33m",
/// "2d 4h". Rounds down to whole seconds; negatives read as "0s".
String formatDuration(double seconds) {
  final total = seconds.isFinite ? math.max(0, seconds.floor()) : 0;
  final d = total ~/ 86400;
  final h = (total % 86400) ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (d > 0) return h > 0 ? '${d}d ${h}h' : '${d}d';
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
  return '${s}s';
}

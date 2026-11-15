import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/economy.dart';
import '../engine/economy.dart' as engine show claimDaily;
import 'game_storage.dart';
import 'providers.dart';

/// What the player earned while the app was closed or in the background.
class AwayReport {
  const AwayReport({
    required this.coins,
    required this.away,
    required this.capped,
  });

  final double coins;
  final Duration away;

  /// True when [away] was longer than the offline cap, so only part of it paid.
  final bool capped;
}

/// Owns the live [GameState]: loads it on start, ticks it every second, and
/// saves it after every action, every [autosaveInterval], and on app pause.
///
/// All game rules stay in `lib/engine`; this class only decides *when* to
/// call them and when to persist.
class GameController extends Notifier<GameState> {
  static const Duration tickInterval = Duration(seconds: 1);
  static const Duration autosaveInterval = Duration(seconds: 10);

  /// Shorter absences don't get a "while you were away" dialog.
  static const Duration minAwayForReport = Duration(minutes: 1);
  static const int maxPlayerNameLength = 20;

  Timer? _timer;
  AwayReport? _launchReport;
  bool _paused = false;
  int _lastSaveAt = 0;

  int _now() => ref.read(clockProvider)();
  GameStorage get _storage => ref.read(gameStorageProvider);

  @override
  GameState build() {
    final now = ref.watch(clockProvider)();
    final storage = ref.watch(gameStorageProvider);
    ref.onDispose(_stopTimer);

    final saved = storage.load();
    _launchReport = saved == null ? null : _reportFor(saved, now);
    final initial = saved == null ? GameState.newGame(now) : tick(saved, now);

    _paused = false;
    _lastSaveAt = now;
    unawaited(storage.save(initial));
    _startTimer();
    return initial;
  }

  /// The "while you were away" report from app launch. Returns it once, then
  /// null, so the dialog is shown a single time.
  AwayReport? takeAwayReport() {
    final report = _launchReport;
    _launchReport = null;
    return report;
  }

  /// Buy the next level of [id]. Returns false if the player can't afford it.
  bool buy(String id) {
    final next = buyRig(state, id, _now());
    if (next == null) return false;
    state = next;
    _save();
    return true;
  }

  /// Claim today's daily reward. Returns the coins paid, or null if it was
  /// already claimed today (or the clock reads a day before the last claim).
  double? claimDaily() {
    final next = engine.claimDaily(state, _now());
    if (next == null) return null;
    state = next;
    _save();
    return streakReward(next.streak);
  }

  void setPlayerName(String name) {
    var trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > maxPlayerNameLength) {
      trimmed = trimmed.substring(0, maxPlayerNameLength);
    }
    state = state.copyWith(playerName: trimmed);
    _save();
  }

  /// Wipe local progress and start a new game.
  Future<void> resetProgress() async {
    _launchReport = null;
    state = GameState.newGame(_now());
    _lastSaveAt = _now();
    await _storage.save(state);
  }

  /// App went to the background: settle earnings, stop ticking, save.
  void onPaused() {
    if (_paused) return;
    _paused = true;
    _stopTimer();
    state = tick(state, _now());
    _save();
  }

  /// App came back: pay what was earned meanwhile and resume ticking.
  /// Returns a report when the absence was long enough to be worth showing.
  AwayReport? onResumed() {
    if (!_paused) return null;
    _paused = false;
    final now = _now();
    final report = _reportFor(state, now);
    state = tick(state, now);
    _save();
    _startTimer();
    return report;
  }

  void _onTick() {
    final now = _now();
    state = tick(state, now);
    if (now - _lastSaveAt >= autosaveInterval.inMilliseconds) _save();
  }

  void _save() {
    _lastSaveAt = _now();
    unawaited(_storage.save(state));
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  AwayReport? _reportFor(GameState before, int now) {
    final awayMs = now - before.lastTick;
    if (awayMs < minAwayForReport.inMilliseconds) return null;
    final coins = offlineEarnings(before, now);
    if (coins <= 0) return null;
    return AwayReport(
      coins: coins,
      away: Duration(milliseconds: awayMs),
      capped: offlineCapped(before, now),
    );
  }
}

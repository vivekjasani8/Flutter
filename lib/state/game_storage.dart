import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/economy.dart';

/// Saves and loads the single local [GameState] as JSON in shared_preferences.
class GameStorage {
  GameStorage(this._prefs);

  /// Where the current save lives.
  static const String key = 'game_state';

  /// Where an unreadable save is moved, so a bad write never silently deletes
  /// a player's progress (it can be inspected or migrated later).
  static const String corruptKey = 'game_state_corrupt';

  final SharedPreferences _prefs;

  /// The saved game, or null if there is none or it cannot be read.
  GameState? load() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return GameState.fromJson(json);
    } on Object {
      // FormatException from bad JSON, TypeError from a wrong shape: fall
      // through and treat the save as unreadable.
    }
    _prefs.setString(corruptKey, raw).ignore();
    _prefs.remove(key).ignore();
    return null;
  }

  Future<void> save(GameState s) async {
    await _prefs.setString(key, jsonEncode(s.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(key);
  }
}

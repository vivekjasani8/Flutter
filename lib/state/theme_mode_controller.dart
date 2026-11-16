import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Appearance chosen in Settings: follow the phone (default), light or dark.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String key = 'theme_mode';

  @override
  ThemeMode build() =>
      switch (ref.watch(sharedPreferencesProvider).getString(key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(key, mode.name);
  }
}

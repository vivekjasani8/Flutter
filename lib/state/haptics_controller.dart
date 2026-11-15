import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Whether vibration feedback is on. Stored on the device; on by default.
class HapticsController extends Notifier<bool> {
  static const String key = 'haptics_enabled';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(key, on);
  }
}

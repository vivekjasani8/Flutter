import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Whether the player has finished the first-launch intro (and so has seen
/// the "this is a game" disclaimer). Stored on the device.
class OnboardingController extends Notifier<bool> {
  static const String key = 'onboarding_done';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(key, true);
  }
}

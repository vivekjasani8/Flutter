import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Vibration feedback for game moments, honouring the Settings switch.
/// Strength grows with how special the moment is.
abstract final class Haptics {
  /// Switching tabs.
  static void tab(WidgetRef ref) => _play(ref, HapticFeedback.selectionClick);

  /// Buying or upgrading a rig.
  static void purchase(WidgetRef ref) => _play(ref, HapticFeedback.lightImpact);

  /// Claiming the daily reward.
  static void reward(WidgetRef ref) => _play(ref, HapticFeedback.mediumImpact);

  /// Unlocking an achievement.
  static void achievement(WidgetRef ref) =>
      _play(ref, HapticFeedback.heavyImpact);

  static void _play(WidgetRef ref, Future<void> Function() feedback) {
    if (ref.read(hapticsProvider)) unawaited(feedback());
  }
}

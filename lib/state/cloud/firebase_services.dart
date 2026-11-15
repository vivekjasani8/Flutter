import 'dart:async';
import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../engine/config.dart';

/// Remote Config parameter holding the [EconomyConfig] JSON. The deployable
/// template is `remoteconfig.template.json` in the project root.
const String economyParameter = 'economy';

/// Apply tuned balance from Remote Config.
///
/// Uses the values fetched on a *previous* launch (instant, works offline),
/// then fetches fresh ones in the background for the next launch, so the
/// balance never changes in the middle of a session. Any problem keeps the
/// built-in [EconomyConfig.defaults].
Future<void> loadRemoteEconomy() async {
  try {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval:
          kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 12),
    ));
    await rc.setDefaults({
      economyParameter: jsonEncode(EconomyConfig.defaults.toJson()),
    });
    await rc.activate();
    useEconomy(EconomyConfig.parse(rc.getString(economyParameter)));
    unawaited(rc.fetch().catchError((Object e) {
      debugPrint('Remote Config fetch failed: $e');
    }));
  } on Object catch (e) {
    debugPrint('Remote Config unavailable, using built-in balance: $e');
  }
}

/// Send crashes to Firebase Crashlytics, in release builds only (debug and
/// test runs on your phone don't pollute the reports).
Future<void> startCrashReporting() async {
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  } on Object catch (e) {
    debugPrint('Crash reporting unavailable: $e');
  }
}

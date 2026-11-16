import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'state/cloud/firebase_cloud.dart';
import 'state/providers.dart';
import 'state/reminder_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final reminders = await LocalReminderScheduler.create();
  // Never blocks the game: if Firebase can't start, saves stay on-device.
  final cloud = await startCloud();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reminderSchedulerProvider.overrideWithValue(reminders),
        cloudAuthProvider.overrideWithValue(cloud.auth),
        cloudStoreProvider.overrideWithValue(cloud.store),
        leaderboardServiceProvider.overrideWithValue(cloud.leaderboard),
      ],
      child: const IdleMinerApp(),
    ),
  );
}

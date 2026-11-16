import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// Shows and cancels reminders. The app talks to this interface; tests use a
/// fake, and [LocalReminderScheduler] talks to the OS.
abstract class ReminderScheduler {
  /// Ask the OS for permission to notify. True if granted.
  Future<bool> requestPermission();

  /// Schedule [reminders], replacing any pending ones with the same ids.
  Future<void> schedule(List<Reminder> reminders);

  /// Cancel pending reminders with these ids.
  Future<void> cancel(List<int> ids);
}

/// Does nothing. Used if the notification plugin fails to start, so the game
/// still runs without reminders.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(List<Reminder> reminders) async {}

  @override
  Future<void> cancel(List<int> ids) async {}
}

/// Real reminders via flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Storage full and daily streak reminders',
      // White fan silhouette (res/drawable-*/ic_notification.png), tinted
      // with the brand gold where Android shows the accent colour.
      icon: 'ic_notification',
      color: Color(0xFFF2B544),
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Initialise the plugin. Falls back to [NoopReminderScheduler] on failure
  /// so a notification problem can never stop the game from starting.
  static Future<ReminderScheduler> create() async {
    try {
      tzdata.initializeTimeZones();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          // Don't prompt on launch; the app asks at the right moment.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return LocalReminderScheduler._(plugin);
    } on Object catch (e) {
      debugPrint('Reminders disabled: $e');
      return const NoopReminderScheduler();
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, r.at),
        notificationDetails: _details,
        // Inexact: may arrive a few minutes late, but needs no special
        // exact-alarm permission (which stores review closely).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
      );
    }
  }

  @override
  Future<void> cancel(List<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/providers.dart';
import 'package:idle_miner_sim/state/reminders.dart';
import 'package:idle_miner_sim/state/reminders_controller.dart';

import '../support/app_harness.dart';
import '../support/fixtures.dart';

void main() {
  late FakeClock clock;
  late FakeReminderScheduler os;
  setUp(() {
    clock = FakeClock(t0);
    os = FakeReminderScheduler();
  });

  final withRigsAndStreak = stateWith(rigLevels: {'cpu': 1})
      .copyWith(lastClaimDay: dayKey(t0), streak: 2);

  test('reminders are off by default and nothing is asked on start', () async {
    final c = gameContainer(await mockPrefs(), clock, reminders: os);
    expect(c.read(remindersProvider), isFalse);
    expect(c.read(remindersProvider.notifier).shouldOfferPrompt, isTrue);
    expect(os.permissionRequests, 0);
  });

  test('enable asks the OS once and remembers the answer', () async {
    final prefs = await mockPrefs();
    final c = gameContainer(prefs, clock, reminders: os);
    expect(await c.read(remindersProvider.notifier).enable(), isTrue);
    expect(c.read(remindersProvider), isTrue);
    expect(os.permissionRequests, 1);
    expect(prefs.getBool(RemindersController.enabledKey), isTrue);
    expect(c.read(remindersProvider.notifier).shouldOfferPrompt, isFalse);
  });

  test('a denied permission leaves reminders off but stops the prompt',
      () async {
    os.grant = false;
    final c = gameContainer(await mockPrefs(), clock, reminders: os);
    expect(await c.read(remindersProvider.notifier).enable(), isFalse);
    expect(c.read(remindersProvider), isFalse);
    expect(c.read(remindersProvider.notifier).shouldOfferPrompt, isFalse);
  });

  test('when on: pause schedules the plan, resume cancels it', () async {
    final c = gameContainer(await mockPrefs(), clock, reminders: os);
    final reminders = c.read(remindersProvider.notifier);
    await reminders.enable();

    await reminders.onAppPaused(withRigsAndStreak, t0);
    expect(os.pending.keys, unorderedEquals(ReminderIds.planned));

    await reminders.onAppResumed();
    expect(os.pending, isEmpty);
  });

  test('when off: pause schedules nothing', () async {
    final c = gameContainer(await mockPrefs(), clock, reminders: os);
    await c.read(remindersProvider.notifier).onAppPaused(withRigsAndStreak, t0);
    expect(os.pending, isEmpty);
  });

  test('disable cancels what was pending', () async {
    final c = gameContainer(await mockPrefs(), clock, reminders: os);
    final reminders = c.read(remindersProvider.notifier);
    await reminders.enable();
    await reminders.onAppPaused(withRigsAndStreak, t0);
    await reminders.disable();
    expect(os.pending, isEmpty);
    expect(c.read(remindersProvider), isFalse);
  });

  test('the debug test reminder survives app pause and resume', () async {
    final c = gameContainer(await mockPrefs(), clock, reminders: os);
    final reminders = c.read(remindersProvider.notifier);
    await reminders.enable();
    await reminders.sendTest(t0);
    expect(os.pending[ReminderIds.test]!.at, t0 + 10000);

    await reminders.onAppPaused(withRigsAndStreak, t0);
    await reminders.onAppResumed();
    expect(os.pending.keys, [ReminderIds.test]);
  });

  test('the on/off choice persists across restarts', () async {
    final prefs = await mockPrefs();
    final first =
        gameContainer(prefs, clock, reminders: os, autoDispose: false);
    await first.read(remindersProvider.notifier).enable();
    first.dispose();

    final second = gameContainer(prefs, clock, reminders: os);
    expect(second.read(remindersProvider), isTrue);
  });
}

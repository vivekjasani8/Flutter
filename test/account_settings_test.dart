import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/economy.dart';

import 'support/app_harness.dart';
import 'support/cloud_fakes.dart';
import 'support/fixtures.dart';

/// Scroll until [f] is built, then fully on screen (not just in the list's
/// off-screen cache), so taps actually land on it.
Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await scrollTo(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late FakeClock clock;
  late FakeCloudAuth auth;
  late FakeCloudStore store;
  setUp(() {
    clock = FakeClock(t0);
    auth = FakeCloudAuth();
    store = FakeCloudStore();
  });

  Future<void> openSettings(WidgetTester tester, {GameState? local}) async {
    await pumpApp(tester, clock,
        cloudAuth: auth,
        cloudStore: store,
        saved: local == null ? const {} : savedGame(local));
    await openTab(tester, 'Settings');
  }

  testWidgets('without a cloud, Settings says progress is on this device',
      (tester) async {
    await pumpApp(tester, clock);
    await openTab(tester, 'Settings');
    await scrollTo(tester, find.byKey(const ValueKey('cloud-unavailable')));
    expect(find.text('Cloud save unavailable'), findsOneWidget);
  });

  testWidgets('a new player is a guest, backed up, with a Google button',
      (tester) async {
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const ValueKey('google-sign-in')));
    expect(find.text('Playing as guest'), findsOneWidget);
    expect(find.textContaining('Synced just now'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-account')), findsOneWidget);
  });

  testWidgets('Sign in with Google shows the account and offers sign-out',
      (tester) async {
    await openSettings(tester);
    await tapAndSettle(tester, find.byKey(const ValueKey('google-sign-in')));

    expect(
        find.textContaining('Signed in as player@example.com'), findsOneWidget);
    expect(find.text('player@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('google-sign-in')), findsNothing);
  });

  testWidgets('sign-out asks first, then starts a new guest game',
      (tester) async {
    await openSettings(tester, local: stateWith(rigLevels: {'cpu': 5}));
    await tapAndSettle(tester, find.byKey(const ValueKey('google-sign-in')));
    await tapAndSettle(tester, find.byKey(const ValueKey('sign-out')));
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Playing as guest'), findsOneWidget);
    expect(liveGame(tester).rigs['cpu'], 0);
  });

  testWidgets('Delete account: cancel keeps everything, confirm deletes',
      (tester) async {
    await openSettings(tester, local: stateWith(rigLevels: {'cpu': 5}));
    final uid = auth.currentUser!.uid;

    await tapAndSettle(tester, find.byKey(const ValueKey('delete-account')));
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.docs.containsKey(uid), isTrue);
    expect(liveGame(tester).rigs['cpu'], 5);

    await tapAndSettle(tester, find.byKey(const ValueKey('delete-account')));
    await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Account deleted'), findsOneWidget);
    expect(store.docs.containsKey(uid), isFalse);
    expect(auth.deletedUids, [uid]);
    expect(liveGame(tester).rigs['cpu'], 0);
  });

  testWidgets('the account section meets the accessibility guidelines',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const ValueKey('delete-account')));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}

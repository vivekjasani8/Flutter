import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/economy.dart';
import '../../state/cloud/cloud_sync_controller.dart';
import '../../state/providers.dart';

/// Settings → Account: who you're playing as, cloud sync status, Google
/// sign-in, sign-out, and permanent account deletion (an App Store
/// requirement for any app with accounts).
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    final now = ref.watch(gameControllerProvider.select((s) => s.lastTick));
    final theme = Theme.of(context);
    final user = cloud.user;

    if (cloud.phase == CloudPhase.unavailable) {
      return const ListTile(
        key: ValueKey('cloud-unavailable'),
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Cloud save unavailable'),
        subtitle: Text('Progress is saved on this device only.'),
      );
    }

    final isGuest = user == null || user.isAnonymous;
    final status = switch (cloud.phase) {
      CloudPhase.connecting => 'Connecting…',
      CloudPhase.offline => 'Offline. Will sync when you are back online.',
      _ => _syncedText(cloud.lastSyncedAt, now),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Account', style: theme.textTheme.titleMedium),
        ),
        ListTile(
          key: const ValueKey('account-status'),
          leading: Icon(isGuest ? Icons.person_outline : Icons.account_circle),
          title: Text(isGuest
              ? 'Playing as guest'
              : (user.email ?? user.displayName ?? 'Google account')),
          subtitle: Text(isGuest
              ? 'Backed up to the cloud. Sign in with Google to keep your '
                  'progress on any phone. $status'
              : 'Signed in with Google. $status'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isGuest
              ? FilledButton.tonalIcon(
                  key: const ValueKey('google-sign-in'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  onPressed: cloud.busy ? null : () => _signIn(context, ref),
                )
              : OutlinedButton.icon(
                  key: const ValueKey('sign-out'),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  onPressed: cloud.busy ? null : () => _signOut(context, ref),
                ),
        ),
        if (cloud.busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (user != null)
          ListTile(
            key: const ValueKey('delete-account'),
            leading: Icon(Icons.delete_forever_outlined,
                color: theme.colorScheme.error),
            title: Text('Delete account',
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle:
                const Text('Permanently delete your cloud save and account'),
            enabled: !cloud.busy,
            onTap: () => _delete(context, ref),
          ),
      ],
    );
  }

  static String _syncedText(int? at, int now) {
    if (at == null) return '';
    final seconds = (now - at) / 1000;
    return seconds < 60
        ? 'Synced just now.'
        : 'Synced ${formatDuration(seconds)} ago.';
  }

  static void _say(BuildContext context, String? message) {
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final message =
        await ref.read(cloudSyncProvider.notifier).signInWithGoogle();
    if (context.mounted) _say(context, message);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      key: 'confirm-sign-out',
      title: 'Sign out?',
      body: 'Your progress stays safe in your Google account. This device '
          'will start a new game until you sign in again.',
      action: 'Sign out',
    );
    if (!ok || !context.mounted) return;
    final message = await ref.read(cloudSyncProvider.notifier).signOut();
    if (context.mounted) _say(context, message);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      key: 'confirm-delete-account',
      title: 'Delete account?',
      body: 'This permanently deletes your account and its cloud save, and '
          'resets the game on this device. It cannot be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final error = await ref.read(cloudSyncProvider.notifier).deleteAccount();
    if (context.mounted) {
      _say(
          context, error ?? 'Account deleted. You are playing as a new guest.');
    }
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String key,
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ValueKey(key),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

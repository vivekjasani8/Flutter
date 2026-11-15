import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/config.dart';
import '../../state/game_controller.dart';
import '../../state/providers.dart';

/// Player name, reminders, progress reset and the "this is a game" disclaimer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final remindersOn = ref.watch(remindersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            key: const ValueKey('edit-name'),
            leading: const Icon(Icons.person_outline),
            title: const Text('Player name'),
            subtitle: Text(s.playerName),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editName(context, ref, s.playerName),
          ),
          SwitchListTile(
            key: const ValueKey('reminders-switch'),
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Reminders'),
            subtitle: const Text('Storage full and streak-at-risk alerts'),
            value: remindersOn,
            onChanged: (on) => _setReminders(context, ref, on),
          ),
          // Debug builds only: check that notifications fire on a phone.
          if (kDebugMode)
            ListTile(
              key: const ValueKey('test-reminder'),
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Send a test reminder'),
              subtitle: const Text('Debug only · arrives in about 10 s'),
              onTap: () => _sendTestReminder(context, ref),
            ),
          ListTile(
            key: const ValueKey('reset-progress'),
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset progress'),
            subtitle: const Text('Start over with a new game on this device'),
            onTap: () => _confirmReset(context, ref),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(appDisclaimer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminders(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    final reminders = ref.read(remindersProvider.notifier);
    if (!on) {
      await reminders.disable();
      return;
    }
    final granted = await reminders.enable();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notifications are blocked for this app. Allow them in '
            'your phone settings, then try again.'),
      ));
    }
  }

  Future<void> _sendTestReminder(BuildContext context, WidgetRef ref) async {
    final reminders = ref.read(remindersProvider.notifier);
    if (!ref.read(remindersProvider) && !await reminders.enable()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Allow notifications first.'),
        ));
      }
      return;
    }
    await reminders.sendTest(ref.read(clockProvider)());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Test reminder scheduled. Leave the app to see it.'),
      ));
    }
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: current),
    );
    if (name != null) {
      ref.read(gameControllerProvider.notifier).setPlayerName(name);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This deletes your $coinName, rigs and achievements on this device. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(gameControllerProvider.notifier).resetProgress();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset. Happy mining!')),
      );
    }
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Player name'),
      content: TextField(
        key: const ValueKey('name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: GameController.maxPlayerNameLength,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-name'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

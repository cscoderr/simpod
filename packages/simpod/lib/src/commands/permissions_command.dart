import 'dart:io';

import 'package:simpod/simpod.dart';

class PermissionsCommand extends SimpodCommand {
  @override
  final String name = 'permissions';

  @override
  final String description = 'Grant, revoke, or reset app permissions';

  static const _actions = {'grant', 'revoke', 'reset'};

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.length < 2) {
      usageException(
        'Usage: simpod permissions <grant|revoke|reset> <service> [bundle_id]\n'
        'Services include: all, camera, photos, location, contacts, '
        'microphone, calendar, reminders, motion, siri.',
      );
    }

    final action = rest[0].toLowerCase();
    if (!_actions.contains(action)) {
      usageException(
        'Invalid action "$action". Expected one of: ${_actions.join(', ')}.',
      );
    }

    final service = rest[1];
    final bundleId = rest.length > 2 ? rest[2] : null;

    // `grant` and `revoke` require a bundle id; `reset` may apply to all apps.
    if (action != 'reset' && bundleId == null) {
      usageException('A bundle_id is required for "$action".');
    }

    final udid = await resolveTargetUdid();
    final result = await SimulatorControl.privacy(
      udid,
      action,
      service,
      bundleId,
    );

    if (result.isSuccess) {
      final target = bundleId ?? 'all apps';
      final past = switch (action) {
        'grant' => 'granted',
        'revoke' => 'revoked',
        _ => 'reset',
      };
      stdout.writeln('Permission "$service" $past for $target on $udid.');
    } else {
      stderr.writeln(
        'Failed to $action "$service": '
        '${result.stderr.isEmpty ? 'simctl privacy failed' : result.stderr}',
      );
      exitCode = 1;
    }
  }
}

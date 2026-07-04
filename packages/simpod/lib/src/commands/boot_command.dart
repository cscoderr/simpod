import 'dart:convert';
import 'dart:io';

import 'package:simpod/simpod.dart';

class BootCommand extends SimpodCommand {
  @override
  final String name = 'boot';

  @override
  final String description = 'Boot a simulator and attach a helper session';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      usageException('Missing device argument. Usage: simpod boot <udid|name>');
    }

    final query = rest.join(' ');
    final device = findDevice(await scanIosDevices(), query);
    if (device == null) {
      usageException(
        'No simulator matched "$query". Run `simpod devices` to list them.',
      );
    }
    final udid = device.udid;

    final result = await SimulatorControl.boot(udid);
    // `Unable to boot device in current state: Booted` is not a real failure.
    if (!result.isSuccess && !result.stderr.contains('current state: Booted')) {
      stderr.writeln(
        result.stderr.isEmpty ? 'simctl boot failed.' : result.stderr,
      );
      exitCode = 1;
      return;
    }

    // No log attachment: this command exits right after printing, and holding
    // the helper's stdio would keep it alive forever.
    final session = await SimpodHelperManager.ensureSession(
      udid,
      attachLogs: false,
    );
    if (session == null) {
      stderr.writeln('Booted $udid but failed to start a helper session.');
      exitCode = 1;
      return;
    }

    if (quiet) {
      stdout.writeln(jsonEncode(session.toJson()..remove('accessToken')));
    } else {
      stdout.writeln('Booted ${device.name} ($udid) — WS: ${session.wsUrl}');
    }
  }
}

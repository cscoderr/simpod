import 'dart:convert';
import 'dart:io';

import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

class DevicesCommand extends SimpodCommand {
  @override
  final String name = 'devices';

  @override
  final String description = 'List available simulators and their state';

  @override
  Future<void> run() async {
    final devices = await scanIosDevices();

    if (quiet) {
      stdout.writeln(jsonEncode(devices.map((d) => d.toJson()).toList()));
      return;
    }

    if (devices.isEmpty) {
      stdout.writeln('No simulators found.');
      return;
    }

    final sessions = {
      for (final s in SimpodSessionManager.readAllSessions()) s.device: s,
    };
    for (final device in devices) {
      final marker = device.state == DeviceState.booted ? '●' : '○';
      final session = sessions[device.udid];
      final suffix = session != null ? '  [session ${session.url}]' : '';
      stdout.writeln(
        '$marker ${device.name}  (${device.udid})  '
        '${device.formattedRuntime}  ${device.state.name}$suffix',
      );
    }
  }
}

import 'dart:io';

import 'package:simpod/simpod.dart';

class ScreenshotCommand extends SimpodCommand {
  ScreenshotCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output file path (defaults to simpod-screenshot-<timestamp>.png)',
      valueHelp: 'file',
    );
  }

  @override
  final String name = 'screenshot';

  @override
  final String description = 'Capture a PNG screenshot of the simulator';

  @override
  Future<void> run() async {
    final udid = await resolveTargetUdid();
    final result = await SimulatorControl.screenshot(udid);
    if (!result.isSuccess) {
      stderr.writeln(
        result.error.isEmpty ? 'simctl screenshot failed.' : result.error,
      );
      exitCode = 1;
      return;
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    final outputPath =
        (argResults?['output'] as String?) ??
        'simpod-screenshot-$timestamp.png';

    saveBytesAndReport(result.bytes!, outputPath, label: 'screenshot');
  }
}

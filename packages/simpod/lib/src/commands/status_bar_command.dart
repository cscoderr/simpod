import 'package:simpod/simpod.dart';

class StatusBarCommand extends SimpodCommand {
  StatusBarCommand() {
    argParser
      ..addOption('battery', help: 'Battery level to show (0-100)')
      ..addOption('time', help: 'Clock time to show (e.g. 9:41)')
      ..addFlag(
        'clear',
        negatable: false,
        help: 'Clear all status bar overrides',
      );
  }

  @override
  final String name = 'status-bar';

  @override
  final String description =
      'Override the status bar (battery, time) or clear it';

  @override
  Future<void> run() async {
    final udid = await resolveTargetUdid();

    if (argResults?['clear'] as bool? ?? false) {
      await reportSimctl(
        SimulatorControl.clearStatusBar(udid),
        successMessage: 'Status bar overrides cleared.',
      );
      return;
    }

    final batteryString = argResults?['battery'] as String?;
    final time = argResults?['time'] as String?;
    if (batteryString == null && time == null) {
      usageException(
        'Nothing to do. Usage: simpod status-bar --battery <0-100> '
        '--time <hh:mm> | --clear',
      );
    }

    int? battery;
    if (batteryString != null) {
      battery = int.tryParse(batteryString);
      if (battery == null || battery < 0 || battery > 100) {
        usageException('--battery must be an integer between 0 and 100.');
      }
    }

    await reportSimctl(
      SimulatorControl.setStatusBarOverride(
        udid,
        batteryLevel: battery,
        time: time,
      ),
      successMessage: 'Status bar overrides applied.',
    );
  }
}

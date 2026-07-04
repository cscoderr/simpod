import 'package:simpod/simpod.dart';

class AppearanceCommand extends SimpodCommand {
  @override
  final String name = 'appearance';

  @override
  final String description = 'Get or set the light/dark appearance';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    final udid = await resolveTargetUdid();

    if (rest.isEmpty) {
      await reportSimctl(SimulatorControl.getAppearance(udid));
      return;
    }

    final theme = rest.first.toLowerCase();
    if (theme != 'light' && theme != 'dark') {
      usageException(
        'Invalid appearance "${rest.first}". Usage: simpod appearance [light|dark]',
      );
    }

    await reportSimctl(
      SimulatorControl.setAppearance(udid, theme),
      successMessage: 'Appearance set to $theme.',
    );
  }
}

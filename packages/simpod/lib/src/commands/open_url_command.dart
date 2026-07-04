import 'package:simpod/simpod.dart';

class OpenUrlCommand extends SimpodCommand {
  @override
  final String name = 'open-url';

  @override
  final String description = 'Open a deep link / https URL on the simulator';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      usageException('Missing URL argument. Usage: simpod open-url <url>');
    }

    final udid = await resolveTargetUdid();
    await reportSimctl(
      SimulatorControl.openUrl(udid, rest.first),
      successMessage: 'Opened ${rest.first}.',
    );
  }
}

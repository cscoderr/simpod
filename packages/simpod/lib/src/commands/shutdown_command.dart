import 'package:simpod/simpod.dart';

class ShutdownCommand extends SimpodCommand {
  @override
  final String name = 'shutdown';

  @override
  final String description = 'Shut a simulator down and stop its helper';

  @override
  Future<void> run() async {
    final udid = await resolveTargetUdid();
    final result = SimulatorControl.shutdown(udid);
    SimpodHelperManager.stopSession(udid);
    await reportSimctl(result, successMessage: 'Shut down $udid.');
  }
}

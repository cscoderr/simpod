import 'dart:async';
import 'dart:io';

import 'package:simpod/simpod.dart';

class LogsCommand extends SimpodCommand {
  LogsCommand() {
    argParser.addOption(
      'seconds',
      help: 'Stop after this many seconds (default: run until Ctrl+C)',
      valueHelp: 'n',
    );
  }

  @override
  final String name = 'logs';

  @override
  final String description = 'Tail the simulator system log';

  @override
  Future<void> run() async {
    final secondsString = argResults?['seconds'] as String?;
    int? seconds;
    if (secondsString != null) {
      seconds = int.tryParse(secondsString);
      if (seconds == null || seconds <= 0) {
        usageException('--seconds must be a positive integer.');
      }
    }

    final udid = await resolveTargetUdid();
    final process = await SimulatorControl.startLogStream(udid);

    final done = Completer<void>();
    void stop() {
      process.kill();
      if (!done.isCompleted) done.complete();
    }

    final sigintSub = ProcessSignal.sigint.watch().listen((_) => stop());
    Timer? timer;
    if (seconds != null) {
      timer = Timer(Duration(seconds: seconds), stop);
    }

    final stdoutDone = stdout.addStream(process.stdout);
    final stderrDone = stderr.addStream(process.stderr);

    final code = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    timer?.cancel();
    await sigintSub.cancel();

    if (!done.isCompleted && code != 0) {
      exitCode = 1;
    }
  }
}

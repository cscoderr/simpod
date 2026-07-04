import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

const int defaultServerPort = 5210;

bool quietMode = false;

Future<void> main(List<String> arguments) async {
  final runner = SimpodCommandRunner();
  try {
    final results = runner.parse(arguments);
    quietMode = results['quiet'] as bool? ?? false;

    if (results['help'] as bool? ?? false) {
      print(runner.usage);
      return;
    }

    if (results['version'] as bool? ?? false) {
      print('simpod $packageVersion');
      return;
    }

    if (results.command != null) {
      await runner.runCommand(results);
      return;
    }

    await runRootOptions(results, runner);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(64);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    print(runner.usage);
    exit(64);
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == 32) exit(0);
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } catch (e, stack) {
    stderr.writeln('Unhandled exception: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

String _jsonEncode(Object? object) =>
    JsonEncoder.withIndent('  ').convert(object);

Future<void> runRootOptions(
  ArgResults results,
  SimpodCommandRunner runner,
) async {
  if (results['list'] as bool? ?? false) {
    final sessions = SimpodSessionManager.readAllSessions();
    if (quietMode) {
      print(
        _jsonEncode(
          sessions.map((s) => s.toJson()..remove('accessToken')).toList(),
        ),
      );
      return;
    }
    if (sessions.isEmpty) {
      print('No running sessions.');
    } else {
      for (final s in sessions) {
        print(
          'Device: ${s.device} (PID: ${s.pid}) -> Web UI: ${s.url}, WS: ${s.wsUrl}',
        );
      }
    }
    return;
  }

  if (results['kill'] as bool? ?? false) {
    final targetDevice = results['device'] as String?;
    if (targetDevice != null) {
      final session = SimpodSessionManager.readSession(targetDevice);
      if (session != null) {
        SimpodHelperManager.stopSession(targetDevice);
      }
      if (quietMode) {
        print(
          _jsonEncode({'stopped': session != null, 'device': targetDevice}),
        );
      } else if (session != null) {
        print('Stopped session for device: $targetDevice');
      } else {
        print('No running session found for device: $targetDevice');
      }
    } else {
      final sessions = SimpodSessionManager.readAllSessions();
      for (final s in sessions) {
        SimpodHelperManager.stopProcess(s.pid);
      }
      SimpodSessionManager.deleteSession(null);
      _stopDetachedPreviewServers();
      if (quietMode) {
        print(jsonEncode({'stopped': sessions.length}));
      } else {
        print('Stopped all sessions.');
      }
    }
    return;
  }

  final String portString = results['port'] as String;
  final int? port = int.tryParse(portString);
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('Error: Invalid --port value "$portString".');
    exit(64);
  }
  final String host = (results['host'] as String?) ?? '127.0.0.1';

  final devices = await resolveDevices(results.rest);
  if (devices.isEmpty) {
    stderr.writeln(
      'Error: No devices specified and no booted iOS simulators detected.',
    );
    exit(1);
  }

  if (!(results['preview'] as bool)) {
    final helperStartPort = results.wasParsed('port')
        ? port
        : defaultHelperPort;
    await runInForeground(devices, helperStartPort);
    return;
  }

  if (results['detach'] as bool) {
    await spawnDetachedPreview(results.arguments, port);
    return;
  }

  await handleServe(port, devices, host);
}

Future<void> spawnDetachedPreview(List<String> originalArgs, int port) async {
  final childArgs = originalArgs.where((a) => a != '--detach').toList();

  final exePath = Platform.resolvedExecutable;
  final runningCompiled =
      p.basenameWithoutExtension(exePath).toLowerCase() != 'dart';

  final executable = exePath;
  final args = runningCompiled
      ? childArgs
      : [Platform.script.toFilePath(), ...childArgs];

  final process = await Process.start(
    executable,
    args,
    mode: ProcessStartMode.detached,
  );

  // Don't report success until the server is actually reachable — the child
  // dies silently if e.g. the port is already bound or no helper can start.
  if (!await _waitForServer(port)) {
    stderr.writeln(
      'Error: Background preview did not come up on port $port '
      '(already in use, or the helper failed to start). '
      'Run `simpod -p $port` in the foreground to see why.',
    );
    exit(1);
  }

  // The child records its own pid once serving; prefer it over the spawned
  // pid so `--kill` targets the right process even after re-execs.
  final pidFile = File(SimpodPaths.previewPidFilePath(port));
  var serverPid = process.pid;
  try {
    serverPid = int.parse(pidFile.readAsStringSync().trim());
  } catch (_) {
    // Fall back to the spawned pid.
  }

  if (quietMode) {
    print(_jsonEncode({'pid': serverPid, 'url': 'http://127.0.0.1:$port'}));
  } else {
    print(
      '\x1B[90mStarted background preview (pid $serverPid):\x1B[0m '
      'http://127.0.0.1:$port',
    );
    print('\x1B[90mStop it with:\x1B[0m simpod --kill');
  }
}

Future<bool> _waitForServer(
  int port, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await isServerHealthy('127.0.0.1', port)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return false;
}

void _stopDetachedPreviewServers() {
  for (final pidFile in SimpodPaths.listPreviewPidFiles()) {
    try {
      final pid = int.tryParse(pidFile.readAsStringSync().trim());
      if (pid != null) SimpodHelperManager.stopProcess(pid);
      pidFile.deleteSync();
    } catch (_) {
      // Best effort; ignore stale or unreadable pid files.
    }
  }
}

Future<List<String>> resolveDevices(List<String> args) async {
  final scanned = await scanIosDevices();
  if (args.isNotEmpty) {
    final resolved = <String>[];
    for (final arg in args) {
      final match = findDevice(scanned, arg);
      if (match == null) {
        stderr.writeln(
          'Error: No simulator matched "$arg". '
          'Run `simpod devices` to list them.',
        );
        exit(1);
      }
      resolved.add(match.udid);
    }
    return resolved;
  }

  final booted = scanned.where((d) => d.state == DeviceState.booted).toList();
  if (booted.isNotEmpty) {
    return [booted.first.udid];
  }

  if (scanned.isEmpty) return [];
  await bootDevice(scanned.first.udid);
  return [scanned.first.udid];
}

Future<void> handleServe(int port, List<String> devices, String host) async {
  final ownedHandles = <HelperHandle>[];
  final sessions = <SimpodSession>[];

  for (final udid in devices) {
    final existing = SimpodSessionManager.readSession(udid);
    if (existing != null) {
      sessions.add(existing);
      continue;
    }
    final handle = await SimpodHelperManager.startHelper(
      udid,
      startPort: defaultHelperPort,
      onLog: (line) {
        if (!quietMode) print('[simpod-server] $line');
      },
    );
    if (handle != null) {
      ownedHandles.add(handle);
      sessions.add(handle.session);
    }
  }

  if (sessions.isEmpty) {
    stderr.writeln(
      'Error: Unable to start a helper session for the preview server.',
    );
    exit(1);
  }

  final accessToken = SimpodSettingsManager.loadOrCreate().accessToken;

  final pidFile = File(SimpodPaths.previewPidFilePath(port));
  var pidFileWritten = false;

  void cleanUp(int exitCode) {
    if (!quietMode) print('\nShutting down...');
    for (final handle in ownedHandles) {
      SimpodHelperManager.stopProcess(handle.process.pid);
      SimpodSessionManager.deleteSession(handle.session.device);
    }
    ownedHandles.clear();
    try {
      if (pidFileWritten && pidFile.existsSync()) pidFile.deleteSync();
    } catch (_) {}
    exit(exitCode);
  }

  try {
    final server = SimpodHttpServer(
      host: host,
      port: port,
      accessToken: accessToken,
    );
    await server.start();
    pidFile.writeAsStringSync('$pid');
    pidFileWritten = true;

    if (quietMode) {
      print(
        _jsonEncode({
          'pid': pid,
          'url': 'http://127.0.0.1:$port',
          'sessions': [
            for (final s in sessions) s.toJson()..remove('accessToken'),
          ],
        }),
      );
    } else {
      await _printServeBanner(host: host, port: port);
    }
  } catch (e) {
    print('Error starting HTTP server: $e');
    cleanUp(1);
  }

  ProcessSignal.sigint.watch().listen((_) => cleanUp(0));
  ProcessSignal.sigterm.watch().listen((_) => cleanUp(0));
  ProcessSignal.sighup.watch().listen((_) => cleanUp(0));

  await Completer<void>().future;
}

Future<void> _printServeBanner({
  required String host,
  required int port,
}) async {
  final networkIP = await getLocalNetworkIPAddress();
  final isExposed =
      host != 'localhost' && host != '::1' && !host.startsWith('127.');

  print("\n");
  print('   - Local: http://127.0.0.1:$port');
  if (networkIP != null && isExposed) {
    print('   - LAN: http://$networkIP:$port');
  } else if (networkIP != null) {
    print(
      '   - LAN:\x1B[90m use --host 0.0.0.0 to expose on http://$networkIP:$port \x1B[0m',
    );
  } else if (host == "0.0.0.0") {
    print('   - LAN:\x1B[31m no LAN connected \x1B[0m');
  } else {
    print('   - LAN:\x1B[90m use --host 0.0.0.0 to expose on LAN \x1B[0m');
  }
  print("\n");
  print(
    '   - Pair a device / show the debug token: \x1B[90msimpod pair\x1B[0m',
  );
  print("\n");
  print('Press Ctrl+C to terminate.');
}

String _sessionLine(SimpodSession s) =>
    'url: ${s.url}, streamUrl: ${s.streamUrl}, wsUrl: ${s.wsUrl}, '
    'port: ${s.port}, device: ${s.device}';

void _printSession(SimpodSession s) {
  if (quietMode) {
    print(_jsonEncode(s.toJson()..remove('accessToken')));
  } else {
    print(_sessionLine(s));
  }
}

Future<void> runInForeground(List<String> udids, int port) async {
  final handles = <HelperHandle>[];

  for (final udid in udids) {
    final existing = SimpodSessionManager.readSession(udid);
    if (existing != null) {
      _printSession(existing);
      continue;
    }
    final handle = await SimpodHelperManager.startHelper(
      udid,
      startPort: port,
      onLog: (line) {
        if (!quietMode) print('[simpod-server] $line');
      },
    );
    if (handle == null) return;
    handles.add(handle);
    _printSession(handle.session);
  }

  if (handles.isEmpty) return;

  void cleanUp(int exitCode) {
    if (!quietMode) print('\nShutting down...');
    for (final handle in handles) {
      SimpodHelperManager.stopProcess(handle.process.pid);
      SimpodSessionManager.deleteSession(handle.session.device);
    }
    handles.clear();
    exit(exitCode);
  }

  ProcessSignal.sigint.watch().listen((_) => cleanUp(0));
  ProcessSignal.sigterm.watch().listen((_) => cleanUp(0));
  ProcessSignal.sighup.watch().listen((_) => cleanUp(0));

  await Completer<void>().future;
}

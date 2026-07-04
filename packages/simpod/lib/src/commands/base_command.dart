import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

abstract class SimpodCommand extends Command<void> {
  SimpodCommand();

  SimpodClient? _client;

  bool get quiet => globalResults?['quiet'] as bool? ?? false;

  Never _multipleSessionsError(List<SimpodSession> sessions) {
    usageException(
      'Multiple simpod sessions are running '
      '(${sessions.map((s) => s.device).join(', ')}). '
      'Target one with --device <udid>.',
    );
  }

  SimpodSession getSession() {
    final deviceUdid = globalResults?['device'] as String?;
    if (deviceUdid != null) {
      final session = SimpodSessionManager.readSession(deviceUdid);
      if (session == null) {
        usageException(
          'No running simpod session found for device: $deviceUdid',
        );
      }
      return session;
    }

    final sessions = SimpodSessionManager.readAllSessions();
    if (sessions.isEmpty) {
      usageException(
        'No active simpod session found. Start the server first with `simpod`.',
      );
    }
    if (sessions.length > 1) _multipleSessionsError(sessions);
    return sessions.first;
  }

  Future<String> resolveTargetUdid() async {
    final deviceUdid = globalResults?['device'] as String?;
    if (deviceUdid != null) return deviceUdid;

    final sessions = SimpodSessionManager.readAllSessions();
    if (sessions.length > 1) _multipleSessionsError(sessions);
    if (sessions.isNotEmpty) return sessions.first.device;

    final booted = (await scanIosDevices())
        .where((d) => d.state == DeviceState.booted)
        .toList();
    if (booted.length == 1) return booted.first.udid;
    if (booted.length > 1) {
      usageException(
        'Multiple simulators are booted. Target one with --device <udid>.',
      );
    }

    usageException(
      'No target device. Use --device <udid> or boot a simulator first.',
    );
  }

  Future<void> reportSimctl(
    Future<SimctlResult> operation, {
    String? successMessage,
  }) async {
    final result = await operation;
    if (result.isSuccess) {
      final message = successMessage ?? result.stdout;
      if (message.isNotEmpty) stdout.writeln(message);
    } else {
      stderr.writeln(
        result.stderr.isEmpty
            ? 'simctl command failed (exit ${result.exitCode}).'
            : result.stderr,
      );
      exitCode = 1;
    }
  }

  /// Writes [bytes] to [outputPath] and reports the result — `{'path': …}`
  /// JSON in quiet mode, a human message otherwise.
  void saveBytesAndReport(
    Uint8List bytes,
    String outputPath, {
    required String label,
  }) {
    try {
      File(outputPath).writeAsBytesSync(bytes);
    } on FileSystemException catch (e) {
      stderr.writeln('Unable to write $outputPath: ${e.message}');
      exitCode = 1;
      return;
    }

    if (quiet) {
      stdout.writeln(jsonEncode({'path': outputPath}));
    } else {
      stdout.writeln('Saved $label to $outputPath');
    }
  }

  SimpodClient get client =>
      _client ??= SimpodClient(wsUrl: getSession().wsUrl);
}

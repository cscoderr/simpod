import 'dart:convert';
import 'dart:io';

import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

const int defaultHelperPort = 5400;

const String helperHost = '127.0.0.1';

class HelperHandle {
  HelperHandle(this.session, this.process);

  final SimpodSession session;
  final Process process;
}

/// * [attached] — child process; stdio is drained and logged.
/// * [detachedWithLogs] — detached, but stdio pipes are held and forwarded to
///   the session log. Only safe from a **long-lived** parent (the preview
///   server): if the parent exits, nobody drains the pipes and the helper
///   eventually blocks on a full stdout buffer.
/// * [detached] — fully detached, no stdio. For short-lived CLI commands
///   (`simpod boot`), which must exit as soon as the helper is up.
enum HelperSpawnMode { attached, detachedWithLogs, detached }

class SimpodHelperManager {
  SimpodHelperManager._();

  static Future<HelperHandle?> startHelper(
    String udid, {
    int startPort = defaultHelperPort,
    HelperSpawnMode mode = HelperSpawnMode.attached,
    void Function(String line)? onLog,
  }) async {
    try {
      final port = await PortScanner.getAvailablePort(startPort);
      final accessToken = SimpodSettingsManager.loadOrCreate().accessToken;
      final process = await Process.start(
        SimpodPaths.helperBinPath(),
        [udid, '--port', port.toString()],
        mode: switch (mode) {
          HelperSpawnMode.attached => ProcessStartMode.normal,
          HelperSpawnMode.detachedWithLogs =>
            ProcessStartMode.detachedWithStdio,
          HelperSpawnMode.detached => ProcessStartMode.detached,
        },
      );

      final baseUrl = 'http://$helperHost:$port';
      final session = SimpodSession(
        pid: process.pid,
        port: port,
        device: udid,
        url: baseUrl,
        accessToken: accessToken,
        streamUrl: '$baseUrl/stream.mjpeg',
        wsUrl: 'ws://$helperHost:$port/ws',
      );
      SimpodSessionManager.writeSession(session);

      if (mode != HelperSpawnMode.detached) {
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              onLog?.call(line);
              SimpodSessionManager.writeSessionLog(udid, '$line\n');
            });
        process.stderr.transform(utf8.decoder).listen((error) {
          SimpodSessionManager.writeSessionLog(udid, '$error\n');
        });
      }

      return HelperHandle(session, process);
    } catch (e) {
      stderr.writeln('Failed to start helper for $udid: $e');
      return null;
    }
  }

  /// [attachLogs] must be `false` when called from a short-lived CLI command:
  /// holding the helper's stdio pipes keeps the command alive forever, and
  /// once it dies the undrained pipes eventually block the helper.
  static Future<SimpodSession?> ensureSession(
    String udid, {
    bool attachLogs = true,
  }) async {
    final existing = SimpodSessionManager.readSession(udid);
    if (existing != null) return existing;

    final handle = await startHelper(
      udid,
      mode: attachLogs
          ? HelperSpawnMode.detachedWithLogs
          : HelperSpawnMode.detached,
    );
    return handle?.session;
  }

  static void stopSession(String udid) {
    final session = SimpodSessionManager.readSession(udid);
    if (session != null) {
      stopProcess(session.pid);
    }
    SimpodSessionManager.deleteSession(udid);
  }

  static void stopProcess(int pid) {
    if (!SimpodSessionManager.isProcessAlive(pid)) return;

    Process.killPid(pid, ProcessSignal.sigterm);

    final deadline = DateTime.now().add(const Duration(milliseconds: 500));
    while (DateTime.now().isBefore(deadline)) {
      if (!SimpodSessionManager.isProcessAlive(pid)) return;
      sleep(const Duration(milliseconds: 25));
    }

    if (SimpodSessionManager.isProcessAlive(pid)) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }
}

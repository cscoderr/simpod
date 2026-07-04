import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

class SimpodSessionManager {
  SimpodSessionManager._();

  static void writeSession(SimpodSession state) {
    try {
      final file = SimpodPaths.sessionFile(state.device);
      file.writeAsStringSync(jsonEncode(state.toJson()));
    } on FileSystemException {
      stderr.writeln('Error: Unable to write session state file.');
    }
  }

  static void writeSessionLog(String device, String log, [bool append = true]) {
    try {
      final file = SimpodPaths.logFile(device);
      file.writeAsStringSync(log, mode: append ? .append : .write);
    } on FileSystemException {
      stderr.writeln('Error: Unable to write session log file.');
    }
  }

  static List<String> listSessionFiles() {
    try {
      final sessionDir = Directory(SimpodPaths.resolveSessionPath());
      if (!sessionDir.existsSync()) return [];
      return sessionDir
          .listSync()
          .where(
            (e) =>
                path.basename(e.path).startsWith('simpod-session-') &&
                e.path.endsWith('.json'),
          )
          .map((e) => e.path)
          .toList();
    } on FileSystemException {
      return [];
    }
  }

  static void deleteSession(String? udid) {
    if (udid != null) {
      try {
        final file = SimpodPaths.sessionFile(udid);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } on FileSystemException {
        stderr.writeln(
          'Error: Unable to delete session file for device: $udid',
        );
      }
    } else {
      for (final filePath in listSessionFiles()) {
        try {
          File(filePath).deleteSync();
        } on FileSystemException {
          stderr.writeln('Error: Unable to delete session file: $filePath');
        }
      }
    }
  }

  static bool isProcessAlive(int pid) {
    try {
      final result = Process.runSync('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the session file when its process is dead, so stale sessions
  /// self-clean on read.
  static SimpodSession? readSessionFile(File file) {
    try {
      if (!file.existsSync()) return null;
      final sessionJson = file.readAsStringSync();
      final session = SimpodSession.fromJson(
        jsonDecode(sessionJson) as Map<String, dynamic>,
      );

      final isAlive = isProcessAlive(session.pid);
      if (!isAlive) {
        file.deleteSync();
        return null;
      }
      return session;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static SimpodSession? readSession(String? udid) {
    if (udid != null) {
      try {
        final sessionFile = SimpodPaths.sessionFile(udid);
        return readSessionFile(sessionFile);
      } on FileSystemException {
        stderr.writeln('Error: Unable to read session file for device: $udid');
        return null;
      }
    }

    for (final filePath in listSessionFiles()) {
      final session = readSessionFile(File(filePath));
      if (session != null) return session;
    }
    return null;
  }

  static List<SimpodSession> readAllSessions() {
    try {
      return listSessionFiles()
          .map((e) => readSessionFile(File(e)))
          .whereType<SimpodSession>()
          .toList();
    } on FileSystemException {
      return [];
    }
  }
}

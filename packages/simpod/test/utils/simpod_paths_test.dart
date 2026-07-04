import 'dart:io';
import 'package:test/test.dart';
import 'package:simpod/src/utils/simpod_paths.dart';

void main() {
  group('SimpodPaths', () {
    test('simpodTempPath is within system temp', () {
      final tempPath = SimpodPaths.simpodTempPath;
      expect(tempPath, startsWith(Directory.systemTemp.path));
      expect(tempPath, endsWith('simpod'));
    });

    test('resolveSessionPath creates the directory if it does not exist', () {
      final sessionPath = SimpodPaths.resolveSessionPath();
      final dir = Directory(sessionPath);
      expect(dir.existsSync(), isTrue);
    });

    test('sessionFilePath returns correct path format', () {
      const udid = '1234-5678-ABCD';
      final sessionPath = SimpodPaths.sessionFilePath(udid);
      expect(sessionPath, endsWith('simpod-session-$udid.json'));
      expect(sessionPath, contains(SimpodPaths.resolveSessionPath()));
    });

    test('logFilePath returns correct path format', () {
      const udid = '1234-5678-ABCD';
      final logPath = SimpodPaths.logFilePath(udid);
      expect(logPath, endsWith('simpod-server-$udid.log'));
      expect(logPath, contains(SimpodPaths.resolveSessionPath()));
    });
  });
}

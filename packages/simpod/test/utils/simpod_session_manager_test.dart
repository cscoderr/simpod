import 'dart:io';

import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';
import 'package:test/test.dart';

void main() {
  group('SimpodSessionManager', () {
    const testUdid = 'test-session-1234';

    setUp(() {
      SimpodSessionManager.deleteSession(testUdid);
    });

    tearDown(() {
      // Clean up after test
      SimpodSessionManager.deleteSession(testUdid);
    });

    test('writeSession and readSession works for an active process', () {
      final session = SimpodSession(
        pid: pid, // Use the current test process PID so isProcessAlive is true
        port: 9999,
        device: testUdid,
        url: 'http://localhost:9999',
        accessToken: 'test-token',
        streamUrl: 'http://localhost:10000',
        wsUrl: 'ws://localhost:9999/ws',
      );

      SimpodSessionManager.writeSession(session);

      final files = SimpodSessionManager.listSessionFiles();
      expect(files.any((f) => f.contains(testUdid)), isTrue);

      final readSession = SimpodSessionManager.readSession(testUdid);
      expect(readSession, isNotNull);
      expect(readSession?.device, equals(testUdid));
      expect(readSession?.pid, equals(pid));
      expect(readSession?.port, equals(9999));
    });

    test('readSession deletes orphaned sessions', () {
      final session = SimpodSession(
        pid: 999999999,
        port: 9999,
        device: testUdid,
        url: 'http://localhost:9999',
        accessToken: 'test-token',
        streamUrl: 'http://localhost:10000',
        wsUrl: 'ws://localhost:9999/ws',
      );

      SimpodSessionManager.writeSession(session);

      final readSession = SimpodSessionManager.readSession(testUdid);
      expect(readSession, isNull, reason: 'Process should not be alive');

      final files = SimpodSessionManager.listSessionFiles();
      expect(
        files.any((f) => f.contains(testUdid)),
        isFalse,
        reason: 'Orphaned session file should be deleted',
      );
    });

    test('deleteSession removes the specific session', () {
      final session = SimpodSession(
        pid: pid,
        port: 9999,
        device: testUdid,
        url: 'http://localhost:9999',
        accessToken: 'test-token',
        streamUrl: 'http://localhost:10000',
        wsUrl: 'ws://localhost:9999/ws',
      );

      SimpodSessionManager.writeSession(session);
      SimpodSessionManager.deleteSession(testUdid);

      final files = SimpodSessionManager.listSessionFiles();
      expect(files.any((f) => f.contains(testUdid)), isFalse);
    });
  });
}

import 'dart:io';

import 'package:simpod/src/utils/port_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('PortScanner', () {
    test(
      'isPortAvailable returns false when a server is already bound to the port',
      () async {
        final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
        final port = server.port;

        final available = await PortScanner.isPortAvailable(port);
        expect(available, isFalse);

        await server.close();
      },
    );

    test('isPortAvailable returns true for an unused port', () async {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final port = server.port;
      await server.close();

      final available = await PortScanner.isPortAvailable(port);
      expect(available, isTrue);
    });

    test('getAvailablePort finds a port that is free', () async {
      final port = await PortScanner.getAvailablePort(45000);
      expect(port, greaterThanOrEqualTo(45000));
      expect(port, lessThan(45100));

      final available = await PortScanner.isPortAvailable(port);
      expect(available, isTrue);
    });
  });
}

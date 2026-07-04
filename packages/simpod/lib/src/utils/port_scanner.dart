import 'dart:io';

import 'package:simpod/simpod.dart';

class PortScanner {
  PortScanner._();

  static Future<bool> isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Best-effort: the probe socket is released before the caller binds, so a
  /// concurrent process can still race for the port. Ports registered in
  /// active sessions are skipped because a helper may not have bound yet.
  static Future<int> getAvailablePort(int start) async {
    final usedPorts = SimpodSessionManager.readAllSessions()
        .map((s) => s.port)
        .toSet();

    for (int port = start; port < start + 100; port++) {
      if (usedPorts.contains(port)) continue;
      if (await isPortAvailable(port)) return port;
    }
    throw Exception('No available port found in range $start-${start + 99}');
  }
}

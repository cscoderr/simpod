import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Probes a preview server's `/api/health` endpoint.
Future<bool> isServerHealthy(String host, int port) async {
  try {
    final response = await http
        .get(Uri.parse('http://$host:$port/api/health'))
        .timeout(const Duration(seconds: 2));
    return response.statusCode == HttpStatus.ok;
  } catch (_) {
    return false;
  }
}

String generateRandomToken() {
  final rand = math.Random.secure();
  final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Prefers a private (RFC 1918) address on `en*` — Ethernet/Wi-Fi on macOS —
/// because VPN tunnels (`utun*`) surface first on some setups and peers on
/// the local network can't reach them.
Future<String?> getLocalNetworkIPAddress() async {
  final interfaces = await NetworkInterface.list(type: .IPv4);
  String? fallback;
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.isLinkLocal || address.isLoopback) continue;
      if (interface.name.startsWith('en') && isPrivateIPv4(address.address)) {
        return address.address;
      }
      fallback ??= address.address;
    }
  }
  return fallback;
}

bool isPrivateIPv4(String address) {
  final octets = address.split('.').map(int.tryParse).toList();
  if (octets.length != 4 || octets.any((o) => o == null)) return false;
  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      (first == 192 && second == 168) ||
      (first == 172 && second >= 16 && second <= 31);
}

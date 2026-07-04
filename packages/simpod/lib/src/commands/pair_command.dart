import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simpod/simpod.dart';

class PairCommand extends SimpodCommand {
  PairCommand() {
    argParser.addFlag(
      'reset',
      negatable: false,
      help:
          'Generate a new access token. Paired devices and running servers '
          'keep using the old one until they restart/re-pair.',
    );
  }

  @override
  final String name = 'pair';

  @override
  final String description = 'Show the pairing QR, deep link, and token';

  @override
  Future<void> run() async {
    var settings = SimpodSettingsManager.loadOrCreate();
    if (argResults?['reset'] as bool? ?? false) {
      settings = settings.copyWith(accessToken: generateRandomToken());
      SimpodSettingsManager.save(settings);
      if (!quiet) {
        stdout.writeln(
          'Access token rotated. Restart any running `simpod` server and '
          're-pair devices.\n',
        );
      }
    }
    final token = settings.accessToken;

    final port = await _findRunningServerPort();
    final lanIp = await getLocalNetworkIPAddress();
    // The server only accepts LAN pairings when it is bound beyond loopback;
    // probing its own LAN address tells us without tracking the bind host.
    final lanReachable =
        port != null && lanIp != null && await isServerHealthy(lanIp, port);

    final localUrl = port == null ? null : 'http://127.0.0.1:$port';
    final pairUrl = port == null
        ? null
        : lanReachable
        ? 'http://$lanIp:$port/pair?t=$token'
        : 'http://127.0.0.1:$port/pair?t=$token';

    if (quiet) {
      stdout.writeln(
        jsonEncode({
          'token': token,
          'url': ?localUrl,
          'pairUrl': ?pairUrl,
          'lanReachable': lanReachable,
        }),
      );
      if (port == null) exitCode = 1;
      return;
    }

    stdout.writeln(
      'Token: $token\n'
      '       \x1B[90m(web dev: flutter run --dart-define=SIMPOD_TOKEN=<token>)\x1B[0m\n',
    );

    if (port == null) {
      stderr.writeln(
        'No preview server is running. Start one first:\n'
        '  simpod                  # local only\n'
        '  simpod --host 0.0.0.0   # allow devices on your network to pair',
      );
      exitCode = 1;
      return;
    }

    stdout.writeln('Pair link: $pairUrl\n');

    if (lanReachable) {
      stdout.writeln('Scan to pair a device on your network:\n');
      stdout.writeln(renderQrAscii(pairUrl!));
    } else {
      stdout.writeln(
        '\x1B[90mThe server is only reachable from this machine — devices on '
        'your network can\'t pair. Restart with `simpod --host 0.0.0.0` to '
        'allow LAN pairing.\x1B[0m',
      );
    }
  }

  /// Finds the port of a healthy preview server by probing the recorded
  /// preview pid files.
  Future<int?> _findRunningServerPort() async {
    for (final pidFile in SimpodPaths.listPreviewPidFiles()) {
      // Filename shape: simpod-preview-<port>.pid
      final name = p.basenameWithoutExtension(pidFile.path);
      final port = int.tryParse(name.replaceFirst('simpod-preview-', ''));
      if (port == null) continue;
      if (await isServerHealthy('127.0.0.1', port)) return port;
    }
    return null;
  }
}

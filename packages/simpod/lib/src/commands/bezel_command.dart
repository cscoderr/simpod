import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:simpod/simpod.dart';

class BezelCommand extends SimpodCommand {
  BezelCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file path (defaults to simpod-bezel-<device>.png)',
        valueHelp: 'file',
      )
      ..addFlag(
        'buttons',
        defaultsTo: true,
        help: 'Include the hardware buttons in the rendered bezel',
      );
  }

  @override
  final String name = 'bezel';

  @override
  final String description = 'Render the device bezel/chrome as a PNG';

  @override
  Future<void> run() async {
    final session = getSession();
    final includeButtons = argResults?['buttons'] as bool? ?? true;
    final uri = Uri.parse('${session.url}/bezel.png?buttons=$includeButtons');

    final http.Response response;
    try {
      response = await http.get(uri);
    } catch (e) {
      stderr.writeln('Unable to reach the helper at ${session.url}: $e');
      exitCode = 1;
      return;
    }
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln(
        'Helper returned ${response.statusCode} for bezel.png '
        '(no bezel assets for this device?).',
      );
      exitCode = 1;
      return;
    }

    final outputPath =
        (argResults?['output'] as String?) ??
        'simpod-bezel-${session.device}.png';
    saveBytesAndReport(response.bodyBytes, outputPath, label: 'bezel');
  }
}

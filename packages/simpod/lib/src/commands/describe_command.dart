import 'dart:io';

import 'package:simpod/simpod.dart';

class DescribeCommand extends SimpodCommand {
  DescribeCommand() {
    argParser.addOption(
      'point',
      help:
          'Describe only the element under a normalized point; pass the x '
          'coordinate here and y as the next argument (or use "x,y")',
      valueHelp: 'x [y]',
    );
  }

  @override
  final String name = 'describe';

  @override
  final String description = 'Dump the accessibility tree (JSON)';

  /// Parses `--point 0.5 0.5` (y lands in the rest args) and `--point 0.5,0.5`.
  (double, double)? _parsePoint() {
    final raw = argResults?['point'] as String?;
    if (raw == null) return null;

    final parts = raw.contains(',')
        ? raw.split(',')
        : [raw, ...?argResults?.rest];
    if (parts.length < 2) {
      usageException(
        'Missing y coordinate. Usage: simpod describe --point <x> <y>',
      );
    }

    final x = double.tryParse(parts[0].trim());
    final y = double.tryParse(parts[1].trim());
    if (x == null || y == null) {
      usageException(
        'Point coordinates must be numeric (normalized 0..1). '
        'Received "${parts[0]}", "${parts[1]}".',
      );
    }
    return (x, y);
  }

  @override
  Future<void> run() async {
    final point = _parsePoint();
    final tree = await client.describeUi(x: point?.$1, y: point?.$2);
    if (tree == null) {
      exitCode = 1;
      return;
    }
    stdout.writeln(tree);
  }
}

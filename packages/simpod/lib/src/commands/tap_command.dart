import 'package:simpod/src/commands/base_command.dart';

class TapCommand extends SimpodCommand {
  @override
  final String name = 'tap';

  @override
  final String description = 'Tap at normalized 0..1 coords';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.length < 2) {
      usageException('Missing coordinate arguments. Usage: simpod tap <x> <y>');
    }

    final xStr = rest[0];
    final yStr = rest[1];

    final x = double.tryParse(xStr);
    final y = double.tryParse(yStr);

    if (x == null || y == null) {
      usageException(
        'Coordinates must be numeric values. Received x: "$xStr", y: "$yStr".',
      );
    }

    await client.sendTap(x, y);
  }
}

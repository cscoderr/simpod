import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

class TypeCommand extends SimpodCommand {
  @override
  final String name = 'type';

  @override
  final String description = 'Type text (US keyboard only)';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      usageException(
        'Missing text argument to type. Usage: simpod type <text>',
      );
    }

    final text = rest.join(' ');
    final events = convertTextToKeyEvents(text);

    await client.sendKeyEvents(events);
  }
}

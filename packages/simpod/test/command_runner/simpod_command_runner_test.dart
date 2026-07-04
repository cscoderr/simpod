import 'package:simpod/simpod.dart';
import 'package:test/test.dart';

void main() {
  group('SimpodCommandRunner', () {
    const documentedCommands = {
      'gesture',
      'tap',
      'button',
      'type',
      'rotate',
      'rotate-left',
      'rotate-right',
      'accessibility',
      'boot',
      'shutdown',
      'devices',
      'appearance',
      'open-url',
      'location',
      'status-bar',
      'permissions',
      'describe',
      'logs',
      'screenshot',
      'bezel',
    };

    test('registers every documented command', () {
      final runner = SimpodCommandRunner();
      for (final command in documentedCommands) {
        expect(
          runner.commands.keys,
          contains(command),
          reason: '`simpod $command` is documented but not registered',
        );
      }
    });

    test('mentions every registered command in the usage text', () {
      final runner = SimpodCommandRunner();
      // Aliases (e.g. a11y) appear in the commands map but not in usage.
      for (final command in runner.commands.keys.where(
        (name) => name != 'help' && runner.commands[name]!.name == name,
      )) {
        expect(
          runner.usage,
          contains(command),
          reason: '`simpod $command` is registered but missing from usage',
        );
      }
    });
  });
}

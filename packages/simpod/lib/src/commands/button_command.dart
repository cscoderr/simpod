import 'dart:io';

import 'package:simpod/simpod.dart';

class ButtonCommand extends SimpodCommand {
  @override
  final String name = 'button';

  @override
  final String description = 'Send a hardware button press';

  /// Button names the helper's `HIDInput.HardwareButton` accepts.
  static const supportedButtons = {
    'home',
    'lock',
    'siri',
    'side_button',
    'app_switcher',
  };

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    final buttonName = rest.isNotEmpty ? rest.first.toLowerCase() : 'home';

    if (buttonName == 'volume_up' || buttonName == 'volume_down') {
      stderr.writeln(
        'Volume buttons can\'t be injected into the iOS Simulator '
        '(CoreSimulator does not route hardware volume events).',
      );
      exitCode = 1;
      return;
    }

    if (!supportedButtons.contains(buttonName)) {
      usageException(
        'Unknown button "$buttonName". Supported buttons: '
        '${supportedButtons.join(', ')}.',
      );
    }

    await client.sendButton(buttonName);
  }
}

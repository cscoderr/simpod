import 'dart:io';

import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

class AccessibilityCommand extends SimpodCommand {
  AccessibilityCommand() {
    argParser
      ..addOption(
        'text-size',
        valueHelp: 'increment|decrement|<size>',
        allowed: supportedTextSizes,
        help: 'Set the Dynamic Type text size',
      )
      ..addFlag('contrast', help: 'Increase Contrast');
    for (final setting in AccessibilitySetting.values) {
      argParser.addFlag(setting.commandName, help: setting.label);
    }
  }

  static const supportedTextSizes = {
    'increment',
    'decrement',
    'extra-small',
    'small',
    'medium',
    'large',
    'extra-large',
    'extra-extra-large',
    'extra-extra-extra-large',
    'accessibility-medium',
    'accessibility-large',
    'accessibility-extra-large',
    'accessibility-extra-extra-large',
    'accessibility-extra-extra-extra-large',
  };

  @override
  final String name = 'accessibility';

  @override
  final List<String> aliases = ['a11y'];

  @override
  final String description =
      'Get or set simulator accessibility settings '
      '(no flags prints the current values)';

  @override
  Future<void> run() async {
    final results = argResults!;
    final udid = await resolveTargetUdid();

    var applied = false;

    final textSize = results['text-size'] as String?;
    if (textSize != null) {
      applied = true;
      await reportSimctl(
        SimulatorControl.setContentSize(udid, textSize),
        successMessage: 'Text size: $textSize.',
      );
    }

    if (results.wasParsed('contrast')) {
      applied = true;
      final value = (results['contrast'] as bool) ? 'enabled' : 'disabled';
      await reportSimctl(
        SimulatorControl.setIncreaseContrast(udid, value),
        successMessage: 'Increase Contrast: $value.',
      );
    }

    for (final setting in AccessibilitySetting.values) {
      if (!results.wasParsed(setting.commandName)) continue;
      applied = true;
      final enabled = results[setting.commandName] as bool;
      await reportSimctl(
        SimulatorControl.setAccessibilitySetting(
          udid,
          setting,
          enabled: enabled,
        ),
        successMessage:
            '${setting.label}: ${enabled ? 'enabled' : 'disabled'}.',
      );
    }

    if (!applied) await _printCurrentValues(udid);
  }

  Future<void> _printCurrentValues(String udid) async {
    final results = await Future.wait([
      SimulatorControl.getContentSize(udid),
      SimulatorControl.getIncreaseContrast(udid),
      for (final setting in AccessibilitySetting.values)
        SimulatorControl.getAccessibilitySetting(udid, setting),
    ]);
    final labels = [
      'Text size',
      'Increase Contrast',
      for (final setting in AccessibilitySetting.values) setting.label,
    ];

    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.isSuccess) {
        stdout.writeln('${labels[i]}: ${result.stdout}');
      } else {
        stderr.writeln(
          result.stderr.isEmpty
              ? 'simctl command failed (exit ${result.exitCode}).'
              : result.stderr,
        );
        exitCode = 1;
      }
    }
  }
}

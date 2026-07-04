import 'dart:io';
import 'dart:typed_data';

import 'package:simpod_core/simpod_core.dart';

class SimctlResult {
  const SimctlResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get isSuccess => exitCode == 0;
}

class ScreenshotResult {
  const ScreenshotResult({required this.exitCode, this.bytes, this.error = ''});

  final int exitCode;
  final Uint8List? bytes;
  final String error;

  bool get isSuccess => exitCode == 0 && bytes != null && bytes!.isNotEmpty;
}

class SimulatorControl {
  SimulatorControl._();

  static Future<SimctlResult> _simctl(List<String> args) async {
    final result = await Process.run('xcrun', ['simctl', ...args]);
    return SimctlResult(
      exitCode: result.exitCode,
      stdout: (result.stdout as String?)?.trim() ?? '',
      stderr: (result.stderr as String?)?.trim() ?? '',
    );
  }

  static Future<SimctlResult> boot(String udid) => _simctl(['boot', udid]);

  static Future<ScreenshotResult> screenshot(String udid) async {
    final tmpDir = Directory.systemTemp.createTempSync('simpod_shot_');
    final file = File('${tmpDir.path}/screenshot.png');
    try {
      final result = await Process.run('xcrun', [
        'simctl',
        'io',
        udid,
        'screenshot',
        '--type=png',
        file.path,
      ]);

      if (result.exitCode != 0) {
        return ScreenshotResult(
          exitCode: result.exitCode,
          error: ((result.stderr as String?) ?? '').trim(),
        );
      }
      if (!file.existsSync()) {
        return ScreenshotResult(
          exitCode: result.exitCode,
          error: 'Screenshot file was not created.',
        );
      }
      return ScreenshotResult(
        exitCode: 0,
        bytes: Uint8List.fromList(file.readAsBytesSync()),
      );
    } finally {
      try {
        tmpDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// The caller owns the returned process and must `kill()` it when the
  /// consumer disconnects.
  static Future<Process> startLogStream(String udid) => Process.start('xcrun', [
    'simctl',
    'spawn',
    udid,
    'log',
    'stream',
    '--style',
    'compact',
  ]);

  static Future<SimctlResult> shutdown(String udid) =>
      _simctl(['shutdown', udid]);

  static Future<SimctlResult> getAppearance(String udid) =>
      _simctl(['ui', udid, 'appearance']);

  static Future<SimctlResult> setAppearance(String udid, String theme) =>
      _simctl(['ui', udid, 'appearance', theme]);

  static Future<SimctlResult> getContentSize(String udid) =>
      _simctl(['ui', udid, 'content_size']);

  static Future<SimctlResult> setContentSize(String udid, String value) =>
      _simctl(['ui', udid, 'content_size', value]);

  static Future<SimctlResult> getIncreaseContrast(String udid) =>
      _simctl(['ui', udid, 'increase_contrast']);

  static Future<SimctlResult> setIncreaseContrast(String udid, String value) =>
      _simctl(['ui', udid, 'increase_contrast', value]);

  static Future<SimctlResult> getAccessibilitySetting(
    String udid,
    AccessibilitySetting setting,
  ) async {
    final result = await _simctl([
      'spawn',
      udid,
      'defaults',
      'read',
      'com.apple.Accessibility',
      setting.defaultsKey,
    ]);

    if (!result.isSuccess && result.stderr.contains('does not exist')) {
      return const SimctlResult(exitCode: 0, stdout: 'disabled', stderr: '');
    }
    if (!result.isSuccess) return result;
    return SimctlResult(
      exitCode: 0,
      stdout: result.stdout == '1' ? 'enabled' : 'disabled',
      stderr: '',
    );
  }

  static Future<SimctlResult> setAccessibilitySetting(
    String udid,
    AccessibilitySetting setting, {
    required bool enabled,
  }) => _simctl([
    'spawn',
    udid,
    'defaults',
    'write',
    'com.apple.Accessibility',
    setting.defaultsKey,
    '-bool',
    '$enabled',
  ]);

  static Future<SimctlResult> openUrl(String udid, String url) =>
      _simctl(['openurl', udid, url]);

  static Future<SimctlResult> setLocation(
    String udid,
    double latitude,
    double longitude,
  ) => _simctl(['location', udid, 'set', '$latitude,$longitude']);

  static Future<SimctlResult> setStatusBarOverride(
    String udid, {
    int? batteryLevel,
    String? time,
  }) => _simctl([
    'status_bar',
    udid,
    'override',
    if (batteryLevel != null) ...[
      '--batteryState',
      'charged',
      '--batteryLevel',
      batteryLevel.toString(),
    ],
    if (time != null) ...['--time', time],
  ]);

  static Future<SimctlResult> clearStatusBar(String udid) =>
      _simctl(['status_bar', udid, 'clear']);

  static Future<SimctlResult> privacy(
    String udid,
    String action,
    String service, [
    String? bundleId,
  ]) => _simctl(['privacy', udid, action, service, ?bundleId]);
}

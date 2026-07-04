import 'dart:convert';
import 'dart:io';

import 'package:simpod_core/simpod_core.dart';

/// Lists the simulators `simctl` knows about, skipping unavailable ones
/// (broken runtimes can't be booted or driven).
Future<List<DeviceInfo>> scanIosDevices() async {
  final result = await Process.run('xcrun', [
    'simctl',
    'list',
    'devices',
    '-j',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('xcrun simctl list failed (exit ${result.exitCode}).');
    return [];
  }
  final json = jsonDecode(result.stdout as String);
  final devices = <DeviceInfo>[];
  for (final entry in (json['devices'] as Map).entries) {
    final runtime = (entry.key as String).replaceAll(
      'com.apple.CoreSimulator.SimRuntime.',
      '',
    );
    final version = runtime.replaceAll('-', '.');
    for (final d in entry.value as List) {
      if (d['isAvailable'] != true) continue;
      devices.add(
        DeviceInfo(
          udid: d['udid'] as String,
          name: d['name'] as String,
          state: DeviceState.fromString(d['state'] as String? ?? ''),
          runtime: version,
        ),
      );
    }
  }
  return devices;
}

/// Matches a simulator by exact udid or case-insensitive name.
DeviceInfo? findDevice(List<DeviceInfo> devices, String query) {
  for (final device in devices) {
    if (device.udid == query ||
        device.name.toLowerCase() == query.toLowerCase()) {
      return device;
    }
  }
  return null;
}

Future<bool> isDeviceBooted(String udid) async {
  final result = await Process.run('xcrun', [
    'simctl',
    'list',
    'devices',
    'booted',
    '-j',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('xcrun simctl list failed (exit ${result.exitCode}).');
    return false;
  }
  final data = jsonDecode(result.stdout as String);
  final devices = data['devices'] as Map<String, dynamic>;
  for (final runtime in devices.values) {
    for (final device in runtime as List) {
      if (device['udid'] == udid) {
        return device['state'] == 'Booted';
      }
    }
  }
  return false;
}

Future<void> bootDevice(String udid) async {
  if (await isDeviceBooted(udid)) return;
  final result = await Process.run('xcrun', ['simctl', 'boot', udid]);
  if (result.exitCode != 0) {
    throw Exception('Failed to boot device $udid: ${result.stderr}');
  }
}

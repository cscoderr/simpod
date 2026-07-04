import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:simpod/simpod.dart';

class UpdateCommand extends SimpodCommand {
  UpdateCommand({PubUpdater? pubUpdater})
    : _pubUpdater = pubUpdater ?? PubUpdater();

  final PubUpdater _pubUpdater;

  static const _packageName = 'simpod';

  @override
  final String name = 'update';

  @override
  final String description = 'Update simpod to the latest version';

  @override
  Future<void> run() async {
    final exe = p.basenameWithoutExtension(Platform.resolvedExecutable);
    if (exe.toLowerCase() != 'dart') {
      stderr.writeln(
        'This is a self-contained build; `update` only applies to pub '
        'installs. Reinstall with `dart pub global activate simpod`, or '
        'rebuild from source with ./build.sh.',
      );
      exitCode = 1;
      return;
    }

    final String latestVersion;
    try {
      latestVersion = await _pubUpdater.getLatestVersion(_packageName);
    } catch (e) {
      stderr.writeln('Unable to check for updates: $e');
      exitCode = 1;
      return;
    }

    if (Version.parse(packageVersion) >= Version.parse(latestVersion)) {
      stdout.writeln('simpod is already up to date ($packageVersion).');
      return;
    }

    stdout.writeln('Updating simpod $packageVersion -> $latestVersion...');
    try {
      await _pubUpdater.update(packageName: _packageName);
    } catch (e) {
      stderr.writeln('Update failed: $e');
      exitCode = 1;
      return;
    }
    stdout.writeln('Updated to $latestVersion.');
  }
}

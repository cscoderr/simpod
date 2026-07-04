import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:simpod/src/utils/embedded_assets.dart';

class SimpodPaths {
  SimpodPaths._();

  static Directory get systemTempDirectory => Directory.systemTemp;

  static Directory get currentWorkingDirectory => Directory.current;

  static String get simpodTempPath =>
      path.join(systemTempDirectory.path, 'simpod');

  static Directory get simpodTempDirectory => Directory(simpodTempPath);

  static String resolveSessionPath() {
    final dir = simpodTempDirectory;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  static String sessionFilePath(String udid) {
    return path.join(resolveSessionPath(), 'simpod-session-$udid.json');
  }

  static String settingsFilePath() {
    return path.join(resolveSessionPath(), 'settings.json');
  }

  static File sessionFile(String udid) {
    return File(sessionFilePath(udid));
  }

  static File logFile(String udid) {
    return File(logFilePath(udid));
  }

  static File frontendIndexFile() {
    return File(path.join(flutterWebBuildPath, 'index.html'));
  }

  static String logFilePath(String udid) {
    return path.join(resolveSessionPath(), 'simpod-server-$udid.log');
  }

  /// Records the last orientation the CLI set, so `rotate-left`/`rotate-right`
  /// can compute quarter turns — the helper has no "get orientation" call.
  static File orientationFile(String udid) {
    return File(path.join(resolveSessionPath(), 'simpod-orientation-$udid'));
  }

  static String previewPidFilePath(int port) {
    return path.join(resolveSessionPath(), 'simpod-preview-$port.pid');
  }

  static List<File> listPreviewPidFiles() {
    final dir = Directory(resolveSessionPath());
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              path.basename(f.path).startsWith('simpod-preview-') &&
              f.path.endsWith('.pid'),
        )
        .toList();
  }

  /// Resolved from the entry script rather than the working directory so
  /// dev-mode (`dart run`) works from anywhere; snapshot launchers don't
  /// match the package layout and fall back to the working directory.
  static String get _sourcePackageRoot {
    try {
      final script = File.fromUri(Platform.script);
      final root = script.parent.parent.path;
      if (File(path.join(root, 'pubspec.yaml')).existsSync() &&
          Directory(path.join(root, 'lib')).existsSync()) {
        return root;
      }
    } catch (_) {}
    return currentWorkingDirectory.path;
  }

  static String helperBinPath() {
    if (EmbeddedAssets.isAvailable) return EmbeddedAssets.helperBinPath;
    return path.join(_sourcePackageRoot, 'lib', 'bin', 'simpod-helper-bin');
  }

  static String get flutterWebBuildPath {
    if (EmbeddedAssets.isAvailable) return EmbeddedAssets.webBuildPath;
    return path.join(simpodClientPath, 'build', 'web');
  }

  static String get simpodClientPath {
    final packagesRoot = path.canonicalize(path.join(_sourcePackageRoot, '..'));
    return path.join(packagesRoot, 'simpod_client');
  }
}

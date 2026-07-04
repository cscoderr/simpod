import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:simpod/src/gen/embedded_assets.g.dart';

/// Resolves the helper binary and Flutter web build that are embedded inside a
/// release `dart compile exe` binary.
class EmbeddedAssets {
  EmbeddedAssets._();

  static bool get isAvailable => kHasEmbeddedAssets;

  static Directory? _root;

  static Directory ensureExtracted() {
    final cached = _root;
    if (cached != null) return cached;

    final dir = Directory(
      path.join(
        Directory.systemTemp.path,
        'simpod-bundle-$kEmbeddedAssetsVersion',
      ),
    );
    final marker = File(path.join(dir.path, '.ready'));

    if (marker.existsSync()) {
      _root = dir;
      return dir;
    }

    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final gzipped = base64Decode(kEmbeddedAssetsGzipBase64.join());
    final tarBytes = GZipDecoder().decodeBytes(gzipped);
    final archive = TarDecoder().decodeBytes(tarBytes);

    for (final file in archive) {
      if (!file.isFile) continue;
      final out = File(path.join(dir.path, file.name));
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(file.content as List<int>);
    }

    // The helper binary loses its executable bit when packed into a tar entry;
    // restore it (macOS-only toolchain).
    final bin = File(path.join(dir.path, 'bin', 'simpod-helper-bin'));
    if (bin.existsSync()) {
      Process.runSync('chmod', ['+x', bin.path]);
    }

    marker.writeAsStringSync('ok');
    _root = dir;
    return dir;
  }

  static String get helperBinPath =>
      path.join(ensureExtracted().path, 'bin', 'simpod-helper-bin');

  static String get webBuildPath => path.join(ensureExtracted().path, 'web');
}

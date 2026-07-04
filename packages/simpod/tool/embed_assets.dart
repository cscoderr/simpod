import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

const String _genPath = 'lib/src/gen/embedded_assets.g.dart';
const String _helperBinPath = 'lib/bin/simpod-helper-bin';
const String _webBuildPath = '../simpod_client/build/web';
const int _chunkSize = 1024 * 1024; // base64 chars per chunk

void main(List<String> args) {
  if (args.contains('--stub')) {
    File(_genPath).writeAsStringSync(_stubContents());
    stdout.writeln('Wrote stub -> $_genPath');
    return;
  }

  final helperBin = File(_helperBinPath);
  if (!helperBin.existsSync()) {
    stderr.writeln('Missing helper binary: $_helperBinPath');
    exit(1);
  }
  final webDir = Directory(_webBuildPath);
  if (!webDir.existsSync()) {
    stderr.writeln('Missing Flutter web build: $_webBuildPath');
    exit(1);
  }

  final archive = Archive();

  final binBytes = helperBin.readAsBytesSync();
  archive.addFile(
    ArchiveFile('bin/simpod-helper-bin', binBytes.length, binBytes)
      ..mode = 0x1ED, // 0o755 - equivalent to chmod +x bin/simpod-helper-bin
  );

  var fileCount = 0;
  for (final entity in webDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = path.relative(entity.path, from: webDir.path);
    final bytes = entity.readAsBytesSync();
    archive.addFile(ArchiveFile('web/$rel', bytes.length, bytes));
    fileCount++;
  }

  final tarBytes = TarEncoder().encode(archive);
  final gzBytes = GZipEncoder().encode(tarBytes);
  if (gzBytes == null) {
    stderr.writeln('Failed to gzip embedded payload.');
    exit(1);
  }

  final b64 = base64Encode(gzBytes);
  final chunks = <String>[];
  for (var i = 0; i < b64.length; i += _chunkSize) {
    chunks.add(
      b64.substring(
        i,
        i + _chunkSize > b64.length ? b64.length : i + _chunkSize,
      ),
    );
  }

  // Deterministic per-payload version, so the runtime reuses an extraction for
  // the same binary but re-extracts when the bundle changes.
  var checksum = 0;
  for (final b in gzBytes) {
    checksum = (checksum * 31 + b) & 0x7fffffff;
  }
  final version = '${gzBytes.length}-${checksum.toRadixString(16)}';

  File(_genPath).writeAsStringSync(_realContents(version, chunks));

  final mb = (gzBytes.length / (1024 * 1024)).toStringAsFixed(1);
  stdout.writeln(
    'Embedded helper bin + $fileCount web files '
    '(${mb}MB gzipped, ${chunks.length} chunks) -> $_genPath',
  );
}

String _header() => '''
// GENERATED FILE — DO NOT EDIT BY HAND.
// Produced by tool/embed_assets.dart.
''';

String _stubContents() => '''${_header()}
/// Whether real embedded assets are compiled into this build.
const bool kHasEmbeddedAssets = false;

/// Version key used to namespace the runtime extraction directory.
const String kEmbeddedAssetsVersion = '0.0.1';

/// `gzip(tar(assets))` encoded as base64 and split into chunks. Empty in the
/// stub; populated by the generator for a release build.
const List<String> kEmbeddedAssetsGzipBase64 = <String>[];
''';

String _realContents(String version, List<String> chunks) {
  final buffer = StringBuffer()
    ..write(_header())
    ..writeln()
    ..writeln('const bool kHasEmbeddedAssets = true;')
    ..writeln()
    ..writeln("const String kEmbeddedAssetsVersion = '$version';")
    ..writeln()
    ..writeln('const List<String> kEmbeddedAssetsGzipBase64 = <String>[');
  for (final chunk in chunks) {
    buffer.writeln("  '$chunk',");
  }
  buffer.writeln('];');
  return buffer.toString();
}

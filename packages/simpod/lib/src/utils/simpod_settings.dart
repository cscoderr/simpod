import 'dart:convert';
import 'dart:io';

import 'package:simpod/simpod.dart';

/// Persistent config at `$TMPDIR/simpod/settings.json`. Bump [schemaVersion]
/// and migrate in [SimpodSettings.fromJson] when the shape changes.
class SimpodSettings {
  const SimpodSettings({required this.accessToken, this.schemaVersion = 1});

  factory SimpodSettings.fromJson(Map<String, dynamic> json) {
    return SimpodSettings(
      accessToken: json['accessToken'] as String,
      schemaVersion: (json['schemaVersion'] as int?) ?? 1,
    );
  }

  final String accessToken;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'accessToken': accessToken,
  };

  SimpodSettings copyWith({String? accessToken}) => SimpodSettings(
    accessToken: accessToken ?? this.accessToken,
    schemaVersion: schemaVersion,
  );
}

/// The settings file is created once and then reused, so a single token is
/// shared by every process and survives restarts.
class SimpodSettingsManager {
  SimpodSettingsManager._();

  static SimpodSettings? _cached;

  static SimpodSettings loadOrCreate() {
    final cached = _cached;
    if (cached != null) return cached;

    final file = File(SimpodPaths.settingsFilePath());
    if (file.existsSync()) {
      try {
        final settings = SimpodSettings.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
        _cached = settings;
        return settings;
      } catch (_) {
        // Corrupt/legacy file — regenerate below.
      }
    }

    final created = SimpodSettings(accessToken: generateRandomToken());
    _write(file, created);
    _cached = created;
    return created;
  }

  static void save(SimpodSettings settings) {
    _write(File(SimpodPaths.settingsFilePath()), settings);
    _cached = settings;
  }

  static void _write(File file, SimpodSettings settings) {
    try {
      file.writeAsStringSync(jsonEncode(settings.toJson()));
    } on FileSystemException {
      stderr.writeln('Error: Unable to write settings file.');
    }
  }
}

import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

abstract class OrientationCommandBase extends SimpodCommand {
  /// Reads the last orientation this CLI recorded for [udid], defaulting to
  /// portrait. Rotations made elsewhere (the web UI) aren't visible here.
  SimpodOrientation lastKnownOrientation(String udid) {
    try {
      final file = SimpodPaths.orientationFile(udid);
      if (file.existsSync()) {
        final recorded = SimpodOrientation.fromWireName(
          file.readAsStringSync().trim(),
        );
        if (recorded != null) return recorded;
      }
    } catch (_) {
      // Unreadable state — fall back to portrait.
    }
    return SimpodOrientation.portrait;
  }

  /// Sends [orientation] to the helper and records it for later quarter turns.
  Future<void> applyOrientation(SimpodOrientation orientation) async {
    final session = getSession();
    await client.sendOrientation(orientation.value);
    try {
      SimpodPaths.orientationFile(
        session.device,
      ).writeAsStringSync(orientation.wireName);
    } catch (_) {
      // Best effort; the rotation itself already went out.
    }
  }
}

class RotateCommand extends OrientationCommandBase {
  @override
  final String name = 'rotate';

  @override
  final String description = 'Set device orientation';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      usageException(
        'Missing orientation argument. Usage: simpod rotate '
        '<${SimpodOrientation.wireNames.join('|')}>',
      );
    }

    final orientation = SimpodOrientation.fromWireName(
      rest.first.toLowerCase(),
    );
    if (orientation == null) {
      usageException(
        'Invalid orientation: "${rest.first}". Supported orientations are: '
        '${SimpodOrientation.wireNames.join(', ')}',
      );
    }

    await applyOrientation(orientation);
  }
}

class RotateLeftCommand extends OrientationCommandBase {
  @override
  final String name = 'rotate-left';

  @override
  final String description = 'Rotate a quarter-turn counterclockwise';

  @override
  Future<void> run() async {
    final session = getSession();
    await applyOrientation(lastKnownOrientation(session.device).rotatedLeft);
  }
}

class RotateRightCommand extends OrientationCommandBase {
  @override
  final String name = 'rotate-right';

  @override
  final String description = 'Rotate a quarter-turn clockwise';

  @override
  Future<void> run() async {
    await applyOrientation(
      lastKnownOrientation(getSession().device).rotatedRight,
    );
  }
}

import 'package:args/args.dart';
import 'package:simpod/simpod.dart';

class LocationCommand extends SimpodCommand {
  @override
  final String name = 'location';

  @override
  final String description = 'Mock the GPS location (latitude longitude)';

  /// Negative coordinates (`-122.0090`) must not be parsed as option flags.
  @override
  final ArgParser argParser = ArgParser.allowAnything();

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.length < 2) {
      usageException(
        'Missing coordinates. Usage: simpod location <latitude> <longitude>',
      );
    }

    final latitude = double.tryParse(rest[0]);
    final longitude = double.tryParse(rest[1]);
    if (latitude == null || longitude == null) {
      usageException(
        'Coordinates must be numeric. Received "${rest[0]}", "${rest[1]}".',
      );
    }

    final udid = await resolveTargetUdid();
    await reportSimctl(
      SimulatorControl.setLocation(udid, latitude, longitude),
      successMessage: 'Location set to $latitude, $longitude.',
    );
  }
}

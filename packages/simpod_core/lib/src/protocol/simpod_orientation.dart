enum SimpodOrientation {
  portrait(value: 1, wireName: 'portrait'),
  portraitUpsideDown(value: 2, wireName: 'portrait_upside_down'),
  landscapeRight(value: 3, wireName: 'landscape_right'),
  landscapeLeft(value: 4, wireName: 'landscape_left');

  const SimpodOrientation({required this.value, required this.wireName});

  /// Integer code used by the web client WebSocket payload.
  final int value;

  /// snake_case token used by the CLI and accepted by the helper.
  final String wireName;

  /// The orientations the CLI `rotate` command accepts, as wire tokens.
  static List<String> get wireNames =>
      values.map((o) => o.wireName).toList(growable: false);

  /// Resolves a [wireName] to its orientation, or
  static SimpodOrientation? fromWireName(String name) {
    for (final orientation in values) {
      if (orientation.wireName == name) return orientation;
    }
    return null;
  }

  SimpodOrientation get rotatedLeft => switch (this) {
    portrait => landscapeLeft,
    landscapeLeft => portraitUpsideDown,
    portraitUpsideDown => landscapeRight,
    landscapeRight => portrait,
  };

  SimpodOrientation get rotatedRight => switch (this) {
    portrait => landscapeRight,
    landscapeRight => portraitUpsideDown,
    portraitUpsideDown => landscapeLeft,
    landscapeLeft => portrait,
  };
}

sealed class SimpodKeyEvent {
  const SimpodKeyEvent(this.usage);
  final int usage;
}

class SimpodKeyDownEvent extends SimpodKeyEvent {
  const SimpodKeyDownEvent(super.usage);
}

class SimpodKeyUpEvent extends SimpodKeyEvent {
  const SimpodKeyUpEvent(super.usage);
}

class Key {
  const Key({required this.usage, required this.shift});
  final int usage;
  final bool shift;
}

Map<String, Key> buildKeysMap() {
  final data = <String, Key>{};

  // Letters a-z and A-Z
  for (int i = 0; i < 26; i++) {
    final int usage = 0x04 + i;
    final String lower = String.fromCharCode('a'.codeUnitAt(0) + i);
    final String upper = String.fromCharCode('A'.codeUnitAt(0) + i);
    data[lower] = Key(usage: usage, shift: false);
    data[upper] = Key(usage: usage, shift: true);
  }

  // Digits 0-9 and their shifted counterparts
  const shiftedDigitChars = [')', '!', '@', '#', r'$', '%', '^', '&', '*', '('];
  for (int i = 0; i < 10; i++) {
    final String digit = String.fromCharCode('0'.codeUnitAt(0) + i);
    final int usage = (i == 0) ? 0x27 : 0x1E + (i - 1);
    data[digit] = Key(usage: usage, shift: false);
    data[shiftedDigitChars[i]] = Key(usage: usage, shift: true);
  }

  // Common symbols
  const plainAndShiftSymbols = <(String, String, int)>{
    ('-', '_', 0x2D),
    ('=', '+', 0x2E),
    ('[', '{', 0x2F),
    (']', '}', 0x30),
    ('\\', '|', 0x31),
    (';', ':', 0x33),
    ("'", '"', 0x34),
    ('`', '~', 0x35),
    (',', '<', 0x36),
    ('.', '>', 0x37),
    ('/', '?', 0x38),
  };

  for (final s in plainAndShiftSymbols) {
    data[s.$1] = Key(usage: s.$3, shift: false);
    data[s.$2] = Key(usage: s.$3, shift: true);
  }

  // Whitespace and navigation keys
  const soloKeys = <String, int>{' ': 0x2C, '\n': 0x28, '\t': 0x2B};
  soloKeys.forEach((key, usage) => data[key] = Key(usage: usage, shift: false));

  return data;
}

const leftShift = 0xe1;
final _keysMap = buildKeysMap();

List<SimpodKeyEvent> convertTextToKeyEvents(String text) {
  final events = <SimpodKeyEvent>[];
  final cleanedText = text.replaceAll(
    '\r',
    '',
  ); // Skip Windows carriage returns
  for (var i = 0; i < cleanedText.length; i++) {
    final char = _keysMap[cleanedText[i]];
    if (char == null) {
      throw UnsupportedError('Character ${cleanedText[i]} is unsupported');
    }
    if (char.shift) {
      events.add(const SimpodKeyDownEvent(leftShift));
    }
    events.add(SimpodKeyDownEvent(char.usage));
    events.add(SimpodKeyUpEvent(char.usage));
    if (char.shift) {
      events.add(const SimpodKeyUpEvent(leftShift));
    }
  }
  return events;
}

import 'package:simpod_core/simpod_core.dart';
import 'package:test/test.dart';

void main() {
  group('convertTextToKeyEvents', () {
    test('converts lowercase characters', () {
      final events = convertTextToKeyEvents('a');
      expect(events, hasLength(2));
      expect(events[0], isA<SimpodKeyDownEvent>());
      expect(events[0].usage, equals(0x04)); // 'a' usage code
      expect(events[1], isA<SimpodKeyUpEvent>());
      expect(events[1].usage, equals(0x04));
    });

    test('converts uppercase characters and adds shift key', () {
      final events = convertTextToKeyEvents('A');
      expect(events, hasLength(4));
      // Shift down
      expect(events[0], isA<SimpodKeyDownEvent>());
      expect(events[0].usage, equals(leftShift));
      // 'a' down
      expect(events[1], isA<SimpodKeyDownEvent>());
      expect(events[1].usage, equals(0x04));
      // 'a' up
      expect(events[2], isA<SimpodKeyUpEvent>());
      expect(events[2].usage, equals(0x04));
      // Shift up
      expect(events[3], isA<SimpodKeyUpEvent>());
      expect(events[3].usage, equals(leftShift));
    });

    test('converts digits correctly', () {
      final events = convertTextToKeyEvents('1');
      expect(events, hasLength(2));
      expect(events[0].usage, equals(0x1E)); // '1' usage code
    });

    test('converts shifted symbols correctly', () {
      final events = convertTextToKeyEvents('!');
      expect(events, hasLength(4));
      expect(events[0].usage, equals(leftShift));
      expect(events[1].usage, equals(0x1E)); // '!' is shift + '1'
    });

    test('strips carriage returns', () {
      final eventsWithCR = convertTextToKeyEvents('a\ra');
      final eventsWithoutCR = convertTextToKeyEvents('aa');

      expect(eventsWithCR.length, equals(eventsWithoutCR.length));
      for (int i = 0; i < eventsWithCR.length; i++) {
        expect(eventsWithCR[i].usage, equals(eventsWithoutCR[i].usage));
      }
    });

    test('throws UnsupportedError for unknown characters', () {
      expect(
        () => convertTextToKeyEvents('💡'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

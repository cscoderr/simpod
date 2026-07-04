import 'package:simpod_core/simpod_core.dart';
import 'package:test/test.dart';

void main() {
  group('SimpodOrientation quarter turns', () {
    test('rotatedLeft cycles counterclockwise through all orientations', () {
      expect(
        SimpodOrientation.portrait.rotatedLeft,
        SimpodOrientation.landscapeLeft,
      );
      expect(
        SimpodOrientation.landscapeLeft.rotatedLeft,
        SimpodOrientation.portraitUpsideDown,
      );
      expect(
        SimpodOrientation.portraitUpsideDown.rotatedLeft,
        SimpodOrientation.landscapeRight,
      );
      expect(
        SimpodOrientation.landscapeRight.rotatedLeft,
        SimpodOrientation.portrait,
      );
    });

    test('rotatedRight is the inverse of rotatedLeft', () {
      for (final orientation in SimpodOrientation.values) {
        expect(orientation.rotatedLeft.rotatedRight, orientation);
        expect(orientation.rotatedRight.rotatedLeft, orientation);
      }
    });

    test('four turns in either direction return to the start', () {
      for (final orientation in SimpodOrientation.values) {
        expect(
          orientation.rotatedLeft.rotatedLeft.rotatedLeft.rotatedLeft,
          orientation,
        );
        expect(
          orientation.rotatedRight.rotatedRight.rotatedRight.rotatedRight,
          orientation,
        );
      }
    });
  });
}

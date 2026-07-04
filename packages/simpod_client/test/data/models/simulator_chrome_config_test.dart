import 'package:flutter_test/flutter_test.dart';
import 'package:simpod_client/data/models/simulator_chrome_config.dart';

void main() {
  group('SimulatorChromeConfig.fromJson', () {
    test('parses a full payload including buttons', () {
      final config = SimulatorChromeConfig.fromJson({
        'buttons': [
          {
            'align': 'left',
            'anchor': 'top',
            'label': 'Volume Up',
            'name': 'volume-up',
            'images': {'pressed': 'p.png', 'rest': 'r.png'},
            'normalOffset': {'x': 1.5, 'y': 2.5},
            'onTop': true,
            'rolloverOffset': {'x': 3.0, 'y': 4.0},
            'type': 'button',
            'usage': 233,
            'usagePage': 12,
            'width': 10.0,
            'height': 40.0,
            'x': 5.0,
            'y': 6.0,
          },
        ],
        'chromeCornerRadius': 12,
        'chromeHeight': 100,
        'chromeWidth': 200,
        'chromeX': 1,
        'chromeY': 2,
        'contentHeight': 300,
        'contentWidth': 400,
        'contentX': 3,
        'contentY': 4,
        'cornerRadius': 8,
        'hasScreenMask': true,
        'screenHeight': 800.0,
        'screenWidth': 400.0,
        'screenX': 10.0,
        'screenY': 20.0,
        'totalHeight': 900.0,
        'totalWidth': 450.0,
        'bezelImage': {'bare': 'bare.png', 'rest': 'rest.png'},
      });

      expect(config.chromeCornerRadius, 12);
      expect(config.hasScreenMask, isTrue);
      expect(config.screenHeight, 800.0);
      expect(config.totalWidth, 450.0);
      expect(config.bezelImage.bare, 'bare.png');

      expect(config.buttons, hasLength(1));
      final button = config.buttons.single;
      expect(button.name, 'volume-up');
      expect(button.usage, 233);
      expect(button.onTop, isTrue);
      expect(button.normalOffset, const Offset(1.5, 2.5));
      expect(button.rolloverOffset, const Offset(3.0, 4.0));
      expect(button.images.pressed, 'p.png');
    });

    test('applies defaults for missing optional fields', () {
      final config = SimulatorChromeConfig.fromJson({
        'bezelImage': {'bare': 'bare.png', 'rest': 'rest.png'},
      });

      expect(config.buttons, isEmpty);
      expect(config.chromeCornerRadius, 0);
      expect(config.chromeHeight, 0);
      expect(config.hasScreenMask, isFalse);
      expect(config.screenHeight, 0);
      expect(config.totalWidth, 0);
    });

    test('defaults button offsets to Offset.zero when absent', () {
      final config = SimulatorChromeConfig.fromJson({
        'buttons': [
          {
            'name': 'home',
            'images': {'pressed': 'p.png', 'rest': 'r.png'},
          },
        ],
        'bezelImage': {'bare': 'bare.png', 'rest': 'rest.png'},
      });

      final button = config.buttons.single;
      expect(button.normalOffset, Offset.zero);
      expect(button.rolloverOffset, Offset.zero);
      expect(button.usage, 0);
      expect(button.align, '');
    });

    test('equal payloads produce equal configs', () {
      Map<String, dynamic> payload() => {
        'bezelImage': {'bare': 'bare.png', 'rest': 'rest.png'},
        'chromeHeight': 100,
      };

      expect(
        SimulatorChromeConfig.fromJson(payload()),
        SimulatorChromeConfig.fromJson(payload()),
      );
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simpod_client/data/models/simulator_definition.dart';

/// A complete, valid simulator-definition JSON map used as the basis for the
/// round-trip and parsing tests.
Map<String, dynamic> sampleJson({bool withSensorBar = false}) => {
  'buttons': [
    {
      'box': {
        'heightPct': 0.1,
        'leftPct': 0.2,
        'topPct': 0.3,
        'widthPct': 0.4,
      },
      'envelope': {'button': 'home', 'type': 'tap'},
      'id': 'home-button',
      'images': {'pressed': 'pressed.png', 'rest': 'rest.png'},
      'transform': {
        'hover': {'x': 1, 'y': 2},
        'pressed': {'x': 3, 'y': 4},
        'rest': {'x': 5, 'y': 6},
      },
      'z': 'above',
    },
  ],
  'identity': {
    'model': 'iPhone16,1',
    'name': 'iPhone 16 Pro',
    'udid': 'ABC-123',
  },
  'keyboard': <String, dynamic>{},
  'screen': {
    'bezelImage': {'bare': 'bare.png', 'rest': 'rest.png'},
    'clipRadius': 55.5,
    'rect': {'height': 800.0, 'width': 400.0, 'x': 10.0, 'y': 20.0},
    'viewport': {'height': 2556.0, 'width': 1179.0},
    if (withSensorBar)
      'sensorBar': {'url': 'sensor.png', 'width': 120.0, 'height': 30.0},
  },
};

void main() {
  group('SimulatorDefinition', () {
    test('parses a full JSON payload', () {
      final def = SimulatorDefinition.fromJson(sampleJson());

      expect(def.identity.udid, 'ABC-123');
      expect(def.identity.name, 'iPhone 16 Pro');
      expect(def.buttons, hasLength(1));

      final button = def.buttons.single;
      expect(button.id, 'home-button');
      expect(button.z, 'above');
      expect(button.envelope.button, 'home');
      expect(button.box.heightPct, 0.1);
      expect(button.transform.hover.x, 1);
      expect(button.transform.rest.y, 6);

      expect(def.screen.clipRadius, 55.5);
      expect(def.screen.rect.width, 400.0);
      expect(def.screen.viewport.height, 2556.0);
      expect(def.screen.sensorBar, isNull);
    });

    test('parses an optional sensorBar when present', () {
      final def = SimulatorDefinition.fromJson(sampleJson(withSensorBar: true));

      expect(def.screen.sensorBar, isNotNull);
      expect(def.screen.sensorBar!.url, 'sensor.png');
      expect(def.screen.sensorBar!.width, 120.0);
      expect(def.screen.sensorBar!.height, 30.0);
    });

    test('round-trips through toJson/fromJson', () {
      final original = SimulatorDefinition.fromJson(
        sampleJson(withSensorBar: true),
      );

      final roundTripped = SimulatorDefinition.fromJson(original.toJson());

      expect(roundTripped, original);
    });

    test('fromJsonString decodes the same as fromJson', () {
      final json = sampleJson();
      final fromMap = SimulatorDefinition.fromJson(json);
      final fromString = SimulatorDefinition.fromJsonString(jsonEncode(json));

      expect(fromString, fromMap);
    });

    test('definitions with differing fields are not equal', () {
      final a = SimulatorDefinition.fromJson(sampleJson());
      final b = SimulatorDefinition.fromJson(sampleJson(withSensorBar: true));

      expect(a, isNot(b));
    });
  });
}

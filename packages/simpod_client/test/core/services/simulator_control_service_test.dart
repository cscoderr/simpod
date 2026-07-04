import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:simpod_client/core/services/simulator_control_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() => registerFallbackValue(Uri()));

  group('SimulatorControlService.screenshot', () {
    late _MockHttpClient client;
    late SimulatorControlService service;

    setUp(() {
      client = _MockHttpClient();
      service = SimulatorControlService(client: client);
    });

    void stubGet(http.Response response) {
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => response);
    }

    test('returns the PNG bytes on a 200 response', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D]);
      stubGet(http.Response.bytes(png, 200));

      final result = await service.screenshot('udid');

      expect(result.success, isTrue);
      expect(result.bytes, png);
      expect(result.error, isEmpty);
    });

    test('parses the error message from a JSON failure body', () async {
      stubGet(
        http.Response(jsonEncode({'error': 'Invalid device: udid'}), 500),
      );

      final result = await service.screenshot('udid');

      expect(result.success, isFalse);
      expect(result.bytes, isNull);
      expect(result.error, 'Invalid device: udid');
    });

    test('falls back to the status code when the body is not JSON', () async {
      stubGet(http.Response('upstream exploded', 503));

      final result = await service.screenshot('udid');

      expect(result.success, isFalse);
      expect(result.error, 'HTTP 503');
    });

    test('reports the exception when the request throws', () async {
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenThrow(Exception('connection refused'));

      final result = await service.screenshot('udid');

      expect(result.success, isFalse);
      expect(result.error, contains('connection refused'));
    });
  });
}

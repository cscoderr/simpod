import 'package:simpod_core/simpod_core.dart';
import 'package:test/test.dart';

void main() {
  group('SimpodSession', () {
    test('fromJson and toJson correctly serialize and deserialize data', () {
      final jsonMap = {
        'pid': 12345,
        'port': 8080,
        'device': 'A1B2C3D4-E5F6',
        'url': 'http://localhost:8080',
        'accessToken': 'abc-123-def',
        'streamUrl': 'http://localhost:8081',
        'wsUrl': 'ws://localhost:8080/ws',
      };

      final session = SimpodSession.fromJson(jsonMap);

      expect(session.pid, equals(12345));
      expect(session.port, equals(8080));
      expect(session.device, equals('A1B2C3D4-E5F6'));
      expect(session.url, equals('http://localhost:8080'));
      expect(session.accessToken, equals('abc-123-def'));
      expect(session.streamUrl, equals('http://localhost:8081'));
      expect(session.wsUrl, equals('ws://localhost:8080/ws'));

      final serialized = session.toJson();
      expect(serialized, equals(jsonMap));
    });
  });
}

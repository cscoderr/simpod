import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';
import 'package:test/test.dart';

void main() {
  group('SimpodClient', () {
    late HttpServer server;
    late String wsUrl;
    late StreamController<String> received;

    setUp(() async {
      received = StreamController<String>.broadcast();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      wsUrl = 'ws://${server.address.host}:${server.port}';

      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((data) {
          if (data is String) received.add(data);
        });
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await received.close();
    });

    Future<List<Map<String, dynamic>>> capture(
      int count,
      Future<void> Function(SimpodClient client) action,
    ) async {
      final frames = received.stream
          .take(count)
          .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
          .toList();

      await action(SimpodClient(wsUrl: wsUrl));

      return frames.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('Did not receive $count frames'),
      );
    }

    test('sendTap emits a begin/end touch pair with numeric coords', () async {
      final frames = await capture(2, (c) => c.sendTap(0.25, 0.75));

      expect(frames, hasLength(2));
      for (final frame in frames) {
        expect(frame['wsType'], 'hid_input');
        expect(frame['type'], 'touch');
      }

      final begin = frames[0]['data'] as Map<String, dynamic>;
      expect(begin['phase'], 'begin');
      expect(begin['x'], isA<num>());
      expect(begin['x'], 0.25);
      expect(begin['y'], 0.75);

      final end = frames[1]['data'] as Map<String, dynamic>;
      expect(end['phase'], 'end');
      expect(end['x'], 0.25);
      expect(end['y'], 0.75);
    });

    test('sendButton emits a single button frame', () async {
      final frames = await capture(1, (c) => c.sendButton('home'));

      expect(frames.single['wsType'], 'hid_input');
      expect(frames.single['type'], 'button');
      expect(frames.single['data'], {'button': 'home'});
    });

    test('sendOrientation emits the integer wire value', () async {
      final frames = await capture(
        1,
        (c) => c.sendOrientation(SimpodOrientation.landscapeLeft.value),
      );

      expect(frames.single['type'], 'orientation');
      expect(
        (frames.single['data'] as Map<String, dynamic>)['orientation'],
        SimpodOrientation.landscapeLeft.value,
      );
    });

    test('sendGesture forwards a touch step verbatim', () async {
      final frames = await capture(
        1,
        (c) => c.sendGesture(
          type: 'touch',
          data: {'phase': 'move', 'x': 0.5, 'y': 0.8, 'edge': 3},
        ),
      );

      expect(frames.single['wsType'], 'hid_input');
      expect(frames.single['type'], 'touch');
      expect(frames.single['data'], {
        'phase': 'move',
        'x': 0.5,
        'y': 0.8,
        'edge': 3,
      });
    });

    test('sendGesture forwards a pinch step verbatim', () async {
      final frames = await capture(
        1,
        (c) => c.sendGesture(
          type: 'pinch',
          data: {'phase': 'begin', 'x1': 0.4, 'y1': 0.5, 'x2': 0.6, 'y2': 0.5},
        ),
      );

      expect(frames.single['type'], 'pinch');
      expect(frames.single['data'], {
        'phase': 'begin',
        'x1': 0.4,
        'y1': 0.5,
        'x2': 0.6,
        'y2': 0.5,
      });
    });

    test('sendKeyEvents maps down/up events to the key payload', () async {
      final frames = await capture(
        2,
        (c) => c.sendKeyEvents(const [
          SimpodKeyDownEvent(0x04),
          SimpodKeyUpEvent(0x04),
        ]),
      );

      expect(frames[0]['type'], 'key');
      expect(frames[0]['data'], {'event': 'down', 'usage': 0x04});
      expect(frames[1]['data'], {'event': 'up', 'usage': 0x04});
    });
  });
}

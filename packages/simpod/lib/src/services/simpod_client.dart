import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simpod_core/simpod_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum _HidInputType { touch, pinch, button, orientation, key }

class SimpodClient {
  SimpodClient({required this.wsUrl})
    : _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  final String wsUrl;
  final WebSocketChannel _channel;

  final StreamController<String> _textFrames = StreamController.broadcast();

  bool _sawHelperError = false;

  Future<bool> _connect() async {
    try {
      await _channel.ready;
    } on SocketException catch (e) {
      return _connectFailed('Socket error: $e');
    } on WebSocketChannelException catch (e) {
      return _connectFailed('WebSocket connection error: $e');
    } catch (e) {
      return _connectFailed('Failed to connect to $wsUrl: $e');
    }

    _channel.stream.listen((event) {
      if (event is! String) return;
      _textFrames.add(event);
      if (event.contains('"error"')) {
        _sawHelperError = true;
        stderr.writeln('Helper error: $event');
      }
    }, onError: (e) => stderr.writeln('WebSocket stream error: $e'));
    return true;
  }

  bool _connectFailed(String message) {
    stderr.writeln(message);
    stderr.writeln(
      'Is a simpod session running? Start one with `simpod` (or check '
      '`simpod --list`).',
    );
    exitCode = 1;
    return false;
  }

  /// The helper only processes text frames for control input; binary frames
  /// are the outbound video stream.
  void _sendHidInput(_HidInputType type, Map<String, dynamic> data) {
    _channel.sink.add(
      json.encode({'wsType': 'hid_input', 'type': type.name, 'data': data}),
    );
  }

  /// The 50ms window is the only chance to catch a helper error frame — the
  /// helper doesn't ack successes, so commands are otherwise fire-and-forget.
  Future<void> _flushAndClose() async {
    await Future.delayed(const Duration(milliseconds: 50));
    await _channel.sink.close();
    if (_sawHelperError) exitCode = 1;
  }

  Future<void> sendTap(double x, double y) async {
    if (!await _connect()) return;
    _sendHidInput(_HidInputType.touch, {'phase': 'begin', 'x': x, 'y': y});
    await Future.delayed(const Duration(milliseconds: 40));
    _sendHidInput(_HidInputType.touch, {'phase': 'end', 'x': x, 'y': y});
    await _flushAndClose();
  }

  Future<void> sendGesture({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    if (!await _connect()) return;
    _sendHidInput(_HidInputType.values.byName(type), data);
    await _flushAndClose();
  }

  Future<void> sendButton(String button) async {
    if (!await _connect()) return;
    _sendHidInput(_HidInputType.button, {'button': button});
    await _flushAndClose();
  }

  Future<void> sendOrientation(int orientation) async {
    if (!await _connect()) return;
    _sendHidInput(_HidInputType.orientation, {'orientation': orientation});
    await _flushAndClose();
  }

  Future<void> sendKeyEvents(List<SimpodKeyEvent> events) async {
    if (!await _connect()) return;

    for (final event in events) {
      final data = switch (event) {
        SimpodKeyDownEvent(usage: final usg) => {'event': 'down', 'usage': usg},
        SimpodKeyUpEvent(usage: final usg) => {'event': 'up', 'usage': usg},
      };
      _sendHidInput(_HidInputType.key, data);
      await Future.delayed(const Duration(milliseconds: 5));
    }

    await _flushAndClose();
  }

  /// The AX grid sweep can take many seconds on complex screens, hence the
  /// generous timeout. Describe errors produce no response frame at all, so
  /// the timeout is also the failure path.
  Future<String?> describeUi({
    double? x,
    double? y,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!await _connect()) return null;

    final response = _textFrames.stream
        .firstWhere((frame) => !frame.contains('"error"'))
        .timeout(timeout);

    _channel.sink.add(
      json.encode({
        'wsType': 'describe_ui',
        'data': {'x': ?x, 'y': ?y},
      }),
    );

    try {
      return await response;
    } on TimeoutException {
      stderr.writeln(
        'Timed out waiting for the accessibility tree '
        '(${timeout.inSeconds}s).',
      );
      exitCode = 1;
      return null;
    } finally {
      await _channel.sink.close();
    }
  }
}

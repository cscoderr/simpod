import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rxdart/rxdart.dart';
import 'package:simpod_client/core/core.dart';
import 'package:web/web.dart' as web;
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketMessageType { touch, pinch, button, orientation, key }

enum StreamFormat { avcc, mjpeg }

enum StreamFormatPreference { auto, avcc, mjpeg }

class StreamSettings {
  const StreamSettings({
    this.format = StreamFormatPreference.auto,
    this.fps = 60,
    this.bitrateMbps = 8,
    this.quality = 0.7,
  });

  final StreamFormatPreference format;
  final int fps;
  final int bitrateMbps;
  final double quality;

  StreamSettings copyWith({
    StreamFormatPreference? format,
    int? fps,
    int? bitrateMbps,
    double? quality,
  }) => StreamSettings(
    format: format ?? this.format,
    fps: fps ?? this.fps,
    bitrateMbps: bitrateMbps ?? this.bitrateMbps,
    quality: quality ?? this.quality,
  );
}

class WebSocketService {
  WebSocketService({AvccStreamRenderer? avccStreamHandler})
    : _avccStreamHandler = avccStreamHandler ?? AvccStreamRenderer() {
    _settings = StreamSettings(format: _loadFormatPref());
    _avccFailed = web.window.localStorage.getItem(_avccFailedKey) == '1';
  }

  static const _formatKey = 'simpod.streamFormat';
  static const _avccFailedKey = 'simpod.avccFailed';
  static const _avccWatchdog = Duration(milliseconds: 2500);

  WebSocketChannel? _channel;
  StreamFormat _streamFormat = .mjpeg;
  StreamSettings _settings = const StreamSettings();
  String? _lastWsUrl;
  bool? _avccSupported;
  bool _avccFailed = false;
  Timer? _avccWatchdogTimer;
  final AvccStreamRenderer _avccStreamHandler;
  final StreamController<dynamic> _mjpegStreamController =
      StreamController.broadcast();
  final BehaviorSubject<dynamic> _accessiblityStreamController =
      BehaviorSubject();
  final BehaviorSubject<StreamFormat> _formatController =
      BehaviorSubject.seeded(.mjpeg);

  final BehaviorSubject<bool> _connectedController = BehaviorSubject.seeded(
    false,
  );

  StreamSettings get settings => _settings;

  bool? get avccSupported => _avccSupported;

  Future<void> applySettings(StreamSettings next) async {
    _settings = next;
    // A deliberate codec choice clears the remembered auto fallback so H.264 is
    // retried; the choice itself is persisted for the next page load.
    _avccFailed = false;
    web.window.localStorage
      ..setItem(_formatKey, next.format.name)
      ..removeItem(_avccFailedKey);
    final url = _lastWsUrl;
    if (url != null) await connect(url);
  }

  Future<void> connect(String wsUrl) async {
    _lastWsUrl = wsUrl;
    _avccWatchdogTimer?.cancel();
    // Browser codec support can't change within a session; probe once.
    final supported = _avccSupported ??= await _avccStreamHandler
        .isAvccSupported();
    // Honor the user's codec choice, but never request H.264 the browser can't
    // decode, and skip it under `auto` once it has failed this session.
    final wantsAvcc = switch (_settings.format) {
      StreamFormatPreference.auto => supported && !_avccFailed,
      StreamFormatPreference.avcc => supported,
      StreamFormatPreference.mjpeg => false,
    };
    if (wantsAvcc) {
      _streamFormat = .avcc;
      _avccStreamHandler.initDecoder();
    } else {
      _streamFormat = .mjpeg;
    }
    _formatController.add(_streamFormat);
    await _channel?.sink.close();
    final channel = WebSocketChannel.connect(
      Uri.parse(
        '$wsUrl?format=${_streamFormat.name}'
        '&fps=${_settings.fps}'
        '&bitrate=${_settings.bitrateMbps * 1000000}'
        '&quality=${_settings.quality}',
      ),
    );
    _channel = channel;
    unawaited(
      channel.ready
          .then((_) => _connectedController.add(true))
          .catchError((Object _) => _connectedController.add(false)),
    );
    channel.stream.listen(
      (data) {
        if (data is Uint8List) {
          if (supported && _streamFormat == .avcc) {
            _avccStreamHandler.handleAvccChunk(data);
          } else {
            _mjpegStreamController.add(data);
          }
        } else {
          _accessiblityStreamController.add(data);
        }
      },
      onError: (error) {
        _connectedController.add(false);
      },
      onDone: () {
        _connectedController.add(false);
      },
    );

    if (_streamFormat == .avcc &&
        _settings.format == StreamFormatPreference.auto) {
      _armAvccFallback(wsUrl);
    }
  }

  // Under `auto`, if H.264 is selected but nothing paints (or the decoder
  // errors) within the watchdog window, remember the failure and reconnect as
  // MJPEG so the stream is never left blank.
  void _armAvccFallback(String wsUrl) {
    _avccWatchdogTimer = Timer(_avccWatchdog, () {
      if (_streamFormat != .avcc) return;
      if (_avccStreamHandler.hasRenderedFrame && !_avccStreamHandler.hasError) {
        return;
      }
      _avccFailed = true;
      web.window.localStorage.setItem(_avccFailedKey, '1');
      unawaited(connect(wsUrl));
    });
  }

  StreamFormatPreference _loadFormatPref() {
    final raw = web.window.localStorage.getItem(_formatKey);
    for (final pref in StreamFormatPreference.values) {
      if (pref.name == raw) return pref;
    }
    return StreamFormatPreference.auto;
  }

  Future<void> close() async {
    _avccWatchdogTimer?.cancel();
    await _avccStreamHandler.close();
    await _mjpegStreamController.close();
    await _accessiblityStreamController.close();
    await _formatController.close();
    await _connectedController.close();
    await _channel?.sink.close();
  }

  Future<void> sendAccessiblity({double? x, double? y}) async {
    final payload = <String, dynamic>{
      'wsType': 'describe_ui',
      'data': {'x': x, 'y': y},
    };

    await sendMessage(payload);
  }

  Future<void> sendTouch({
    required String type,
    required double x,
    required double y,
    int? edge,
  }) async {
    final payload = <String, dynamic>{
      'wsType': 'hid_input',
      'type': SocketMessageType.touch.name,
      'data': {'phase': type, 'x': x, 'y': y, 'edge': edge},
    };

    await sendMessage(payload);
  }

  Future<void> sendMultiTouch({
    required String type,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) async {
    final payload = <String, dynamic>{
      'wsType': 'hid_input',
      'type': SocketMessageType.pinch.name,
      'data': {'phase': type, 'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2},
    };

    await sendMessage(payload);
  }

  Future<void> sendButton(String button) async {
    final payload = <String, dynamic>{
      'wsType': 'hid_input',
      'type': SocketMessageType.button.name,
      'data': {'button': button},
    };

    await sendMessage(payload);
  }

  Future<void> sendOrientation(int orientation) async {
    final payload = <String, dynamic>{
      'wsType': 'hid_input',
      'type': SocketMessageType.orientation.name,
      'data': {'orientation': orientation},
    };

    await sendMessage(payload);
  }

  Future<void> sendMessage(Map<String, dynamic> payload) async {
    try {
      await _channel?.ready;
    } on SocketException {
    } on WebSocketChannelException {}
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> sendKey({required String event, required int usage}) async {
    final payload = <String, dynamic>{
      'wsType': 'hid_input',
      'type': SocketMessageType.key.name,
      'data': {'event': event, 'usage': usage},
    };

    await sendMessage(payload);
  }

  StreamFormat get streamFormat => _streamFormat;
  Stream<StreamFormat> get streamFormatStream => _formatController.stream;
  Stream<dynamic> get mjpegStream => _mjpegStreamController.stream;
  Stream<dynamic> get accessibilityStream =>
      _accessiblityStreamController.stream;

  Stream<bool> get connectionStream => _connectedController.stream;
}

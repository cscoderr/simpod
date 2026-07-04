import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

final class AvccStreamRenderer {
  AvccStreamRenderer() {
    _registerCanvasFactory();
  }

  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _ctx;
  web.VideoDecoder? _decoder;
  int _timestamp = 0;
  bool _hasRenderedFrame = false;
  bool _hasError = false;
  static const canvasId = 'simulator-avcc-canvas';

  /// Whether a frame has actually painted since the last [initDecoder].".
  bool get hasRenderedFrame => _hasRenderedFrame;
  bool get hasError => _hasError;

  void _registerCanvasFactory() {
    _canvas =
        (web.document.getElementById(canvasId) as web.HTMLCanvasElement?) ??
        web.HTMLCanvasElement();

    _canvas!
      ..id = canvasId
      ..width = 100
      ..height = 100
      ..style.width = '100%'
      ..style.height = '100%';

    ui_web.platformViewRegistry.registerViewFactory(
      canvasId,
      (int viewId) => _canvas!,
    );
  }

  Future<bool> isAvccSupported() async {
    try {
      final config = web.VideoDecoderConfig(codec: 'avc1.42001f');
      final support = await web.VideoDecoder.isConfigSupported(config).toDart;
      return support.supported;
    } catch (e) {
      return false;
    }
  }

  void initDecoder() {
    _hasRenderedFrame = false;
    _hasError = false;
    final init = web.VideoDecoderInit(
      output: ((web.VideoFrame frame) {
        try {
          _paint(frame, frame.displayWidth, frame.displayHeight);
        } finally {
          frame.close();
        }
      }).toJS,
      error: ((JSAny e) {
        _hasError = true;
        print('Decoder error: $e');
      }).toJS,
    );
    _decoder = web.VideoDecoder(init);
  }

  void _paint(web.CanvasImageSource source, int width, int height) {
    try {
      if (_canvas?.width != width || _canvas?.height != height) {
        _canvas?.width = width;
        _canvas?.height = height;
        _ctx = null;
      }
      _ctx ??= _canvas!.getContext('2d')! as web.CanvasRenderingContext2D;
      if (_ctx?.isNull == true) return;
      _ctx!.drawImage(source, 0, 0, width, height);
      _hasRenderedFrame = true;
    } catch (e) {}
  }

  void handleAvccChunk(Uint8List bytes) {
    final type = bytes[0];
    final payload = bytes.sublist(1);
    if (type == 1) {
      try {
        _decoder?.configure(
          web.VideoDecoderConfig(
            codec: _avcCodecString(payload),
            description: payload.toJS,
            hardwareAcceleration: 'prefer-hardware',
            optimizeForLatency: true,
          ),
        );
      } catch (e) {
        _hasError = true;
      }
    } else if ((type == 2 || type == 3) && _decoder?.state == 'configured') {
      try {
        final chunk = web.EncodedVideoChunk(
          web.EncodedVideoChunkInit(
            type: type == 2 ? 'key' : 'delta',
            timestamp: _timestamp,
            data: payload.toJS,
          ),
        );
        _decoder!.decode(chunk);
        _timestamp += 16667; // ~60fps tick; not displayed, just monotonic.
      } catch (e) {}
    } else if (type == 4) {
      final blobOption = web.BlobPropertyBag(type: 'image/jpeg');
      final blob = web.Blob([payload.toJS].toJS, blobOption);
      web.window.createImageBitmap(blob).toDart.then((bmp) {
        try {
          _paint(bmp, bmp.width, bmp.height);
        } finally {
          bmp.close();
        }
      });
    }
  }

  String _avcCodecString(Uint8List byte) {
    if (byte.length < 4) return 'avc1.42001f';
    return 'avc1.${_hex(byte[1])}${_hex(byte[2])}${_hex(byte[3])}';
  }

  String _hex(int b) => b.toRadixString(16).padLeft(2, '0');

  Future<void> close() async {
    if (_decoder?.state != 'closed') {
      _decoder?.close();
    }
    _decoder = null;
  }
}

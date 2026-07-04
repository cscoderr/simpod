import 'dart:async';
import 'dart:js_interop';

import 'package:simpod_client/core/utils/api_config.dart';
import 'package:web/web.dart' as web;

class AxStreamService {
  web.EventSource? _source;
  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  void connect(String udid) {
    close();

    final base = '${ApiConfig.baseUrl}/api/device/$udid/ax';
    final token = ApiConfig.accessToken;
    final url = token == null
        ? base
        : '$base?token=${Uri.encodeQueryComponent(token)}';

    final source = web.EventSource(url);
    source.addEventListener(
      'message',
      (web.Event event) {
        final data = (event as web.MessageEvent).data;
        if (data.isA<JSString>() && !_controller.isClosed) {
          _controller.add((data as JSString).toDart);
        }
      }.toJS,
    );
    _source = source;
  }

  void close() {
    _source?.close();
    _source = null;
  }

  Future<void> dispose() async {
    close();
    await _controller.close();
  }
}

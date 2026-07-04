import 'package:flutter/foundation.dart';

abstract class ApiConfig {
  static String get baseUrl {
    final scheme = Uri.base.scheme;
    final host = Uri.base.host;
    if (kDebugMode) {
      return '$scheme://$host:5210';
    } else {
      return '$scheme://$host:${Uri.base.port}';
    }
  }

  static String get wsUrl {
    final host = Uri.base.host;
    if (kDebugMode) {
      return 'ws://$host:5210/ws';
    }
    final port = Uri.base.port;
    final scheme = Uri.base.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://$host:$port/ws';
  }

  static const String _debugToken = String.fromEnvironment('SIMPOD_TOKEN');

  static String? get accessToken {
    if (kDebugMode && _debugToken.isNotEmpty) return _debugToken;
    return null;
  }

  static Map<String, String> get headers {
    final token = accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'X-Simpod-Token': token,
    };
  }
}

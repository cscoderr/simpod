import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:simpod_client/core/utils/api_config.dart';
import 'package:simpod_core/simpod_core.dart';

class SimulatorControlResult {
  const SimulatorControlResult({
    required this.success,
    this.stdout = '',
    this.error = '',
  });

  final bool success;
  final String stdout;
  final String error;
}

class ScreenshotResult {
  const ScreenshotResult({required this.success, this.bytes, this.error = ''});

  final bool success;
  final Uint8List? bytes;
  final String error;
}

class SimulatorControlService {
  SimulatorControlService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String _url(String udid, String path) =>
      '${ApiConfig.baseUrl}/api/device/$udid/$path';

  SimulatorControlResult _toResult(http.Response response) {
    if (response.statusCode == 200) {
      Map<String, dynamic>? decoded;
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } catch (_) {}
      final stdout = (decoded?['stdout'] ?? decoded?['appearance'] ?? '')
          .toString();
      return SimulatorControlResult(success: true, stdout: stdout);
    }
    return SimulatorControlResult(
      success: false,
      error: _decodeError(response),
    );
  }

  String _decodeError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  Future<SimulatorControlResult> _sendRequest(
    String method,
    String udid,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final uri = Uri.parse(_url(udid, path));
      final encoded = body == null ? null : jsonEncode(body);
      final headers = ApiConfig.headers;
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'DELETE' => await _client.delete(uri, headers: headers, body: encoded),
        _ => await _client.post(uri, headers: headers, body: encoded),
      };
      return _toResult(response);
    } catch (e) {
      return SimulatorControlResult(success: false, error: e.toString());
    }
  }

  Future<SimulatorControlResult> boot(String udid) =>
      _sendRequest('POST', udid, 'boot');

  Future<SimulatorControlResult> shutdown(String udid) =>
      _sendRequest('POST', udid, 'shutdown');

  Future<SimulatorControlResult> getAppearance(String udid) =>
      _sendRequest('GET', udid, 'appearance');

  Future<SimulatorControlResult> setAppearance(String udid, String theme) =>
      _sendRequest('POST', udid, 'appearance', {'theme': theme});

  Future<SimulatorControlResult> setTextSize(String udid, String value) =>
      _sendRequest('POST', udid, 'text-size', {'value': value});

  Future<SimulatorControlResult> setContrast(String udid, bool enabled) =>
      _sendRequest('POST', udid, 'contrast', {'enabled': enabled});

  /// `null` when the value can't be read (server down, device shut down).
  Future<bool?> getContrast(String udid) async {
    final json = await _getJson(udid, 'contrast');
    return switch (json?['contrast']) {
      final String value => value == 'enabled',
      _ => null,
    };
  }

  Future<bool?> getAccessibility(
    String udid,
    AccessibilitySetting setting,
  ) async {
    final json = await _getJson(udid, 'accessibility/${setting.commandName}');
    return switch (json?['enabled']) {
      final bool enabled => enabled,
      _ => null,
    };
  }

  Future<Map<String, dynamic>?> _getJson(String udid, String path) async {
    try {
      final response = await _client.get(
        Uri.parse(_url(udid, path)),
        headers: ApiConfig.headers,
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<SimulatorControlResult> setAccessibility(
    String udid,
    AccessibilitySetting setting,
    bool enabled,
  ) => _sendRequest('POST', udid, 'accessibility/${setting.commandName}', {
    'enabled': enabled,
  });

  Future<SimulatorControlResult> openUrl(String udid, String url) =>
      _sendRequest('POST', udid, 'open-url', {'url': url});

  Future<SimulatorControlResult> setLocation(
    String udid,
    double latitude,
    double longitude,
  ) => _sendRequest('POST', udid, 'location', {
    'latitude': latitude,
    'longitude': longitude,
  });

  Future<SimulatorControlResult> setStatusBarOverride(
    String udid, {
    int? batteryLevel,
    String? time,
  }) => _sendRequest('POST', udid, 'status-bar', {
    if (batteryLevel != null) 'batteryLevel': batteryLevel,
    if (time != null && time.isNotEmpty) 'time': time,
  });

  Future<SimulatorControlResult> clearStatusBar(String udid) =>
      _sendRequest('DELETE', udid, 'status-bar');

  Future<SimulatorControlResult> setPermission(
    String udid, {
    required String action,
    required String service,
    String? bundleId,
  }) => _sendRequest('POST', udid, 'permissions', {
    'action': action,
    'service': service,
    if (bundleId != null && bundleId.isNotEmpty) 'bundleId': bundleId,
  });

  Future<ScreenshotResult> screenshot(String udid) async {
    try {
      final uri = Uri.parse(_url(udid, 'screenshot'));
      final response = await _client.get(uri, headers: ApiConfig.headers);
      if (response.statusCode == 200) {
        return ScreenshotResult(success: true, bytes: response.bodyBytes);
      }
      return ScreenshotResult(success: false, error: _decodeError(response));
    } catch (e) {
      return ScreenshotResult(success: false, error: e.toString());
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:simpod/simpod.dart';
import 'package:simpod_core/simpod_core.dart';

const axUnavailableError = 'AX_UNAVAILABLE';

class SimpodHttpServer {
  SimpodHttpServer({
    this.port = 5210,
    this.host = "127.0.0.1",
    required this.accessToken,
  });

  final int port;
  final String host;
  final String accessToken;

  Future<void> start() async {
    final publicRouter = Router()
      ..get('/pair', _handlePairRequest)
      ..get('/api/device/<udid>/bezel.png', _handleBezelPngRequest)
      ..get(
        '/api/device/<udid>/chrome-button/<file>',
        _handleChromeButtonRequest,
      );

    final router = Router()
      ..get('/api/health', _handleHealthRequest)
      ..get('/api/session/<udid>', _handleSessionRequest)
      ..get('/api/devices', _handleDevicesRequest)
      ..post('/api/device/<udid>/boot', _handleBootRequest)
      ..post('/api/device/<udid>/shutdown', _handleShutdownRequest)
      ..get('/api/device/<udid>/screenshot', _handleScreenshotRequest)
      ..get('/api/device/<udid>/appearance', _handleGetAppearanceRequest)
      ..post('/api/device/<udid>/appearance', _handleSetAppearanceRequest)
      ..get('/api/device/<udid>/text-size', _handleGetTextSizeRequest)
      ..post('/api/device/<udid>/text-size', _handleSetTextSizeRequest)
      ..get('/api/device/<udid>/contrast', _handleGetContrastRequest)
      ..post('/api/device/<udid>/contrast', _handleSetContrastRequest)
      ..get(
        '/api/device/<udid>/accessibility/<setting>',
        _handleGetAccessibilityRequest,
      )
      ..post(
        '/api/device/<udid>/accessibility/<setting>',
        _handleSetAccessibilityRequest,
      )
      ..post('/api/device/<udid>/open-url', _handleOpenUrlRequest)
      ..post('/api/device/<udid>/location', _handleLocationRequest)
      ..post('/api/device/<udid>/status-bar', _handleStatusBarRequest)
      ..delete('/api/device/<udid>/status-bar', _handleClearStatusBarRequest)
      ..get('/api/device/<udid>/chrome', _handleChromeJsonRequest)
      ..get('/api/device/<udid>/chrome-profile', _handleChromeProfileRequest)
      ..get('/api/device/<udid>/logs', _handleLogsRequest)
      ..get('/api/device/<udid>/ax', _handleAxStreamRequest)
      ..get('/api/device/<udid>/ax.json', _handleAxSnapshotRequest)
      ..post('/api/device/<udid>/permissions', _handlePermissionsRequest);

    Response clientRedirectHandler(Request request) {
      final redirect = _rootRedirectHandler(request);
      if (redirect != null) return redirect;
      return Response.notFound('Not found');
    }

    final static = await staticHandler();

    final publicHandler = Pipeline().addHandler(publicRouter.call);
    final enforceAuth = Platform.environment['SIMPOD_ENFORCE_AUTH'] == '1';
    final protectedHandler = Pipeline()
        .addMiddleware(enforceAuth ? _authMiddleware() : (Handler h) => h)
        .addHandler(
          Cascade()
              .add(router.call)
              .add(clientRedirectHandler)
              .add(static)
              .handler,
        );
    final routeHandler = Cascade()
        .add(publicHandler)
        .add(protectedHandler)
        .handler;

    final handler = Pipeline()
        // .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(routeHandler);
    await shelf_io.serve(handler, host, port);
  }

  Future<Handler> staticHandler() async {
    if (SimpodPaths.frontendIndexFile().existsSync()) {
      return createStaticHandler(
        SimpodPaths.flutterWebBuildPath,
        defaultDocument: 'index.html',
      );
    }

    if (Directory(SimpodPaths.simpodClientPath).existsSync()) {
      final process = await Process.start('flutter', [
        'build',
        'web',
        '--wasm',
      ], workingDirectory: SimpodPaths.simpodClientPath);

      print("Building flutter web application...");
      final stdoutFuture = process.stdout.drain<void>();
      final stderrFuture = process.stderr.pipe(stderr);

      final exitCode = await process.exitCode;
      await stdoutFuture;
      await stderrFuture;
      if (exitCode != 0) {
        throw Exception('flutter build failed');
      }

      print("\x1B[32m✓ Build completed\x1B[0m");
      print(
        '\x1B[90mServing web application from ${SimpodPaths.flutterWebBuildPath}\x1B[0m',
      );
      return createStaticHandler(
        SimpodPaths.flutterWebBuildPath,
        defaultDocument: 'index.html',
      );
    }

    stderr.writeln(
      'Warning: web dashboard assets not found; serving the API only.',
    );
    return (Request request) => Response.ok(
      '<!doctype html><html><body style="font-family: sans-serif">'
      '<h3>Simpod</h3>'
      '<p>The web dashboard assets are missing from this installation. '
      'The HTTP/WebSocket API is still available.</p>'
      '</body></html>',
      headers: {'Content-Type': 'text/html'},
    );
  }

  String get _tokenCookie =>
      'simpodToken=$accessToken; Path=/; SameSite=Strict; HttpOnly';

  /// Loopback is auto-trusted; LAN clients must pair.
  bool _isLoopback(Request request) {
    final info =
        request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    return info?.remoteAddress.isLoopback ?? false;
  }

  /// The HttpOnly token cookie is attached only for loopback requests; LAN
  /// devices get the page without a cookie and must pair via `/pair`.
  Response? _rootRedirectHandler(Request request) {
    final pathString = request.url.path;
    if (pathString == '' || pathString == 'index.html') {
      final indexPath = path.join(
        SimpodPaths.flutterWebBuildPath,
        'index.html',
      );
      final indexFile = File(indexPath);
      if (indexFile.existsSync()) {
        final htmlContent = indexFile.readAsStringSync();
        return .ok(
          htmlContent,
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            if (_isLoopback(request)) 'Set-Cookie': _tokenCookie,
          },
        );
      }
    }
    return null;
  }

  Response _handlePairRequest(Request request) {
    final token = request.url.queryParameters['t'];
    if (token == null || token != accessToken) {
      return .forbidden(
        jsonEncode({'error': 'Invalid or missing pairing token.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    return .found(Uri.parse('/'), headers: {'Set-Cookie': _tokenCookie});
  }

  Response _handleHealthRequest(Request request) {
    return .ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _sessionResponse(SimpodSession session) {
    final sessionMap = session.toJson()..remove('accessToken');
    return .ok(
      jsonEncode(sessionMap),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _simctlResponse(SimctlResult result) {
    if (result.isSuccess) {
      return .ok(
        jsonEncode({'exitCode': result.exitCode, 'stdout': result.stdout}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    return .internalServerError(
      body: jsonEncode({
        'exitCode': result.exitCode,
        'error': result.stderr.isEmpty
            ? 'simctl command failed'
            : result.stderr,
      }),
    );
  }

  Future<Map<String, dynamic>> _readJsonBody(Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) return {};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Starts a helper on demand when the simulator is booted but has no
  /// session yet, so the client can switch to an already-booted device.
  Future<Response> _handleSessionRequest(Request request, String udid) async {
    final existing = SimpodSessionManager.readSession(udid);
    if (existing != null) return _sessionResponse(existing);

    if (!await isDeviceBooted(udid)) {
      return .notFound(jsonEncode({'error': 'Simulator $udid is not booted.'}));
    }

    final session = await SimpodHelperManager.ensureSession(udid);
    if (session == null) {
      return .internalServerError(
        body: jsonEncode({'error': 'Failed to start a helper for $udid.'}),
      );
    }
    return _sessionResponse(session);
  }

  Future<Response> _handleBootRequest(Request request, String udid) async {
    final result = await SimulatorControl.boot(udid);
    // `Unable to boot device in current state: Booted` is not a real failure.
    if (!result.isSuccess && !result.stderr.contains('current state: Booted')) {
      return _simctlResponse(result);
    }
    final session = await SimpodHelperManager.ensureSession(udid);
    if (session == null) {
      return .internalServerError(
        body: jsonEncode({'error': 'Booted but failed to start helper.'}),
      );
    }
    return _sessionResponse(session);
  }

  Future<Response> _handleScreenshotRequest(
    Request request,
    String udid,
  ) async {
    final result = await SimulatorControl.screenshot(udid);
    if (!result.isSuccess) {
      return .internalServerError(
        body: jsonEncode({
          'exitCode': result.exitCode,
          'error': result.error.isEmpty
              ? 'simctl screenshot failed'
              : result.error,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
    return .ok(
      result.bytes,
      headers: {
        'content-type': 'image/png',
        'content-disposition': 'attachment; filename="simpod-screenshot.png"',
        'cache-control': 'no-store',
      },
    );
  }

  Future<Response> _handleShutdownRequest(Request request, String udid) async {
    final result = await SimulatorControl.shutdown(udid);
    SimpodHelperManager.stopSession(udid);
    return _simctlResponse(result);
  }

  /// Wraps a simctl read into `{"<key>": "<stdout>"}` JSON (or the standard
  /// error response).
  Future<Response> _simctlValueResponse(
    String key,
    Future<SimctlResult> operation,
  ) async {
    final result = await operation;
    if (!result.isSuccess) return _simctlResponse(result);
    return .ok(
      jsonEncode({key: result.stdout}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleGetAppearanceRequest(Request request, String udid) =>
      _simctlValueResponse('appearance', SimulatorControl.getAppearance(udid));

  Future<Response> _handleSetAppearanceRequest(
    Request request,
    String udid,
  ) async {
    final body = await _readJsonBody(request);
    final theme = body['theme'] as String?;
    if (theme != 'light' && theme != 'dark') {
      return .badRequest(
        body: jsonEncode({'error': 'theme must be "light" or "dark".'}),
      );
    }
    return _simctlResponse(await SimulatorControl.setAppearance(udid, theme!));
  }

  Future<Response> _handleGetTextSizeRequest(Request request, String udid) =>
      _simctlValueResponse('textSize', SimulatorControl.getContentSize(udid));

  Future<Response> _handleSetTextSizeRequest(
    Request request,
    String udid,
  ) async {
    final body = await _readJsonBody(request);
    final value = (body['value'] as String?)?.trim();
    if (value == null || value.isEmpty) {
      return .badRequest(
        body: jsonEncode({
          'error':
              'value is required (increment, decrement, or a size category).',
        }),
      );
    }
    return _simctlResponse(await SimulatorControl.setContentSize(udid, value));
  }

  Future<Response> _handleGetContrastRequest(Request request, String udid) =>
      _simctlValueResponse(
        'contrast',
        SimulatorControl.getIncreaseContrast(udid),
      );

  Future<Response> _handleSetContrastRequest(
    Request request,
    String udid,
  ) async {
    final body = await _readJsonBody(request);
    final enabled = body['enabled'];
    if (enabled is! bool) {
      return .badRequest(
        body: jsonEncode({'error': 'enabled must be true or false.'}),
      );
    }
    return _simctlResponse(
      await SimulatorControl.setIncreaseContrast(
        udid,
        enabled ? 'enabled' : 'disabled',
      ),
    );
  }

  Future<Response> _handleGetAccessibilityRequest(
    Request request,
    String udid,
    String settingName,
  ) async {
    final setting = AccessibilitySetting.fromCommandName(settingName);
    if (setting == null) {
      return .notFound(
        jsonEncode({'error': 'Unknown accessibility setting "$settingName".'}),
      );
    }
    final result = await SimulatorControl.getAccessibilitySetting(
      udid,
      setting,
    );
    if (!result.isSuccess) return _simctlResponse(result);
    return .ok(
      jsonEncode({
        'setting': setting.commandName,
        'enabled': result.stdout == 'enabled',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleSetAccessibilityRequest(
    Request request,
    String udid,
    String settingName,
  ) async {
    final setting = AccessibilitySetting.fromCommandName(settingName);
    if (setting == null) {
      return .notFound(
        jsonEncode({'error': 'Unknown accessibility setting "$settingName".'}),
      );
    }
    final body = await _readJsonBody(request);
    final enabled = body['enabled'];
    if (enabled is! bool) {
      return .badRequest(
        body: jsonEncode({'error': 'enabled must be true or false.'}),
      );
    }
    return _simctlResponse(
      await SimulatorControl.setAccessibilitySetting(
        udid,
        setting,
        enabled: enabled,
      ),
    );
  }

  Future<Response> _handleOpenUrlRequest(Request request, String udid) async {
    final body = await _readJsonBody(request);
    final url = (body['url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      return .badRequest(body: jsonEncode({'error': 'url is required.'}));
    }
    return _simctlResponse(await SimulatorControl.openUrl(udid, url));
  }

  Future<Response> _handleLocationRequest(Request request, String udid) async {
    final body = await _readJsonBody(request);
    final lat = (body['latitude'] as num?)?.toDouble();
    final lon = (body['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      return .badRequest(
        body: jsonEncode({'error': 'latitude and longitude are required.'}),
      );
    }
    return _simctlResponse(await SimulatorControl.setLocation(udid, lat, lon));
  }

  Future<Response> _handleStatusBarRequest(Request request, String udid) async {
    final body = await _readJsonBody(request);
    final batteryLevel = (body['batteryLevel'] as num?)?.toInt();
    final time = (body['time'] as String?)?.trim();

    if (batteryLevel != null || (time != null && time.isNotEmpty)) {
      final result = await SimulatorControl.setStatusBarOverride(
        udid,
        batteryLevel: batteryLevel,
        time: (time == null || time.isEmpty) ? null : time,
      );
      if (!result.isSuccess) return _simctlResponse(result);
    }
    if (batteryLevel == null && (time == null || time.isEmpty)) {
      return .badRequest(
        body: jsonEncode({'error': 'Provide batteryLevel and/or time.'}),
      );
    }
    return .ok(jsonEncode({'status': 'ok'}));
  }

  Future<Response> _handleClearStatusBarRequest(
    Request request,
    String udid,
  ) async {
    return _simctlResponse(await SimulatorControl.clearStatusBar(udid));
  }

  Future<Response> _handleLogsRequest(Request request, String udid) async {
    if (!await isDeviceBooted(udid)) {
      return .notFound(
        jsonEncode({'error': 'Simulator $udid is not booted.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    Process? process;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () async {
        try {
          final proc = await SimulatorControl.startLogStream(udid);
          process = proc;
          proc.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
                if (!controller.isClosed) {
                  controller.add(utf8.encode('data: $line\n\n'));
                }
              });
          unawaited(proc.stderr.drain<void>());
          unawaited(
            proc.exitCode.then((_) {
              if (!controller.isClosed) controller.close();
            }),
          );
        } catch (e) {
          if (!controller.isClosed) {
            controller
              ..addError(e)
              ..close();
          }
        }
      },
      onCancel: () {
        process?.kill();
        process = null;
      },
    );

    return .ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    );
  }

  Future<Response> _handleAxSnapshotRequest(Request request, String udid) {
    final query = request.url.query;
    return _proxyHelperGet(
      udid,
      '/ax.json${query.isEmpty ? '' : '?$query'}',
      contentType: 'application/json',
      cacheControl: 'no-store',
    );
  }

  /// Streams the simulator's accessibility tree as Server-Sent Events.
  Future<Response> _handleAxStreamRequest(Request request, String udid) async {
    final session = SimpodSessionManager.readSession(udid);
    if (session == null) {
      return .notFound(
        jsonEncode({'error': 'No running session for $udid.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final axUri = Uri.parse('http://127.0.0.1:${session.port}/ax.json');

    var cancelled = false;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () async {
        final client = http.Client();
        String? lastPayload;
        while (!cancelled) {
          try {
            final response = await client
                .get(axUri)
                .timeout(const Duration(seconds: 45));
            if (cancelled) break;
            if (response.statusCode == HttpStatus.ok &&
                response.body != lastPayload) {
              lastPayload = response.body;
              controller.add(utf8.encode('data: ${response.body}\n\n'));
            }
          } catch (_) {}
          await Future<void>.delayed(_axPollGap);
        }
        client.close();
        await controller.close();
      },
      onCancel: () => cancelled = true,
    );

    return .ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    );
  }

  static const Duration _axPollGap = Duration(milliseconds: 500);

  Future<Response> _handlePermissionsRequest(
    Request request,
    String udid,
  ) async {
    final body = await _readJsonBody(request);
    final action = (body['action'] as String?)?.toLowerCase();
    final service = (body['service'] as String?)?.trim();
    final bundleId = (body['bundleId'] as String?)?.trim();

    if (action == null || !{'grant', 'revoke', 'reset'}.contains(action)) {
      return .badRequest(
        body: jsonEncode({'error': 'action must be grant, revoke, or reset.'}),
      );
    }
    if (service == null || service.isEmpty) {
      return .badRequest(body: jsonEncode({'error': 'service is required.'}));
    }
    if (action != 'reset' && (bundleId == null || bundleId.isEmpty)) {
      return .badRequest(
        body: jsonEncode({'error': 'bundleId is required for "$action".'}),
      );
    }

    return _simctlResponse(
      await SimulatorControl.privacy(
        udid,
        action,
        service,
        bundleId == null || bundleId.isEmpty ? null : bundleId,
      ),
    );
  }

  Future<Response> _handleDevicesRequest(Request request) async {
    final devices = await scanIosDevices();
    return .ok(
      jsonEncode(devices.map((d) => d.toJson()).toList()),
      headers: {
        'Content-Type': 'application/json',
        'cache-control': 'no-cache',
      },
    );
  }

  Future<Response> _proxyHelperGet(
    String udid,
    String helperPathAndQuery, {
    required String contentType,
    String cacheControl = 'no-cache',
  }) async {
    final session = SimpodSessionManager.readSession(udid);
    if (session == null) return .notFound('Session not found');

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${session.port}$helperPathAndQuery'),
      );
      if (response.statusCode != HttpStatus.ok) return .internalServerError();
      return .ok(
        response.bodyBytes,
        headers: {'content-type': contentType, 'cache-control': cacheControl},
      );
    } catch (e) {
      return .internalServerError();
    }
  }

  Future<Response> _handleBezelPngRequest(Request request, String udid) {
    final buttons = request.url.queryParameters['buttons'] ?? 'true';
    return _proxyHelperGet(
      udid,
      '/bezel.png?buttons=$buttons',
      contentType: 'image/png',
      cacheControl: 'public, max-age=86400',
    );
  }

  Future<Response> _handleChromeProfileRequest(Request request, String udid) {
    return _proxyHelperGet(
      udid,
      '/chrome.json',
      contentType: 'application/json',
    );
  }

  Future<Response> _handleChromeJsonRequest(Request request, String udid) {
    return _proxyHelperGet(
      udid,
      '/chrome.json?prefix=/api/device/$udid/',
      contentType: 'application/json',
    );
  }

  Future<Response> _handleChromeButtonRequest(
    Request request,
    String udid,
    String file,
  ) {
    return _proxyHelperGet(
      udid,
      '/chrome-button/$file',
      contentType: 'image/png',
      cacheControl: 'public, max-age=86400',
    );
  }

  String? _extractTokenFromCookie(String? cookieHeader) {
    if (cookieHeader == null || cookieHeader.isEmpty) return null;
    final cookies = cookieHeader.split(';');
    for (var cookie in cookies) {
      final parts = cookie.split('=');
      if (parts.length == 2 && parts[0].trim() == 'simpodToken') {
        return parts[1].trim();
      }
    }
    return null;
  }

  Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final requestPath = request.url.path;
        if (requestPath.startsWith('api/') || requestPath.startsWith('ws')) {
          final cookieHeader = request.headers['Cookie'];
          // Cookie (same-origin) → header → query param. The query param lets
          // EventSource (which can't set headers) authorize the log stream.
          final token =
              _extractTokenFromCookie(cookieHeader) ??
              request.headers['X-Simpod-Token'] ??
              request.url.queryParameters['token'];
          if (token == null) {
            return .forbidden(
              jsonEncode({'error': 'SimPod API access token is required.'}),
              headers: {'Content-Type': 'application/json'},
            );
          }
          if (token != accessToken) {
            return .unauthorized(
              jsonEncode({'error': 'Unauthorized.'}),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }
        return await innerHandler(request);
      };
    };
  }

  /// Middleware to attach CORS headers to responses.
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return .ok(
            '',
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
              'Access-Control-Allow-Headers': 'Content-Type, X-Simpod-Token',
            },
          );
        }
        final response = await innerHandler(request);
        return response.change(
          headers: {...response.headers, 'Access-Control-Allow-Origin': '*'},
        );
      };
    };
  }
}

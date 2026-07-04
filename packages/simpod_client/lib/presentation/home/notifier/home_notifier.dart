import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/device_selection/notifier/devices_provider.dart';
import 'package:simpod_client/presentation/home/notifier/device_actions.dart';
import 'package:simpod_client/presentation/home/notifier/home_state.dart';
import 'package:simpod_client/presentation/home/notifier/polled_devices_provider.dart';
import 'package:simpod_client/presentation/home/notifier/session_provider.dart';
import 'package:simpod_client/presentation/home/widgets/ax/ax_overlay_widget.dart';
import 'package:simpod_core/simpod_core.dart';
import 'package:web/web.dart' as web;

class HomeNotifier extends Notifier<HomeState> {
  HomeNotifier(this.udid);

  final String udid;

  late WebSocketService _webSocketService;
  late AXOverlayController axOverlayController;
  final SimulatorControlService _control = SimulatorControlService();

  StreamSubscription<bool>? _connectionSub;

  @override
  HomeState build() {
    _webSocketService = ref.read(webSocketServiceProvider);
    // Watch .notifier (the controller instance), NOT the provider itself —
    // watching a ChangeNotifierProvider rebuilds this whole notifier on every
    // notifyListeners(), resetting HomeState and re-initializing the page.
    axOverlayController = ref.watch(axOverlayControllerProvider(udid).notifier);

    ref.listen(polledDevicesProvider, (_, next) {
      final devices = next.value;
      if (devices != null) _onDevices(devices);
    });

    ref.onDispose(() => _connectionSub?.cancel());
    // State can't be mutated while build is running; kick the async setup
    // onto the event loop.
    Future.microtask(_initialize);
    return const HomeState();
  }

  bool get mounted => ref.mounted;

  String get _targetUdid => state.selectedDevice?.udid ?? udid;

  Future<void> _initialize() async {
    if (!mounted) return;
    _listenToConnection();
    _seedSelectedDeviceFromStorage();
    await _refreshDevices();
    if (!mounted) return;

    final target = state.selectedDevice;
    if (target != null && target.state == DeviceState.booted) {
      try {
        await _fetchSessionForDevice(target.udid);
      } catch (_) {
        // Surfaced via state.error.
      }
    }
  }

  void _listenToConnection() {
    _connectionSub = _webSocketService.connectionStream.listen((connected) {
      if (connected) {
        if (state.isDisconnected) {
          _updateState(state.copyWith(isDisconnected: false));
        }
        return;
      }
      if (state.streamUrl != null) {
        _updateState(state.copyWith(isDisconnected: true));
      }
    });
  }

  void _onDevices(List<DeviceInfo> devices) {
    if (!mounted) return;
    final current = _deviceByUdid(devices, _targetUdid);

    final wasStreaming = state.streamUrl != null;
    final shutDown = current != null && current.state != DeviceState.booted;

    _updateState(
      state.copyWith(
        devices: devices,
        selectedDevice: current ?? state.selectedDevice ?? devices.firstOrNull,
        deviceInfo: current ?? state.deviceInfo,
        isDisconnected: wasStreaming && shutDown ? true : null,
      ),
    );
  }

  Future<void> _refreshDevices() async {
    try {
      _onDevices(await ref.refresh(devicesProvider.future));
    } catch (_) {
      // The poll picks it up on the next tick.
    }
  }

  DeviceInfo? _deviceByUdid(List<DeviceInfo> devices, String udid) {
    for (final device in devices) {
      if (device.udid == udid) return device;
    }
    return null;
  }

  /// The hand-off from the selection page is only a seed — the authoritative
  /// state is refreshed right after, and the session is fetched live rather
  /// than trusting any stored stream URL.
  void _seedSelectedDeviceFromStorage() {
    final rawDeviceInfo = web.window.sessionStorage.getItem('deviceInfo');
    if (rawDeviceInfo == null || rawDeviceInfo.isEmpty) return;

    final deviceInfo = DeviceInfo.fromJson(
      jsonDecode(rawDeviceInfo) as Map<String, dynamic>,
    );
    _updateState(
      state.copyWith(deviceInfo: deviceInfo, selectedDevice: deviceInfo),
    );
  }

  String _checkHost(String url) {
    final uri = Uri.parse(url);
    final currentHost = web.window.location.hostname;
    if (uri.host == currentHost) return url;
    return uri.replace(host: currentHost).toString();
  }

  Future<void> _fetchSessionForDevice(String targetUdid) async {
    _updateState(state.copyWith(isLoading: true, clearError: true));
    try {
      final session = await ref.refresh(sessionProvider(targetUdid).future);
      if (!mounted) return;

      final streamUrl = _checkHost(session.streamUrl);
      final wsUrl = _checkHost(session.wsUrl);
      await _webSocketService.connect(wsUrl);

      _updateState(
        state.copyWith(
          isLoading: false,
          streamUrl: streamUrl,
          wsUrl: wsUrl,
          clearError: true,
          isDisconnected: false,
        ),
      );
    } catch (e) {
      _updateState(state.copyWith(isLoading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> selectDevice(DeviceInfo device) async {
    _updateState(
      state.copyWith(
        selectedDevice: device,
        deviceInfo: device,
        clearStream: true,
        clearError: true,
        isDisconnected: false,
      ),
    );

    if (device.state == DeviceState.booted) {
      try {
        await _fetchSessionForDevice(device.udid);
      } catch (_) {
        // Surfaced via state.error.
      }
    } else {
      await bootDevice();
    }
  }

  /// Boots the selected device and attaches its stream.
  Future<void> bootDevice() async {
    final targetUdid = _targetUdid;
    try {
      await bootDeviceMutation(targetUdid).run(ref, (_) async {
        _updateState(
          state.copyWith(
            isLoading: true,
            isDisconnected: false,
            clearError: true,
          ),
        );
        final result = await _control.boot(targetUdid);
        if (!mounted) return;
        if (!result.success) {
          final err = result.error.isEmpty
              ? 'Failed to boot device'
              : result.error;
          _updateState(state.copyWith(isLoading: false, error: err));
          throw Exception(err);
        }
        // Independent: the session fetch targets the udid directly, and the
        // device list refresh only updates the selector.
        await Future.wait([
          _refreshDevices(),
          _fetchSessionForDevice(targetUdid),
        ]);
      });
    } catch (_) {
      // Already surfaced via state.error and the mutation state.
    }
  }

  /// Shuts the selected device down and tears the stream down.
  Future<void> shutdownDevice() async {
    final targetUdid = _targetUdid;
    try {
      await shutdownDeviceMutation(targetUdid).run(ref, (_) async {
        _updateState(state.copyWith(isLoading: true));
        final result = await _control.shutdown(targetUdid);
        if (!mounted) return;
        if (!result.success) {
          final err = result.error.isEmpty
              ? 'Failed to shutdown device'
              : result.error;
          _updateState(state.copyWith(isLoading: false, error: err));
          throw Exception(err);
        }
        _updateState(state.copyWith(clearStream: true, isDisconnected: false));
        await _refreshDevices();
        _updateState(state.copyWith(isLoading: false));
      });
    } catch (_) {}
  }

  void clearError() => _updateState(state.copyWith(clearError: true));

  Future<void> toggleAccessibility() async {
    final nextEnabled = !state.enableAccessibility;
    _updateState(state.copyWith(enableAccessibility: nextEnabled));
    if (!nextEnabled) {
      axOverlayController.clear();
    }
  }

  void toggleAXSidebar() {
    _updateState(state.copyWith(showLeftSidebar: !state.showLeftSidebar));
  }

  void setZoom(double scale) {
    _updateState(state.copyWith(zoomScale: scale.clamp(0.6, 1.1)));
  }

  void zoomIn() => setZoom(state.zoomScale + 0.05);
  void zoomOut() => setZoom(state.zoomScale - 0.05);

  void resetRotation() {
    _updateState(state.copyWith(rotationTurns: 0));
    _webSocketService.sendOrientation(SimpodOrientation.portrait.value);
  }

  void toggleOrientation() => _rotate(0.25);
  void rotateLeft() => _rotate(-0.25);

  void _rotate(double deltaTurns) {
    final newTurns = state.rotationTurns + deltaTurns;
    final normalized = (newTurns % 1.0 + 1.0) % 1.0;

    final orientation = switch (normalized) {
      0.25 => SimpodOrientation.landscapeLeft,
      0.50 => SimpodOrientation.portraitUpsideDown,
      0.75 => SimpodOrientation.landscapeRight,
      _ => SimpodOrientation.portrait,
    };

    _updateState(state.copyWith(rotationTurns: newTurns));
    _webSocketService.sendOrientation(orientation.value);
  }

  void handleHomePressed([bool isDoubleTap = false]) {
    _webSocketService.sendButton(isDoubleTap ? 'app_switcher' : 'home');
  }

  void pressButton(String button) {
    _webSocketService.sendButton(button);
  }

  Future<void> applyStreamSettings(StreamSettings settings) async {
    await _webSocketService.applySettings(settings);
    // Identity-bump so the canvas rebuilds and picks up a codec change.
    _updateState(state.copyWith());
  }

  Future<void> toggleAppearance() async {
    final result = await _control.getAppearance(udid);
    if (!result.success) return;

    final targetTheme = result.stdout.trim() == 'light' ? 'dark' : 'light';
    await setAppearance(targetTheme);
  }

  Future<void> setAppearance(String theme) async {
    await _control.setAppearance(udid, theme);
  }

  Future<void> setTextSize(String value) async {
    await _control.setTextSize(_targetUdid, value);
  }

  Future<void> setContrast(bool enabled) async {
    await _control.setContrast(_targetUdid, enabled);
  }

  Future<bool?> getContrast() => _control.getContrast(_targetUdid);

  Future<bool?> getAccessibility(AccessibilitySetting setting) =>
      _control.getAccessibility(_targetUdid, setting);

  Future<void> setAccessibility(
    AccessibilitySetting setting,
    bool enabled,
  ) async {
    await _control.setAccessibility(_targetUdid, setting, enabled);
  }

  Future<void> setStatusBarOverride({int? batteryLevel, String? time}) async {
    await _control.setStatusBarOverride(
      udid,
      batteryLevel: batteryLevel,
      time: time?.trim(),
    );
  }

  Future<void> clearStatusBarOverrides() async {
    await _control.clearStatusBar(udid);
  }

  /// Wraps a control-service call into the `(success, message)` shape the
  /// UI's toasts consume.
  Future<({bool success, String message})> _report(
    Future<SimulatorControlResult> operation, {
    required String failureFallback,
    required String successMessage,
  }) async {
    final result = await operation;
    if (!mounted) return (success: false, message: 'Cancelled');
    if (!result.success) {
      return (
        success: false,
        message: result.error.isEmpty ? failureFallback : result.error,
      );
    }
    return (success: true, message: successMessage);
  }

  Future<({bool success, String message})> openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return (success: false, message: 'Enter a URL or deep link first');
    }
    return _report(
      _control.openUrl(udid, trimmed),
      failureFallback: 'Failed to open URL',
      successMessage: 'Opened $trimmed',
    );
  }

  Future<({bool success, String message})> setLocation(double lat, double lon) {
    return _report(
      _control.setLocation(udid, lat, lon),
      failureFallback: 'Failed to set location',
      successMessage: 'Location set to $lat, $lon',
    );
  }

  Future<({bool success, String message})> setPermission({
    required String action,
    required String service,
    String? bundleId,
  }) {
    final target = (bundleId == null || bundleId.isEmpty)
        ? 'all apps'
        : bundleId;
    final past = switch (action) {
      'grant' => 'granted',
      'revoke' => 'revoked',
      _ => 'reset',
    };
    return _report(
      _control.setPermission(
        _targetUdid,
        action: action,
        service: service,
        bundleId: bundleId,
      ),
      failureFallback: 'Permission update failed',
      successMessage: 'Permission "$service" $past for $target',
    );
  }

  Future<({bool success, String message, Uint8List? bytes})>
  captureScreenshot() async {
    final result = await _control.screenshot(_targetUdid);
    if (!mounted) return (success: false, message: 'Cancelled', bytes: null);

    if (result.success && result.bytes != null) {
      final filename = _screenshotFilename();
      _downloadBytes(result.bytes!, filename, 'image/png');
      return (
        success: true,
        message: 'Screenshot saved to Downloads',
        bytes: result.bytes,
      );
    }

    final err = result.error.isEmpty
        ? 'Failed to capture screenshot'
        : result.error;
    return (success: false, message: err, bytes: null);
  }

  String _screenshotFilename() {
    final rawName =
        state.selectedDevice?.name ?? state.deviceInfo?.name ?? 'device';
    final safeName = rawName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'simpod-${safeName.isEmpty ? 'device' : safeName}-$stamp.png';
  }

  void _downloadBytes(Uint8List bytes, String filename, String mimeType) {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  void _updateState(HomeState next) {
    if (!mounted) return;
    state = next;
  }
}

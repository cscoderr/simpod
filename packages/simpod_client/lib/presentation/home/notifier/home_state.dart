import 'package:simpod_core/simpod_core.dart';

class HomeState {
  const HomeState({
    this.showLeftSidebar = true,
    this.zoomScale = 0.95,
    this.rotationTurns = 0,
    this.streamUrl,
    this.wsUrl,
    this.devices = const [],
    this.deviceInfo,
    this.selectedDevice,
    this.isLoading = false,
    this.error,
    this.enableAccessibility = false,
    this.isDisconnected = false,
  });

  final bool showLeftSidebar;
  final double zoomScale;
  final double rotationTurns;
  final String? streamUrl;
  final String? wsUrl;
  final List<DeviceInfo> devices;
  final DeviceInfo? deviceInfo;
  final DeviceInfo? selectedDevice;
  final bool isLoading;
  final String? error;
  final bool enableAccessibility;
  final bool isDisconnected;

  HomeState copyWith({
    bool? showLeftSidebar,
    double? zoomScale,
    double? rotationTurns,
    String? streamUrl,
    String? wsUrl,
    List<DeviceInfo>? devices,
    DeviceInfo? deviceInfo,
    DeviceInfo? selectedDevice,
    bool? isLoading,
    String? error,
    bool? enableAccessibility,
    bool? isDisconnected,
    bool clearError = false,
    bool clearStream = false,
  }) {
    return HomeState(
      showLeftSidebar: showLeftSidebar ?? this.showLeftSidebar,
      zoomScale: zoomScale ?? this.zoomScale,
      rotationTurns: rotationTurns ?? this.rotationTurns,
      streamUrl: clearStream ? null : (streamUrl ?? this.streamUrl),
      wsUrl: clearStream ? null : (wsUrl ?? this.wsUrl),
      devices: devices ?? this.devices,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      enableAccessibility: enableAccessibility ?? this.enableAccessibility,
      isDisconnected: isDisconnected ?? this.isDisconnected,
    );
  }
}

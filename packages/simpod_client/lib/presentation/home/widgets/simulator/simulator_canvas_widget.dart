import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/notifier/device_chrome_provider.dart';
import 'package:simpod_client/presentation/home/widgets/widgets.dart';
import 'package:simpod_core/simpod_core.dart';

class SimulatorCanvasWidget extends ConsumerWidget {
  const SimulatorCanvasWidget({
    required this.udid,
    required this.simulatorFocusNode,
    required this.webSocketService,
    required this.inputController,
    required this.axOverlayController,
    required this.onHomePressed,
    required this.onCaptureScreenshot,
    required this.onOrientationPressed,
    required this.onOverlayTap,
    required this.onPowerPressed,
    required this.onBoot,
    this.onDeviceSelected,
    super.key,
  });

  final String udid;

  final FocusNode simulatorFocusNode;
  final WebSocketService webSocketService;
  final SimulatorInputController inputController;
  final AXOverlayController axOverlayController;
  final void Function([bool]) onHomePressed;
  final VoidCallback onOrientationPressed;
  final VoidCallback onCaptureScreenshot;
  final VoidCallback onOverlayTap;
  final VoidCallback onPowerPressed;
  final VoidCallback onBoot;
  final ValueChanged<DeviceInfo>? onDeviceSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeNotifierProvider(udid));
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isMobile = viewportWidth < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double? targetWidth;
        if (!isMobile) {
          final chrome = ref.watch(deviceChromeProvider(udid)).asData?.value;
          // final isLandscape = (state.rotationTurns % 0.5 != 0);

          double aspectRatio;
          aspectRatio = chrome != null
              ? chrome.totalWidth / chrome.totalHeight
              : 390.0 / 844.0;

          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final availableHeight = h - 48.0 - 10.0 - 56.0;
          final availableWidth = w - 48.0;

          final simWidth = availableHeight * aspectRatio;
          targetWidth = simWidth.clamp(0.0, availableWidth);
        } else {
          targetWidth = null;
        }

        return Center(
          child: AnimatedScale(
            scale: state.zoomScale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedRotation(
              turns: state.rotationTurns,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xlg),
                child: SizedBox(
                  width: targetWidth,
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: isMobile ? .center : .stretch,
                    spacing: AppSpacing.sm + AppSpacing.xxs,
                    children: [
                      if (!isMobile)
                        SimulatorToolbar(
                          deviceInfo: state.deviceInfo,
                          devices: state.devices,
                          onDeviceSelected: onDeviceSelected,
                          onHomePressed: onHomePressed,
                          onHomeDoubleTap: () => onHomePressed(true),
                          onOrientationPressed: onOrientationPressed,
                          onCaptureScreenshot: onCaptureScreenshot,
                        ),
                      Expanded(
                        child: SimulatorWidget(
                          udid: udid,
                          streamUrl: state.streamUrl,
                          simulatorFocusNode: simulatorFocusNode,
                          webSocketService: webSocketService,
                          inputController: inputController,
                          axOverlayController: axOverlayController,
                          onOverlayTap: onOverlayTap,
                          onBoot: onBoot,
                          isDisconnected: state.isDisconnected,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

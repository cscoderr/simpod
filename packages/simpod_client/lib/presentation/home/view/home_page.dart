import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide KeyEvent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/notifier/ax_tree_provider.dart';
import 'package:simpod_client/presentation/home/notifier/home_notifier.dart';
import 'package:simpod_client/presentation/home/notifier/home_state.dart';
import 'package:simpod_client/presentation/home/widgets/controls_sidebar.dart';
import 'package:simpod_client/presentation/home/widgets/widgets.dart';
import 'package:simpod_core/simpod_core.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.udid, super.key});

  final String udid;

  @override
  Widget build(BuildContext context) {
    return HomeView(udid: udid);
  }
}

class HomeView extends ConsumerStatefulWidget {
  const HomeView({required this.udid, super.key});

  final String udid;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  final FocusNode _simulatorFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final SimulatorInputController _simulatorInputController;

  @override
  void initState() {
    super.initState();
    _simulatorInputController = SimulatorInputController(
      webSocketService: ref.read(webSocketServiceProvider),
    );
  }

  @override
  void dispose() {
    _simulatorFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _simulatorInputController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_simulatorFocusNode.hasFocus) return;

    final controller = ref.read(homeNotifierProvider(widget.udid).notifier);
    if (ref.read(homeNotifierProvider(widget.udid)).wsUrl == null) return;

    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyH && isMeta && isShift) {
        ref.read(webSocketServiceProvider).sendButton('home');
        return;
      }

      if ((event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) &&
          isMeta &&
          !isShift &&
          !isAlt &&
          !isControl) {
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyA && isMeta && isShift) {
        controller.toggleAppearance();
        return;
      }
      ref
          .read(webSocketServiceProvider)
          .sendKey(event: 'down', usage: event.physicalKey.usbHidUsage);
    } else if (event is KeyUpEvent) {
      ref
          .read(webSocketServiceProvider)
          .sendKey(event: 'up', usage: event.physicalKey.usbHidUsage);
    }
  }

  static const double _panelWidth = 340;

  HomeNotifier get _controller =>
      ref.read(homeNotifierProvider(widget.udid).notifier);

  void _togglePower() {
    final state = ref.read(homeNotifierProvider(widget.udid));
    if (state.selectedDevice?.state == DeviceState.booted) {
      _controller.shutdownDevice();
    } else {
      _controller.bootDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeNotifierProvider(widget.udid));
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isMobile = viewportWidth < 600;

    // Keep the AX SSE stream alive and feed the canvas overlay while the
    // inspector is enabled; dropping this listener (inspector off, page
    // closed) lets the provider auto-dispose and close the connection.
    if (state.enableAccessibility) {
      final axTarget = state.selectedDevice?.udid ?? widget.udid;
      ref.listen(axTreeProvider(axTarget), (_, root) {
        if (root != null) _controller.axOverlayController.setRoot(root);
      });
    }

    if (state.error != null) {
      return StatusView.error(
        title: 'Something went wrong',
        message: state.error,
        actionLabel: 'Dismiss',
        onAction: _controller.clearError,
      );
    }

    final isDeviceShutdown =
        state.selectedDevice != null &&
        state.selectedDevice!.state != DeviceState.booted;

    if (!isDeviceShutdown && (state.streamUrl == null || state.wsUrl == null)) {
      return const StatusView.loading(
        message: 'Waiting for the device stream…',
      );
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        key: _scaffoldKey,
        body: isMobile
            ? _buildMobileLayout(state, viewportWidth)
            : _buildDesktopLayout(state),
      ),
    );
  }

  Widget _buildMobileLayout(HomeState state, double viewportWidth) {
    final panelWidth = math.min(_panelWidth, viewportWidth * 0.85);
    final scrimVisible = state.showLeftSidebar;

    return Stack(
      children: [
        _buildCanvas(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: _buildSideControlBar()),
        ),
        Positioned(
          bottom: AppSpacing.xlg - AppSpacing.xs,
          right: AppSpacing.xlg - AppSpacing.xs,
          child: _buildZoomControls(state),
        ),
        if (scrimVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: _controller.toggleAXSidebar,
              child: AnimatedContainer(
                duration: AppMotion.base,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          child: _horizontalPanel(
            open: state.showLeftSidebar,
            width: panelWidth,
            alignment: Alignment.centerLeft,
            child: _buildControlsSidebar(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(HomeState state) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        _horizontalPanel(
          open: state.showLeftSidebar,
          width: _panelWidth,
          alignment: Alignment.centerLeft,
          child: _buildControlsSidebar(),
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _buildCanvas()),
              Positioned(
                top: 20,
                left: 20,
                child: IgnorePointer(
                  ignoring: state.showLeftSidebar,
                  child: AnimatedOpacity(
                    opacity: state.showLeftSidebar ? 0 : 1,
                    duration: AppMotion.base,
                    curve: Curves.easeOut,
                    child: Row(
                      mainAxisSize: .min,
                      spacing: 10,
                      children: [
                        SimpodIconButton(
                          icon: CupertinoIcons.sidebar_left,
                          tooltip: 'Show toolkit',
                          onPressed: _controller.toggleAXSidebar,
                        ),
                        Text(
                          'SIMPOD',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: context.colorScheme.onSurface,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: _buildZoomControls(state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideControlBar() {
    final controller = _controller;
    return SideControlBar(
      udid: widget.udid,
      onInspectorPressed: () {
        controller
          ..toggleAccessibility()
          ..toggleAXSidebar();
      },
      onToggleAXSidebar: controller.toggleAXSidebar,
      onDeviceSelected: controller.selectDevice,
      onHomePressed: controller.handleHomePressed,
      onHomeDoubleTap: () => controller.handleHomePressed(true),
      onOrientationPressed: controller.toggleOrientation,
    );
  }

  Widget _buildCanvas() {
    final controller = _controller;
    return SimulatorCanvasWidget(
      udid: widget.udid,
      simulatorFocusNode: _simulatorFocusNode,
      webSocketService: ref.read(webSocketServiceProvider),
      inputController: _simulatorInputController,
      axOverlayController: controller.axOverlayController,
      onHomePressed: controller.handleHomePressed,
      onOrientationPressed: controller.toggleOrientation,
      onOverlayTap: controller.toggleAccessibility,
      onPowerPressed: _togglePower,
      onBoot: controller.bootDevice,
      onCaptureScreenshot: () async {
        final result = await controller.captureScreenshot();
        if (!mounted) return;
        showSimpodToast(
          context,
          result.message,
          isError: !result.success,
          preview: result.bytes,
        );
      },
      onDeviceSelected: controller.selectDevice,
    );
  }

  Widget _buildZoomControls(HomeState state) => ZoomControlsWidget(
    zoomScale: state.zoomScale,
    onZoomIn: _controller.zoomIn,
    onZoomOut: _controller.zoomOut,
    onSetZoom: _controller.setZoom,
  );

  Widget _buildControlsSidebar() =>
      ControlsSidebar(udid: widget.udid, onClose: _controller.toggleAXSidebar);

  Widget _horizontalPanel({
    required bool open,
    required double width,
    required Alignment alignment,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: AppMotion.emphasized,
      curve: AppMotion.panelCurve,
      width: open ? width : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: alignment,
          minWidth: _panelWidth,
          maxWidth: _panelWidth,
          child: child,
        ),
      ),
    );
  }
}

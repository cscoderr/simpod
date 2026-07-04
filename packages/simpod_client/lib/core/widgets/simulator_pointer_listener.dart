import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';

class SimulatorPointerListener extends StatefulWidget {
  const SimulatorPointerListener({
    super.key,
    required this.inputController,
    required this.child,
  });

  final SimulatorInputController inputController;
  final Widget child;

  @override
  State<SimulatorPointerListener> createState() =>
      _SimulatorPointerListenerState();
}

class _SimulatorPointerListenerState extends State<SimulatorPointerListener>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    widget.inputController.addListener(_onHandlerChanged);
  }

  void _onHandlerChanged() {
    final inputController = widget.inputController;
    if (inputController.singleTouch ||
        inputController.isMultiTouchActive ||
        inputController.isAltPinchActive) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.inputController.removeListener(_onHandlerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.inputController,
      builder: (context, child) {
        final controller = widget.inputController;
        return Listener(
          onPointerDown: controller.handlePointerDown,
          onPointerMove: controller.handlePointerMove,
          onPointerUp: controller.handlePointerUp,
          onPointerHover: controller.handleMouseHover,
          onPointerCancel: controller.handlePointerCancel,
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            onExit: (_) => controller.onExit?.call(),
            child: Stack(
              key: controller.stackKey,
              children: [
                child!,
                if (controller.fingerIndicators != null)
                  TouchIndicatorOverlay(
                    indicators: controller.fingerIndicators!,
                    animationController: _controller,
                    inputController: controller,
                  ),
              ],
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

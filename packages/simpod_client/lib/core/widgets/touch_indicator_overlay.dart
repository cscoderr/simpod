import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/finger_indicators.dart';

class TouchIndicatorOverlay extends StatelessWidget {
  const TouchIndicatorOverlay({
    super.key,
    required this.inputController,
    required this.animationController,
    required this.indicators,
  });

  final SimulatorInputController inputController;
  final AnimationController animationController;
  final FingerIndicators indicators;

  Animation<double> get _opacity =>
      CurvedAnimation(parent: animationController, curve: Curves.easeIn);

  Animation<double> get _scale => Tween<double>(begin: 0.4, end: 1.0).animate(
    CurvedAnimation(parent: animationController, curve: Curves.easeOutBack),
  );

  @override
  Widget build(BuildContext context) {
    final showSecond =
        inputController.isMultiTouchActive ||
        inputController.isAltPinchActive ||
        HardwareKeyboard.instance.isAltPressed;

    final pos1 = inputController.normalizedToStackOffset(
      indicators.x1,
      indicators.y1,
    );
    final pos2 = inputController.normalizedToStackOffset(
      indicators.x2,
      indicators.y2,
    );

    return Stack(
      children: [
        _TouchRing(position: pos1, opacity: _opacity, scale: _scale),

        if (showSecond)
          _TouchRing(position: pos2, opacity: _opacity, scale: _scale),
      ],
    );
  }
}

class _TouchRing extends StatelessWidget {
  const _TouchRing({
    required this.position,
    required this.opacity,
    required this.scale,
  });

  final Offset position;
  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 12,
      top: position.dy - 12,
      child: FadeTransition(
        opacity: opacity,
        child: ScaleTransition(
          scale: scale,
          child: Container(
            height: 24,
            width: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The ring sits over arbitrary simulator content, so it can't
              // follow the (monochrome) theme accent: a white ring with a
              // dark halo stays visible on both light and dark app screens.
              color: Colors.white.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

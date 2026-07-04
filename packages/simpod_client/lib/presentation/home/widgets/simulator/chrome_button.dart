import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/models.dart';

class ChromeButton extends StatefulWidget {
  const ChromeButton({
    super.key,
    required this.button,
    required this.width,
    required this.height,
    required this.scale,
    this.originX = 0,
    this.originY = 0,
  });

  final SimulatorChromeButton button;
  final double width;
  final double height;
  final double scale;
  final double originX;
  final double originY;

  @override
  State<ChromeButton> createState() => _ChromeButtonState();
}

class _ChromeButtonState extends State<ChromeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset get _restOffset => widget.button.normalOffset;

  Offset get _hoverOffset => widget.button.rolloverOffset;

  double get _left {
    final btn = widget.button;

    final offset = lerpDouble(
      _restOffset.dx,
      _hoverOffset.dx,
      _controller.value,
    )!;

    final double raw;
    switch (btn.anchor) {
      case 'right':
        raw = widget.width + offset - btn.width;
      default:
        raw = offset;
    }
    return (widget.originX + raw) * widget.scale;
  }

  double get _top {
    final raw = lerpDouble(_restOffset.dy, _hoverOffset.dy, _controller.value)!;
    return (widget.originY + raw) * widget.scale;
  }

  void _onHover(bool value) {
    if (value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _press() {
    setState(() => _pressed = true);
  }

  void _release() {
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final btn = widget.button;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = lerpDouble(
          0,
          btn.anchor == 'left' ? -2 : 2,
          _controller.value,
        )!;

        final pressedScale = _pressed ? lerpDouble(1.0, .94, .35)! : 1.0;

        return Positioned(
          left: _left + slide,
          top: _top,
          width: btn.width * widget.scale,
          height: btn.height * widget.scale,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => _onHover(true),
            onExit: (_) {
              _onHover(false);
              _release();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _press(),
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _pressed ? .96 : 1),
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value * pressedScale,
                    child: Transform.translate(
                      offset: Offset(
                        _pressed ? (btn.anchor == 'left' ? 2 : -2) : 0,
                        0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 70),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeOut,
                        child: NetworkImageWidget(
                          key: ValueKey(
                            '${widget.button.name}-${_pressed ? 'pressed' : 'rest'}',
                          ),
                          url: _pressed ? btn.images.pressed : btn.images.rest,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

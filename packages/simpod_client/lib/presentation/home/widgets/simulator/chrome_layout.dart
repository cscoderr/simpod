import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart' show NetworkImageWidget;
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_client/presentation/home/widgets/widgets.dart';

class ChromeLayout extends StatelessWidget {
  const ChromeLayout({
    required this.chrome,
    required this.baseUrl,
    required this.child,
  });
  final SimulatorChromeConfig chrome;
  final String baseUrl;
  final Widget child;

  /// A little breathing room (device points) so the cosmetic ±2px hover/press
  /// slide never reaches the stack edge and loses its hit area.
  static const double _safety = 4;

  Rect _buttonsBounds() {
    Rect? bounds;
    for (final b in chrome.buttons) {
      double leftFor(Offset o) =>
          b.anchor == 'right' ? chrome.totalWidth + o.dx - b.width : o.dx;

      final lefts = [leftFor(b.normalOffset), leftFor(b.rolloverOffset)];
      final tops = [b.normalOffset.dy, b.rolloverOffset.dy];
      final rect = Rect.fromLTRB(
        lefts.reduce(math.min),
        tops.reduce(math.min),
        lefts.reduce(math.max) + b.width,
        tops.reduce(math.max) + b.height,
      );
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds ?? Rect.zero;
  }

  @override
  Widget build(BuildContext context) {
    final buttons = _buttonsBounds();

    final padLeft = math.max(0.0, -buttons.left) + _safety;
    final padTop = math.max(0.0, -buttons.top) + _safety;
    final padRight = math.max(0.0, buttons.right - chrome.totalWidth) + _safety;
    final padBottom =
        math.max(0.0, buttons.bottom - chrome.totalHeight) + _safety;

    final framedWidth = chrome.totalWidth + padLeft + padRight;
    final framedHeight = chrome.totalHeight + padTop + padBottom;

    return AspectRatio(
      aspectRatio: framedWidth / framedHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            constraints.maxWidth / framedWidth,
            constraints.maxHeight / framedHeight,
          );

          final belowBezelButtons = chrome.buttons.where((b) => !b.onTop);
          final aboveBezelButtons = chrome.buttons.where((b) => b.onTop);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ...belowBezelButtons.map(
                (btn) => _buildButtonsLayer(btn, scale, padLeft, padTop),
              ),
              _buildScreenLayer(scale, padLeft, padTop),
              _buildBezelLayer(chrome.bezelImage.rest, scale, padLeft, padTop),
              ...aboveBezelButtons.map(
                (btn) => _buildButtonsLayer(btn, scale, padLeft, padTop),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScreenLayer(double scale, double originX, double originY) {
    return Positioned(
      left: (originX + chrome.screenX) * scale,
      top: (originY + chrome.screenY) * scale,
      width: chrome.screenWidth * scale,
      height: chrome.screenHeight * scale,
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(chrome.cornerRadius * scale),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildBezelLayer(
    String url,
    double scale,
    double originX,
    double originY,
  ) {
    return Positioned(
      left: originX * scale,
      top: originY * scale,
      width: chrome.totalWidth * scale,
      height: chrome.totalHeight * scale,
      child: IgnorePointer(child: NetworkImageWidget(url: url)),
    );
  }

  Widget _buildButtonsLayer(
    SimulatorChromeButton button,
    double scale,
    double originX,
    double originY,
  ) {
    return ChromeButton(
      button: button,
      width: chrome.totalWidth,
      height: chrome.totalHeight,
      scale: scale,
      originX: originX,
      originY: originY,
    );
  }
}

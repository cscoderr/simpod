import 'package:flutter/animation.dart';

/// Centralized animation durations and curves so motion feels consistent and
/// intentional across the app instead of every widget picking its own timing.
abstract class AppMotion {
  /// 120ms — hover/press feedback, tiny state flips.
  static const Duration fast = Duration(milliseconds: 120);

  /// 200ms — most micro-interactions (scale, fades).
  static const Duration base = Duration(milliseconds: 200);

  /// 250ms — panels, sidebars, drawers sliding in/out.
  static const Duration emphasized = Duration(milliseconds: 250);

  /// 350ms — large layout transitions.
  static const Duration slow = Duration(milliseconds: 350);

  /// Standard easing for entrances/exits of panels.
  static const Curve panelCurve = Curves.easeOutCubic;

  /// Springy easing for playful affordances (zoom, etc.).
  static const Curve emphasizedCurve = Curves.easeOutBack;
}

import 'package:flutter/material.dart';

abstract class _Palette {
  // Neutral scale (zinc-like)
  static const Color ink = Color(0xFF18181B);
  static const Color paper = Color(0xFFFAFAFA);

  // Status
  static const Color liveGreen = Color(0xFF4AF2A1);
  static const Color liveGreenDim = Color(0xFF10B981);
  static const Color amber = Colors.amberAccent;
  static const Color red = Colors.redAccent;

  // Accessibility overlay colours
  static const Color axGreen = Color(0xFF4AF2A1);
  static const Color axAmber = Color(0xFFFFB300);
  static const Color axBlue = Color(0xFF1565C0);
  static const Color axBlueLight = Color(0xFF64B5F6);
  static const Color axTeal = Color(0xFF80CBC4);
  static const Color axTooltipBorder = Color(0xFF2196F3);
}

abstract class AppColorsDark {
  // Surfaces
  static const Color background = Color(0xFF0A0A0B);
  static const Color surface = Color(0xFF09090B);
  static const Color surfaceCard = Color(0xFF0F0F11);
  static const Color surfaceOverlay = Color(0xFF141417);
  static const Color deviceScreenMock = Color(0xFF18181B);

  // Accent
  static const Color primary = _Palette.paper;
  static const Color onPrimary = Color(0xFF111113);
  static const Color primaryAccent = Color(0xFFE4E4E7);

  // Status
  static const Color statusLive = _Palette.liveGreenDim;
  static const Color statusLiveGlow = _Palette.liveGreen;
  static const Color statusConnecting = _Palette.amber;
  static const Color statusError = _Palette.red;

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textDimmed = Colors.white38;
  static const Color textFaded = Colors.white24;

  // Accessibility overlays
  static const Color axHighlight = _Palette.axGreen;
  static const Color axFocused = _Palette.axAmber;
  static const Color tooltipBackground = Color(0xF0111827);
  static const Color tooltipBorder = _Palette.axTooltipBorder;
  static const Color axChipBg = _Palette.axBlue;
  static const Color axChipText = _Palette.axBlueLight;
  static const Color axValueText = _Palette.axTeal;

  // Utilities
  static const Color white = Colors.white;
  static Color border({double alpha = 0.08}) => white.withValues(alpha: alpha);
  static Color tint({double alpha = 0.03}) => white.withValues(alpha: alpha);
}

abstract class AppColorsLight {
  // Surfaces
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFF4F4F5);
  static const Color surfaceOverlay = Color(0xFFEFEFF1);
  static const Color deviceScreenMock = Color(0xFFE4E4E7);

  // Accent
  static const Color primary = _Palette.ink;
  static const Color onPrimary = Colors.white;
  static const Color primaryAccent = Color(0xFF3F3F46);
  static const Color primaryContainer = Color(0xFFE4E4E7);
  static const Color onPrimaryContainer = _Palette.ink;

  // Status
  static const Color statusLive = Color(0xFF059669);
  static const Color statusLiveGlow = Color(0xFF10B981);
  static const Color statusConnecting = Color(0xFFD97706);
  static const Color statusError = Color(0xFFDC2626);

  // Text
  static const Color textPrimary = Color(0xFF111113);
  static const Color textSecondary = Color(0xFF3F3F46);
  static const Color textMuted = Color(0xFF6B6B74);
  static const Color textDimmed = Color(0xFF9898A1);
  static const Color textFaded = Color(0xFFBBBBC2);

  // Accessibility overlays
  static const Color axHighlight = Color(0xFF059669);
  static const Color axFocused = Color(0xFFD97706);
  static const Color tooltipBackground = Color(0xF0FAFAFA);
  static const Color tooltipBorder = _Palette.ink;
  static const Color axChipBg = Color(0xFFE4E4E7);
  static const Color axChipText = _Palette.ink;
  static const Color axValueText = Color(0xFF0D9488);

  // Utilities
  static const Color black = Colors.black;
  static Color border({double alpha = 0.10}) => black.withValues(alpha: alpha);
  static Color tint({double alpha = 0.04}) => black.withValues(alpha: alpha);
}

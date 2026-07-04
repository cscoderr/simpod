import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTextTheme {
  static TextTheme build(Brightness brightness) {
    final baseTheme = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final theme = GoogleFonts.interTextTheme(baseTheme.textTheme);

    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      displayMedium: theme.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.75,
      ),
      displaySmall: theme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleLarge: theme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: theme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: theme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelLarge: theme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: theme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: theme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
    );
  }
}

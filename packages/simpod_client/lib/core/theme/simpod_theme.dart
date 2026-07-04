import 'package:flutter/material.dart';
import 'package:simpod_client/core/theme/app_colors.dart';
import 'package:simpod_client/core/theme/app_spacing.dart';
import 'package:simpod_client/core/theme/simpod_text_theme.dart';

class SimpodTheme {
  SimpodTheme();

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: colorScheme.surfaceContainerHighest,
      primaryColor: colorScheme.primary,
      colorScheme: colorScheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      tabBarTheme: TabBarThemeData(
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        space: 1,
        thickness: 1,
      ),
      tooltipTheme: tooltipThemeData,
      popupMenuTheme: popupMenuThemeData,
      appBarTheme: appBarTheme,
      chipTheme: chipThemeData,
    );
  }

  Brightness get brightness => Brightness.dark;

  ColorScheme get colorScheme {
    return const ColorScheme.dark().copyWith(
      primary: AppColorsDark.primary,
      onPrimary: AppColorsDark.onPrimary,
      primaryContainer: AppColorsDark.primary.withValues(alpha: 0.14),
      onPrimaryContainer: AppColorsDark.primaryAccent,
      secondary: AppColorsDark.primaryAccent,
      onSecondary: AppColorsDark.onPrimary,
      surface: AppColorsDark.surface,
      surfaceContainerHighest: AppColorsDark.surfaceCard,
      surfaceContainerHigh: AppColorsDark.surfaceCard,
      surfaceContainer: AppColorsDark.surfaceOverlay,
      surfaceContainerLow: AppColorsDark.background,
      surfaceContainerLowest: AppColorsDark.background,
      error: AppColorsDark.statusError,
      onSurface: AppColorsDark.textPrimary,
      onSurfaceVariant: AppColorsDark.textDimmed,
      outline: Colors.white24,
      outlineVariant: Colors.white12,
    );
  }

  Color get dividerColor => AppColorsDark.border(alpha: 0.08);

  TextTheme get textTheme => AppTextTheme.build(brightness).apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: textTheme.titleLarge,
    );
  }

  ChipThemeData get chipThemeData {
    return ChipThemeData(
      backgroundColor: AppColorsDark.surfaceOverlay,
      labelStyle: textTheme.labelLarge,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
        vertical: AppSpacing.sm - AppSpacing.xxs,
      ),
      side: BorderSide(color: AppColorsDark.border(alpha: 0.12)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xxs),
      ),
    );
  }

  TooltipThemeData get tooltipThemeData {
    final tt = AppTextTheme.build(brightness);
    return TooltipThemeData(
      waitDuration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        color: AppColorsDark.surfaceOverlay,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      textStyle: tt.bodySmall?.copyWith(color: AppColorsDark.textPrimary),
    );
  }

  PopupMenuThemeData get popupMenuThemeData {
    return PopupMenuThemeData(
      color: AppColorsDark.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xxs),
        side: BorderSide(color: AppColorsDark.border(alpha: 0.12)),
      ),
    );
  }
}

class SimpodDarkTheme extends SimpodTheme {
  @override
  ColorScheme get colorScheme {
    return const ColorScheme.dark().copyWith(
      primary: AppColorsDark.primary,
      onPrimary: AppColorsDark.onPrimary,
      primaryContainer: AppColorsDark.primary.withValues(alpha: 0.14),
      onPrimaryContainer: AppColorsDark.primaryAccent,
      secondary: AppColorsDark.primaryAccent,
      onSecondary: AppColorsDark.onPrimary,
      surface: AppColorsDark.background,
      surfaceContainerHighest: AppColorsDark.surfaceCard,
      surfaceContainerHigh: AppColorsDark.surfaceCard,
      surfaceContainer: AppColorsDark.surfaceOverlay,
      surfaceContainerLow: AppColorsDark.background,
      surfaceContainerLowest: AppColorsDark.background,
      error: AppColorsDark.statusError,
      onSurface: AppColorsDark.textPrimary,
      onSurfaceVariant: AppColorsDark.textDimmed,
      outline: Colors.white24,
      outlineVariant: Colors.white12,
    );
  }
}

class SimpodLightTheme extends SimpodTheme {
  @override
  Brightness get brightness => Brightness.light;

  @override
  ColorScheme get colorScheme {
    return const ColorScheme.light().copyWith(
      primary: AppColorsLight.primary,
      onPrimary: AppColorsLight.onPrimary,
      primaryContainer: AppColorsLight.primaryContainer,
      onPrimaryContainer: AppColorsLight.onPrimaryContainer,
      secondary: AppColorsLight.primaryAccent,
      onSecondary: Colors.white,
      surface: AppColorsLight.surface,
      surfaceContainerHighest: AppColorsLight.surfaceCard,
      surfaceContainerHigh: AppColorsLight.surfaceCard,
      surfaceContainer: AppColorsLight.surfaceOverlay,
      surfaceContainerLow: AppColorsLight.background,
      surfaceContainerLowest: AppColorsLight.background,
      error: AppColorsLight.statusError,
      onSurface: AppColorsLight.textPrimary,
      onSurfaceVariant: AppColorsLight.textMuted,
      outline: AppColorsLight.border(alpha: 0.20),
      outlineVariant: AppColorsLight.border(alpha: 0.10),
    );
  }

  @override
  Color get dividerColor => AppColorsLight.border(alpha: 0.10);

  @override
  ChipThemeData get chipThemeData {
    final tt = AppTextTheme.build(brightness);
    return ChipThemeData(
      backgroundColor: AppColorsLight.surfaceOverlay,
      labelStyle: tt.labelLarge?.copyWith(color: AppColorsLight.textPrimary),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
        vertical: AppSpacing.sm - AppSpacing.xxs,
      ),
      side: BorderSide(color: AppColorsLight.border(alpha: 0.14)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xxs),
      ),
    );
  }

  @override
  TooltipThemeData get tooltipThemeData {
    final tt = AppTextTheme.build(brightness);
    return TooltipThemeData(
      waitDuration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        color: AppColorsLight.tooltipBackground,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: AppColorsLight.tooltipBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColorsLight.border(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: tt.bodySmall?.copyWith(color: AppColorsLight.textPrimary),
    );
  }

  @override
  PopupMenuThemeData get popupMenuThemeData {
    return PopupMenuThemeData(
      color: AppColorsLight.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColorsLight.border(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xxs),
        side: BorderSide(color: AppColorsLight.border(alpha: 0.12)),
      ),
    );
  }
}

extension SimpodThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;
}

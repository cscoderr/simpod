import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';

class ThemeSwitcherButton extends ConsumerWidget {
  const ThemeSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = context.colorScheme;
    final isDark = themeMode == ThemeMode.dark;

    final solidBg = isDark
        ? AppColorsDark.surfaceCard
        : AppColorsLight.surfaceCard;
    final borderColor = isDark
        ? AppColorsDark.border(alpha: 0.12)
        : AppColorsLight.border(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: solidBg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          hoverColor: colorScheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 250),
              child: isDark
                  ? Icon(CupertinoIcons.sun_max_fill, size: 14)
                  : Icon(CupertinoIcons.moon_fill, size: 14),
            ),
          ),
        ),
      ),
    );
  }
}

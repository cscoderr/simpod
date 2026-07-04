import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';

class SimpodOutlineButton extends StatelessWidget {
  const SimpodOutlineButton({
    super.key,
    required this.text,
    this.loading = false,
    this.onTap,
  });
  final String text;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final live = context.isDarkMode
        ? AppColorsDark.statusLiveGlow
        : AppColorsLight.statusLive;
    return SizedBox(
      height: 28,
      child: loading
          ? const CircularProgressIndicator.adaptive()
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: live,
                side: BorderSide(color: live.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.sm - AppSpacing.xxs,
                  ),
                ),
              ),
              child: Text(
                text,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: live,
                ),
              ),
            ),
    );
  }
}

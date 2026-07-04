import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';

class SimpodFilledButton extends StatelessWidget {
  const SimpodFilledButton({
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
    final colorScheme = context.colorScheme;
    return SizedBox(
      height: 28,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm - AppSpacing.xxs),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : Text(
                text,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}

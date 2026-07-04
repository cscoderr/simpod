import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';

class DeviceSelectionHeader extends StatelessWidget {
  const DeviceSelectionHeader({required this.onRefresh, super.key});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xlg - AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                Text(
                  'Simulators',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface.withValues(alpha: 0.7),
                side: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.sm - AppSpacing.xxs,
                  ),
                ),
              ),
              child: Text(
                'Refresh',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

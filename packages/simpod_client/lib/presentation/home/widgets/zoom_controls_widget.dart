import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/core/core.dart';

class ZoomControlsWidget extends StatelessWidget {
  const ZoomControlsWidget({
    required this.zoomScale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onSetZoom,
    super.key,
  });

  final double zoomScale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<double> onSetZoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark = context.isDarkMode;
    final solidBg = isDark
        ? AppColorsDark.surfaceCard
        : AppColorsLight.surfaceCard;
    final borderColor = isDark
        ? AppColorsDark.border(alpha: 0.12)
        : AppColorsLight.border(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: solidBg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          _buildZoomActionButton(context, CupertinoIcons.minus, onZoomOut),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              '${(zoomScale * 100).toInt()}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildZoomActionButton(context, CupertinoIcons.add, onZoomIn),
          Container(
            width: 1,
            height: 16,
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
          _buildZoomTextButton(
            context,
            label: 'Fit',
            onTap: () => onSetZoom(0.85),
          ),
          _buildZoomTextButton(
            context,
            label: '1:1',
            onTap: () => onSetZoom(1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomActionButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm - AppSpacing.xxs),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppSpacing.sm - AppSpacing.xxs),
        ),
        child: Icon(
          icon,
          size: 11,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildZoomTextButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

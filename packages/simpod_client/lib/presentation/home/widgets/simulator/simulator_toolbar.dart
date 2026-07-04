import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/widgets/device_selector_menu.dart';
import 'package:simpod_core/simpod_core.dart';

class SimulatorToolbar extends StatelessWidget {
  const SimulatorToolbar({
    required this.deviceInfo,
    this.devices = const [],
    this.onDeviceSelected,
    super.key,
    this.onHomePressed,
    this.onHomeDoubleTap,
    this.onOrientationPressed,
    this.onAccessibilityPressed,
    this.onPowerPressed,
    this.onCaptureScreenshot,
  });
  final DeviceInfo? deviceInfo;
  final List<DeviceInfo> devices;
  final ValueChanged<DeviceInfo>? onDeviceSelected;
  final VoidCallback? onHomePressed;
  final VoidCallback? onHomeDoubleTap;
  final VoidCallback? onOrientationPressed;
  final VoidCallback? onAccessibilityPressed;
  final VoidCallback? onPowerPressed;
  final VoidCallback? onCaptureScreenshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = context.isDarkMode;
    final width = MediaQuery.sizeOf(context).width;
    final useCompactToolbar = width < 750;
    final useSmallToolbar = width < 550;

    final solidBg = isDark
        ? AppColorsDark.surfaceCard
        : AppColorsLight.surfaceCard;
    final borderColor = isDark
        ? AppColorsDark.border(alpha: 0.12)
        : AppColorsLight.border(alpha: 0.08);

    final borderRadius = BorderRadius.circular(
      (useSmallToolbar || useCompactToolbar)
          ? AppSpacing.sm + AppSpacing.xxs
          : 50,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: solidBg,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, AppSpacing.sm + AppSpacing.xxs),
          ),
        ],
      ),
      child: Flex(
        direction: (useCompactToolbar && !useSmallToolbar)
            ? Axis.vertical
            : Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: (useCompactToolbar && !useSmallToolbar) ? AppSpacing.xs : 0,
        children: [
          if (!useSmallToolbar)
            Padding(
              padding: useCompactToolbar
                  ? EdgeInsets.zero
                  : const EdgeInsetsDirectional.only(start: AppSpacing.xs),
              child: DeviceSelectorMenu(
                devices: devices,
                selectedDevice: deviceInfo,
                onDeviceSelected: onDeviceSelected,
                menuItemMinWidth: 260,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Flex(
                    direction: useCompactToolbar
                        ? Axis.horizontal
                        : Axis.vertical,
                    crossAxisAlignment: useCompactToolbar
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: useCompactToolbar ? AppSpacing.xs : 0,
                    children: [
                      Text(
                        deviceInfo?.name ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: useCompactToolbar
                              ? colorScheme.onSurface.withValues(alpha: 0.4)
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (useCompactToolbar)
                        Text(
                          '-',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      Text(
                        deviceInfo?.formattedRuntime ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: useCompactToolbar ? 14 : 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs + AppSpacing.xxxs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SimpodIconButton(
                  onPressed: onHomePressed,
                  onDoubleTap: onHomeDoubleTap,
                  tooltip: 'Home',
                  icon: CupertinoIcons.home,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                SimpodIconButton(
                  onPressed: onCaptureScreenshot,
                  tooltip: 'Capture Screen',
                  icon: CupertinoIcons.camera_on_rectangle,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                SimpodIconButton(
                  onPressed: onOrientationPressed,
                  tooltip: 'Rotate',
                  icon: CupertinoIcons.rotate_right,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_core/simpod_core.dart';

class DeviceSelectorMenu extends StatelessWidget {
  const DeviceSelectorMenu({
    required this.devices,
    required this.selectedDevice,
    required this.onDeviceSelected,
    required this.child,
    this.menuItemMinWidth = 240,
    super.key,
  });

  final List<DeviceInfo> devices;
  final DeviceInfo? selectedDevice;
  final ValueChanged<DeviceInfo>? onDeviceSelected;
  final Widget child;
  final double menuItemMinWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final enabled = devices.isNotEmpty && onDeviceSelected != null;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainer),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xxs),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
      menuChildren: [
        for (final device in devices)
          _DeviceMenuItem(
            device: device,
            isCurrent: selectedDevice?.udid == device.udid,
            minWidth: menuItemMinWidth,
            onPressed: () => onDeviceSelected!(device),
          ),
      ],
      builder: (context, controller, _) {
        return Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            hoverColor: colorScheme.primary.withValues(alpha: 0.05),
            onTap: enabled
                ? () =>
                      controller.isOpen ? controller.close() : controller.open()
                : null,
            child: child,
          ),
        );
      },
    );
  }
}

class _DeviceMenuItem extends StatelessWidget {
  const _DeviceMenuItem({
    required this.device,
    required this.isCurrent,
    required this.minWidth,
    required this.onPressed,
  });

  final DeviceInfo device;
  final bool isCurrent;
  final double minWidth;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBooted = device.state == DeviceState.booted;

    return MenuItemButton(
      onPressed: onPressed,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiveDot(isBooted: isBooted),
                    const SizedBox(width: 6),
                    Text(
                      device.formattedRuntime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isCurrent)
              Icon(Icons.check, size: 14, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.isBooted});

  final bool isBooted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isBooted
            ? AppColorsDark.statusLiveGlow
            : colorScheme.onSurface.withValues(alpha: 0.4),
        shape: BoxShape.circle,
        boxShadow: isBooted
            ? [
                BoxShadow(
                  color: AppColorsDark.statusLiveGlow.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/home.dart';
import 'package:simpod_core/simpod_core.dart' as simpod_core;

class SideControlBar extends ConsumerStatefulWidget {
  const SideControlBar({
    required this.udid,
    required this.onInspectorPressed,
    required this.onToggleAXSidebar,
    this.onDeviceSelected,
    this.onHomePressed,
    this.onHomeDoubleTap,
    this.onOrientationPressed,
    super.key,
  });
  final ValueChanged<simpod_core.DeviceInfo>? onDeviceSelected;
  final String udid;
  final VoidCallback onInspectorPressed;
  final VoidCallback onToggleAXSidebar;

  final VoidCallback? onHomePressed;
  final VoidCallback? onHomeDoubleTap;
  final VoidCallback? onOrientationPressed;

  @override
  ConsumerState<SideControlBar> createState() => _SideControlBarState();
}

class _SideControlBarState extends ConsumerState<SideControlBar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = context.isDarkMode;
    final state = ref.watch(homeNotifierProvider(widget.udid));

    final solidBg = isDark
        ? AppColorsDark.surfaceCard
        : AppColorsLight.surfaceCard;
    final borderColor = isDark
        ? AppColorsDark.border(alpha: 0.12)
        : AppColorsLight.border(alpha: 0.08);

    final isBooted =
        state.selectedDevice?.state == simpod_core.DeviceState.booted;
    final isVertical = !isMobile;
    final borderRadius = BorderRadius.circular(
      isVertical ? 10.0 : (AppSpacing.xlg - AppSpacing.xs),
    );

    if (isMobile && !_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = true;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: solidBg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDotIndicator(isBooted: isBooted),
                const SizedBox(width: 8),
                Text(
                  state.selectedDevice?.name ?? 'No Device',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.sm : AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isVertical
              ? (AppSpacing.xs - AppSpacing.xxs)
              : AppSpacing.xs,
          vertical: isVertical
              ? AppSpacing.xs
              : (AppSpacing.xs - AppSpacing.xxs),
        ),
        decoration: BoxDecoration(
          color: solidBg,
          border: Border.all(color: borderColor),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isVertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionGroup(
                    isVertical: isVertical,
                    showLeftSidebar: state.showLeftSidebar,
                    onToggleAXSidebar: widget.onToggleAXSidebar,
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionGroup(
                    isVertical: isVertical,
                    showLeftSidebar: state.showLeftSidebar,
                    onToggleAXSidebar: widget.onToggleAXSidebar,
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    margin: EdgeInsets.symmetric(
                      horizontal: isMobile ? 3.0 : 4.0,
                    ),
                    color: context.colorScheme.outlineVariant,
                  ),
                  _DeviceStatusDisplay(
                    isMobile: isMobile,
                    isVertical: isVertical,
                    devices: state.devices,
                    selectedDevice: state.selectedDevice,
                    onDeviceSelected: (device) {
                      widget.onDeviceSelected?.call(device);
                      if (isMobile) {
                        setState(() {
                          _isExpanded = false;
                        });
                      }
                    },
                  ),
                  if (isMobile) ...[
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      color: context.colorScheme.outlineVariant,
                    ),
                    _ActionIcon(
                      icon: CupertinoIcons.home,
                      tooltip: 'Home',
                      onTap: widget.onHomePressed,
                    ),
                    _ActionIcon(
                      icon: CupertinoIcons.camera_on_rectangle,
                      tooltip: 'Save Screen',
                      onTap: () {},
                    ),
                    _ActionIcon(
                      icon: CupertinoIcons.rotate_right,
                      tooltip: 'Rotate',
                      onTap: widget.onOrientationPressed,
                    ),
                  ],
                  if (isMobile) ...[
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      color: context.colorScheme.outlineVariant,
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = false;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          CupertinoIcons.chevron_up,
                          size: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.isVertical,
    required this.showLeftSidebar,
    required this.onToggleAXSidebar,
  });

  final bool isVertical;
  final bool showLeftSidebar;
  final VoidCallback onToggleAXSidebar;

  @override
  Widget build(BuildContext context) {
    final children = [
      _ActionIcon(
        icon: CupertinoIcons.square_stack_3d_up,
        tooltip: 'Toggle AX Tree',
        isActive: showLeftSidebar,
        onTap: onToggleAXSidebar,
      ),
    ];

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xxs,
        children: children,
      );
    } else {
      return Row(mainAxisSize: MainAxisSize.min, children: children);
    }
  }
}

class _DeviceStatusDisplay extends StatelessWidget {
  const _DeviceStatusDisplay({
    required this.isMobile,
    required this.isVertical,
    this.devices = const [],
    required this.selectedDevice,
    this.onDeviceSelected,
  });

  final bool isMobile;
  final bool isVertical;
  final List<simpod_core.DeviceInfo> devices;
  final simpod_core.DeviceInfo? selectedDevice;
  final ValueChanged<simpod_core.DeviceInfo>? onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isVertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  CupertinoIcons.device_phone_portrait,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        selectedDevice?.state == simpod_core.DeviceState.booted
                        ? AppColorsDark.statusLiveGlow
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    boxShadow:
                        selectedDevice?.state == simpod_core.DeviceState.booted
                        ? [
                            BoxShadow(
                              color: AppColorsDark.statusLiveGlow.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Horizontal layout (can be mobile expanded horizontal control bar)
    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: isMobile ? 6.0 : AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: isMobile ? 4.0 : AppSpacing.sm,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedDevice?.name ?? 'Unknown',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.2,
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
              if (!isMobile)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            selectedDevice?.state ==
                                simpod_core.DeviceState.booted
                            ? AppColorsDark.statusLiveGlow
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        boxShadow:
                            selectedDevice?.state ==
                                simpod_core.DeviceState.booted
                            ? [
                                BoxShadow(
                                  color: AppColorsDark.statusLiveGlow
                                      .withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    Text(
                      selectedDevice?.runtime ?? 'Unknown',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (isMobile && devices.isNotEmpty && onDeviceSelected != null)
            Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
        ],
      ),
    );

    if (isMobile && devices.isNotEmpty && onDeviceSelected != null) {
      return DeviceSelectorMenu(
        devices: devices,
        selectedDevice: selectedDevice,
        onDeviceSelected: onDeviceSelected,
        menuItemMinWidth: 200,
        child: content,
      );
    }

    return content;
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final paddingVal = isMobile ? 6.0 : 8.0;
    final iconSizeVal = isMobile ? 16.0 : 20.0;

    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(fontSize: 10, color: Colors.white),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: HoverBuilder(
        builder: (context, isHovered) {
          final activeBg = isActive
              ? colorScheme.primary.withValues(alpha: 0.08)
              : (isHovered
                    ? colorScheme.primary.withValues(alpha: 0.04)
                    : Colors.transparent);

          final iconColor = isActive
              ? colorScheme.primary
              : (isHovered
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.5));

          return AnimatedScale(
            scale: isHovered ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Material(
              type: MaterialType.transparency,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                hoverColor: Colors.transparent,
                onTap: onTap ?? () {},
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.all(paddingVal),
                  decoration: BoxDecoration(
                    color: activeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: iconSizeVal, color: iconColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_core/simpod_core.dart';

class DeviceListRow extends StatefulWidget {
  const DeviceListRow({
    required this.device,
    this.isEven = false,
    required this.onBoot,
    required this.onStreamRequested,
    super.key,
  });

  final DeviceInfo device;
  final bool isEven;
  final VoidCallback onBoot;
  final VoidCallback onStreamRequested;

  @override
  State<DeviceListRow> createState() => _DeviceListRowState();
}

class _DeviceListRowState extends State<DeviceListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final theme = context.theme;
    final isBooted = widget.device.state == DeviceState.booted;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withValues(alpha: 0.04)
              : widget.isEven
              ? Colors.transparent
              : colorScheme.primary.withValues(alpha: 0.01),
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.04),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 25,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md + AppSpacing.xxs,
                ),
                child: Row(
                  spacing: AppSpacing.sm,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMobile)
                      Container(
                        width: AppSpacing.sm - AppSpacing.xxs,
                        height: AppSpacing.sm - AppSpacing.xxs,
                        decoration: BoxDecoration(
                          color: isBooted
                              ? AppColorsDark.statusLiveGlow
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          boxShadow: isBooted
                              ? [
                                  BoxShadow(
                                    color: AppColorsDark.statusLiveGlow
                                        .withValues(alpha: 0.4),
                                    blurRadius: AppSpacing.sm - AppSpacing.xxs,
                                    spreadRadius: AppSpacing.xxxs,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        widget.device.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _hovered
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // State Column (hidden on mobile)
            if (!isMobile)
              Expanded(
                flex: 15,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md + AppSpacing.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.sm - AppSpacing.xxs,
                    children: [
                      Container(
                        width: AppSpacing.sm - AppSpacing.xxs,
                        height: AppSpacing.sm - AppSpacing.xxs,
                        decoration: BoxDecoration(
                          color: isBooted
                              ? AppColorsDark.statusLiveGlow
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          boxShadow: isBooted
                              ? [
                                  BoxShadow(
                                    color: AppColorsDark.statusLiveGlow
                                        .withValues(alpha: 0.4),
                                    blurRadius: AppSpacing.sm - AppSpacing.xxs,
                                    spreadRadius: AppSpacing.xxxs,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${widget.device.state.name.substring(0, 1).toUpperCase()}${widget.device.state.name.substring(1)}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Runtime Column (hidden on mobile)
            if (!isMobile)
              Expanded(
                flex: 15,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md + AppSpacing.xxs,
                  ),
                  child: Text(
                    widget.device.formattedRuntime,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            // Actions Column (always shown)
            Expanded(
              flex: isMobile ? 12 : 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + AppSpacing.xxs,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBooted)
                          SimpodOutlineButton(
                            text: 'Stream',
                            onTap: widget.onStreamRequested,
                          )
                        else
                          SimpodFilledButton(
                            text: 'Boot',
                            onTap: widget.onBoot,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

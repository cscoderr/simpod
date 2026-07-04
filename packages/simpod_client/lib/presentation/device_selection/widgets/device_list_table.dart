import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/device_selection/device_selection.dart';
import 'package:simpod_core/simpod_core.dart';

class DeviceListTable extends ConsumerWidget {
  const DeviceListTable({
    required this.onStreamRequested,
    required this.onBootRequested,
    super.key,
  });

  final Future<void> Function(DeviceInfo device) onStreamRequested;
  final ValueChanged<DeviceInfo> onBootRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTableHeaders(context),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: devices.when(
            data: (data) {
              return _buildDeviceList(context, data);
            },
            error: (error, _) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xlg - AppSpacing.xs),
                child: Text('${error.toString()}'),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(AppSpacing.xlg - AppSpacing.xs),
              child: const CircularProgressIndicator.adaptive(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaders(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 25, child: _buildHeaderCell(context, 'Name')),
          if (!isMobile) ...[
            Expanded(flex: 15, child: _buildHeaderCell(context, 'State')),
            Expanded(flex: 15, child: _buildHeaderCell(context, 'Runtime')),
          ],
          Expanded(
            flex: isMobile ? 12 : 22,
            child: _buildHeaderCell(context, 'Actions', alignRight: true),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    String title, {
    bool alignRight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Text(
        title,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: context.textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, List<DeviceInfo> devices) {
    final running = <DeviceInfo>[];
    final available = <DeviceInfo>[];
    for (final device in devices) {
      if (device.state == DeviceState.booted) {
        running.add(device);
      } else {
        available.add(device);
      }
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          if (running.isNotEmpty) ...[
            _buildSectionHeader(context, 'RUNNING', running.length),
            for (final (index, device) in running.indexed)
              DeviceListRow(
                device: device,
                isEven: index.isEven,
                onBoot: () => onBootRequested(device),
                onStreamRequested: () => onStreamRequested(device),
              ),
          ],
          if (available.isNotEmpty) ...[
            _buildSectionHeader(context, 'AVAILABLE', available.length),
            for (final (index, device) in available.indexed)
              DeviceListRow(
                device: device,
                isEven: index.isEven,
                onBoot: () => onBootRequested(device),
                onStreamRequested: () => onStreamRequested(device),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        '$title ($count)',
        style: context.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

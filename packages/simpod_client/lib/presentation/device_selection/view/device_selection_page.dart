import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/device_selection/device_selection.dart';
import 'package:simpod_core/simpod_core.dart';
import 'package:web/web.dart' as web;

class DeviceSelectionPage extends ConsumerWidget {
  const DeviceSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final colorScheme = context.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.surfaceDim, theme.colorScheme.surface],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xlg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SIMPOD',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  spacing: AppSpacing.xxs,
                  mainAxisAlignment: .center,
                  children: [
                    Flexible(
                      child: Text(
                        'Select a simulator to boot, or start one manually via ',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm - AppSpacing.xxs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        'simpod --detach',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xlg),
                _DevicesTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevicesTable extends ConsumerWidget {
  const _DevicesTable();

  void _openDevice(BuildContext context, DeviceInfo device) {
    web.window.sessionStorage.setItem(
      'deviceInfo',
      jsonEncode(device.toJson()),
    );
    context.goNamed('home', queryParameters: {'device': device.udid});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final colorScheme = context.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.min(680.0, width - 32.0)),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DeviceSelectionHeader(
                  onRefresh: () =>
                      ref.invalidate(devicesProvider, asReload: true),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outline.withValues(alpha: 0.15),
                ),
                DeviceListTable(
                  onBootRequested: (device) => _openDevice(context, device),
                  onStreamRequested: (device) async =>
                      _openDevice(context, device),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

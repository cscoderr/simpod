import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/home.dart';
import 'package:simpod_client/presentation/home/notifier/ax_tree_provider.dart';
import 'package:simpod_client/presentation/home/widgets/ax/ax_tree_widget.dart';
import 'package:simpod_core/simpod_core.dart';

class ControlsSidebar extends ConsumerStatefulWidget {
  const ControlsSidebar({required this.udid, this.onClose, super.key});

  final String udid;
  final VoidCallback? onClose;

  @override
  ConsumerState<ControlsSidebar> createState() => _ControlsSidebarState();
}

class _ControlsSidebarState extends ConsumerState<ControlsSidebar> {
  final _urlController = TextEditingController();
  final _latController = TextEditingController(text: '37.7749');
  final _lonController = TextEditingController(text: '-122.4194');
  final _timeController = TextEditingController(text: '9:41');
  final _bundleIdController = TextEditingController();

  double _batteryLevel = 100;
  String _permissionService = 'photos';
  late StreamSettings _streamSettings;

  bool _contrastOn = false;
  final Map<AccessibilitySetting, bool> _axToggles = {
    for (final setting in AccessibilitySetting.values) setting: false,
  };

  static const _locationPresets = <(String, double, double)>[
    ('San Francisco', 37.7749, -122.4194),
    ('New York', 40.7128, -74.0060),
    ('London', 51.5074, -0.1278),
    ('Tokyo', 35.6762, 139.6503),
  ];

  static const _permissionServices = <(String, String)>[
    ('photos', 'Photos'),
    ('photos-add', 'Photos (add only)'),
    ('camera', 'Camera'),
    ('microphone', 'Microphone'),
    ('location', 'Location'),
    ('location-always', 'Location (always)'),
    ('contacts', 'Contacts'),
    ('calendar', 'Calendar'),
    ('reminders', 'Reminders'),
    ('media-library', 'Media library'),
    ('motion', 'Motion'),
    ('siri', 'Siri'),
    ('all', 'All services'),
  ];

  @override
  void initState() {
    super.initState();
    _streamSettings = ref.read(webSocketServiceProvider).settings;
    _loadAccessibilityValues();
  }

  Future<void> _loadAccessibilityValues() async {
    final notifier = _notifier;
    final values = await Future.wait([
      notifier.getContrast(),
      for (final setting in AccessibilitySetting.values)
        notifier.getAccessibility(setting),
    ]);
    if (!mounted) return;
    setState(() {
      _contrastOn = values.first ?? _contrastOn;
      for (final (i, setting) in AccessibilitySetting.values.indexed) {
        _axToggles[setting] = values[i + 1] ?? _axToggles[setting]!;
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _timeController.dispose();
    _bundleIdController.dispose();
    super.dispose();
  }

  HomeNotifier get _notifier =>
      ref.read(homeNotifierProvider(widget.udid).notifier);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    final (enableAccessibility, axTarget) = ref.watch(
      homeNotifierProvider(
        widget.udid,
      ).select((s) => (s.enableAccessibility, s.selectedDevice?.udid)),
    );

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccordionSection(
                    title: 'ACCESSIBILITY',
                    initiallyExpanded: true,
                    trailing: SimpodSwitch(
                      value: enableAccessibility,
                      onChanged: (_) => _notifier.toggleAccessibility(),
                    ),
                    child: _buildAccessibilityContent(
                      enableAccessibility: enableAccessibility,
                      axTarget: axTarget ?? widget.udid,
                    ),
                  ),
                  _AccordionSection(
                    title: 'DEVICE',
                    initiallyExpanded: true,
                    child: _buildDeviceContent(),
                  ),
                  _AccordionSection(
                    title: 'DEEP LINK',
                    child: _buildDeepLinkContent(),
                  ),
                  _AccordionSection(
                    title: 'LOCATION',
                    child: _buildLocationContent(),
                  ),
                  // _AccordionSection(
                  //   title: 'PERMISSIONS',
                  //   child: _buildPermissionsContent(),
                  // ),
                  _AccordionSection(
                    title: 'STATUS BAR OVERRIDE',
                    child: _buildStatusBarContent(),
                  ),
                  _AccordionSection(
                    title: 'STREAM',
                    child: _buildStreamContent(),
                    withDivider: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xxs,
      ),
      child: Row(
        children: [
          SimpodIconButton(
            icon: CupertinoIcons.sidebar_left,
            iconSize: 18,
            tooltip: 'Hide toolkit',
            onPressed: widget.onClose,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'SIMULATOR TOOLKIT',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.8,
              color: context.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          const ThemeSwitcherButton(),
        ],
      ),
    );
  }

  Widget _buildAccessibilityContent({
    required bool enableAccessibility,
    required String axTarget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!enableAccessibility)
          _buildAxEmptyState()
        else
          _buildAxLiveContent(axTarget),
      ],
    );
  }

  static IconData _accessibilityIcon(AccessibilitySetting setting) =>
      switch (setting) {
        AccessibilitySetting.reduceMotion => CupertinoIcons.slowmo,
        AccessibilitySetting.reduceTransparency =>
          CupertinoIcons.rectangle_stack,
        AccessibilitySetting.showBorders => CupertinoIcons.capsule,
      };

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _SettingRow(
      icon: icon,
      label: label,
      trailing: SimpodSwitch(onChanged: onChanged, value: value),
    );
  }

  Widget _buildAxEmptyState() {
    final colorScheme = context.colorScheme;
    return _InsetPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.viewfinder,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Inspector is off',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Turn on to inspect the UI as it changes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              height: 1.5,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RowButton(
            label: 'Enable inspector',
            primary: true,
            expand: true,
            onTap: _notifier.toggleAccessibility,
          ),
        ],
      ),
    );
  }

  Widget _buildAxLiveContent(String axTarget) {
    final colorScheme = context.colorScheme;
    final notifier = _notifier;
    final root = ref.watch(axTreeProvider(axTarget));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 250,
          child: root == null
              ? Center(
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      CircularProgressIndicator.adaptive(),
                      Text(
                        'Waiting for acccessibility data...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                )
              : AXTreeWidget(
                  root: root,
                  onNodeSelected: (node) =>
                      notifier.axOverlayController.highlightWithChildren(node),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListenableBuilder(
          listenable: notifier.axOverlayController,
          builder: (context, _) {
            final node = notifier.axOverlayController.focused;
            if (node == null) {
              return _InsetPanel(
                child: Text(
                  'Select an element in the tree to inspect it',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              );
            }
            return _InsetPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NODE PROPERTIES',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 0.6,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Column(
                    spacing: AppSpacing.xs,
                    children: [
                      _PropertyRow('Role', node.role),
                      if (node.subrole != null)
                        _PropertyRow('Subrole', node.subrole!),
                      _PropertyRow('Label', node.label ?? '–'),
                      _PropertyRow('Value', node.value ?? '–'),
                      _PropertyRow('Title', node.title ?? '–'),
                      _PropertyRow('Identifier', node.identifier ?? '–'),
                      _PropertyRow('Help', node.help ?? '–'),
                      _PropertyRow(
                        'Frame',
                        '[${node.frameX.toInt()}, ${node.frameY.toInt()}, '
                            '${node.frameWidth.toInt()}×${node.frameHeight.toInt()}]',
                      ),
                      _PropertyRow('Enabled', node.enabled.toString()),
                      _PropertyRow('Focused', node.focused.toString()),
                      _PropertyRow('Hidden', node.hidden.toString()),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeviceContent() {
    return Column(
      children: [
        _SettingRow(
          icon: CupertinoIcons.circle_lefthalf_fill,
          label: 'Appearance',
          trailing: _Dropdown<String>(
            width: 96,
            value: null,
            hint: 'Set…',
            items: const [
              (value: 'light', label: 'Light'),
              (value: 'dark', label: 'Dark'),
            ],
            onChanged: (theme) => _notifier.setAppearance(theme),
          ),
        ),
        _SettingRow(
          icon: CupertinoIcons.house,
          label: 'Home',
          trailing: _RowButton(
            label: 'Press',
            onTap: _notifier.handleHomePressed,
          ),
        ),
        _SettingRow(
          icon: CupertinoIcons.square_on_square,
          label: 'App Switcher',
          trailing: _RowButton(
            label: 'Press',
            onTap: () => _notifier.handleHomePressed(true),
          ),
        ),
        _SettingRow(
          icon: CupertinoIcons.lock,
          label: 'Lock',
          trailing: _RowButton(
            label: 'Press',
            onTap: () => _notifier.pressButton('lock'),
          ),
        ),
        _SettingRow(
          icon: CupertinoIcons.mic,
          label: 'Siri',
          trailing: _RowButton(
            label: 'Press',
            onTap: () => _notifier.pressButton('siri'),
          ),
        ),
        _SettingRow(
          icon: CupertinoIcons.rotate_right,
          label: 'Rotate',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              _RowIconButton(
                icon: CupertinoIcons.rotate_left,
                tooltip: 'Rotate left',
                onTap: _notifier.rotateLeft,
              ),
              _RowIconButton(
                icon: CupertinoIcons.rotate_right,
                tooltip: 'Rotate right',
                onTap: _notifier.toggleOrientation,
              ),
            ],
          ),
        ),
        _SettingRow(
          icon: CupertinoIcons.camera,
          label: 'Screenshot',
          trailing: _RowButton(label: 'Capture', onTap: _captureScreenshot),
        ),
        _SettingRow(
          icon: CupertinoIcons.textformat_size,
          label: 'Text size',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              _RowIconButton(
                icon: CupertinoIcons.minus,
                tooltip: 'Decrease text size',
                onTap: () => _notifier.setTextSize('decrement'),
              ),
              _RowIconButton(
                icon: CupertinoIcons.plus,
                tooltip: 'Increase text size',
                onTap: () => _notifier.setTextSize('increment'),
              ),
            ],
          ),
        ),
        _buildToggleRow(
          icon: CupertinoIcons.circle_righthalf_fill,
          label: 'Increase Contrast',
          value: _contrastOn,
          onChanged: (enabled) {
            setState(() => _contrastOn = enabled);
            _notifier.setContrast(enabled);
          },
        ),
        for (final setting in AccessibilitySetting.values)
          _buildToggleRow(
            icon: _accessibilityIcon(setting),
            label: setting.label,
            value: _axToggles[setting]!,
            onChanged: (enabled) {
              setState(() => _axToggles[setting] = enabled);
              _notifier.setAccessibility(setting, enabled);
            },
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Future<void> _captureScreenshot() async {
    final result = await _notifier.captureScreenshot();
    if (!mounted) return;
    _showToast(result.message, isError: !result.success, preview: result.bytes);
  }

  Widget _buildDeepLinkContent() {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: SimpodCustomTextField(
            controller: _urlController,
            placeholder: 'myapp://route or https://…',
            onSubmitted: (_) => _openDeepLink(),
          ),
        ),
        _RowButton(label: 'Open', primary: true, onTap: _openDeepLink),
      ],
    );
  }

  Future<void> _openDeepLink() async {
    final result = await _notifier.openUrl(_urlController.text);
    if (!mounted) return;
    _showToast(result.message, isError: !result.success);
  }

  Widget _buildLocationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: SimpodCustomTextField(
                controller: _latController,
                placeholder: 'Latitude',
              ),
            ),
            Expanded(
              child: SimpodCustomTextField(
                controller: _lonController,
                placeholder: 'Longitude',
              ),
            ),
            _RowButton(label: 'Set', primary: true, onTap: _applyLocation),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.xs + AppSpacing.xxs,
          runSpacing: AppSpacing.xs + AppSpacing.xxs,
          children: [
            for (final (name, lat, lon) in _locationPresets)
              _Chip(
                label: name,
                onTap: () {
                  _latController.text = lat.toString();
                  _lonController.text = lon.toString();
                  _applyLocation();
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyLocation() async {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null || lon == null) {
      _showToast('Latitude and longitude must be numeric', isError: true);
      return;
    }
    final result = await _notifier.setLocation(lat, lon);
    if (!mounted) return;
    _showToast(result.message, isError: !result.success);
  }

  Widget _buildPermissionsContent() {
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          icon: CupertinoIcons.checkmark_shield,
          label: 'Service',
          trailing: _Dropdown<String>(
            width: 150,
            value: _permissionService,
            items: [
              for (final (value, label) in _permissionServices)
                (value: value, label: label),
            ],
            onChanged: (value) => setState(() => _permissionService = value),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SimpodCustomTextField(
          controller: _bundleIdController,
          placeholder: 'com.example.app',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: _RowButton(
                label: 'Grant',
                primary: true,
                expand: true,
                onTap: () => _applyPermission('grant'),
              ),
            ),
            Expanded(
              child: _RowButton(
                label: 'Revoke',
                expand: true,
                onTap: () => _applyPermission('revoke'),
              ),
            ),
            Expanded(
              child: _RowButton(
                label: 'Reset',
                expand: true,
                onTap: () => _applyPermission('reset'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Grant and revoke require a bundle id.',
          style: GoogleFonts.inter(
            fontSize: 9.5,
            height: 1.4,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Future<void> _applyPermission(String action) async {
    final bundleId = _bundleIdController.text.trim();
    if (action != 'reset' && bundleId.isEmpty) {
      _showToast('Enter the app bundle id to $action', isError: true);
      return;
    }
    final result = await _notifier.setPermission(
      action: action,
      service: _permissionService,
      bundleId: bundleId.isEmpty ? null : bundleId,
    );
    if (!mounted) return;
    _showToast(result.message, isError: !result.success);
  }

  Widget _buildStatusBarContent() {
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          icon: CupertinoIcons.battery_75_percent,
          label: 'Battery',
          trailing: Text(
            '${_batteryLevel.toInt()}%',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        CupertinoSlider(
          value: _batteryLevel,
          max: 100,
          activeColor: colorScheme.primary,
          onChanged: (value) => setState(() => _batteryLevel = value),
        ),
        const SizedBox(height: AppSpacing.xs),
        _SettingRow(
          icon: CupertinoIcons.clock,
          label: 'Clock',
          trailing: SizedBox(
            width: 110,
            child: SimpodCustomTextField(
              controller: _timeController,
              placeholder: '9:41',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: _RowButton(
                label: 'Apply override',
                primary: true,
                expand: true,
                onTap: () {
                  _notifier.setStatusBarOverride(
                    batteryLevel: _batteryLevel.toInt(),
                    time: _timeController.text,
                  );
                  _showToast('Status bar overrides applied', isError: false);
                },
              ),
            ),
            Expanded(
              child: _RowButton(
                label: 'Clear all',
                expand: true,
                onTap: () {
                  _notifier.clearStatusBarOverrides();
                  _showToast('Status bar overrides cleared', isError: false);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreamContent() {
    final service = ref.read(webSocketServiceProvider);
    final avccSupported = service.avccSupported ?? true;
    final usesH264 =
        _streamSettings.format != StreamFormatPreference.mjpeg && avccSupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          icon: CupertinoIcons.film,
          label: 'Codec',
          trailing: _Dropdown<StreamFormatPreference>(
            width: 130,
            value: _streamSettings.format,
            items: [
              (value: StreamFormatPreference.auto, label: 'Auto'),
              if (avccSupported)
                (value: StreamFormatPreference.avcc, label: 'H.264'),
              (value: StreamFormatPreference.mjpeg, label: 'MJPEG'),
            ],
            onChanged: (format) =>
                _applyStream(_streamSettings.copyWith(format: format)),
          ),
        ),
        if (usesH264) ...[
          _SettingRow(
            icon: CupertinoIcons.speedometer,
            label: 'Frame rate',
            trailing: _Dropdown<int>(
              width: 110,
              value: _streamSettings.fps,
              items: const [
                (value: 30, label: '30 fps'),
                (value: 60, label: '60 fps'),
                (value: 120, label: '120 fps'),
              ],
              onChanged: (fps) =>
                  _applyStream(_streamSettings.copyWith(fps: fps)),
            ),
          ),
          _SettingRow(
            icon: CupertinoIcons.gauge,
            label: 'Bitrate',
            trailing: _Dropdown<int>(
              width: 110,
              value: _streamSettings.bitrateMbps,
              items: const [
                (value: 2, label: '2 Mbps'),
                (value: 4, label: '4 Mbps'),
                (value: 8, label: '8 Mbps'),
                (value: 16, label: '16 Mbps'),
              ],
              onChanged: (mbps) =>
                  _applyStream(_streamSettings.copyWith(bitrateMbps: mbps)),
            ),
          ),
        ] else
          _SettingRow(
            icon: CupertinoIcons.photo,
            label: 'Quality',
            trailing: _Dropdown<double>(
              width: 110,
              value: _streamSettings.quality,
              items: const [
                (value: 0.4, label: 'Low'),
                (value: 0.7, label: 'Medium'),
                (value: 0.9, label: 'High'),
              ],
              onChanged: (quality) =>
                  _applyStream(_streamSettings.copyWith(quality: quality)),
            ),
          ),
      ],
    );
  }

  Future<void> _applyStream(StreamSettings next) async {
    setState(() => _streamSettings = next);
    await _notifier.applyStreamSettings(next);
    if (!mounted) return;
    _showToast('Stream settings applied', isError: false);
  }

  void _showToast(String message, {required bool isError, Uint8List? preview}) {
    showSimpodToast(context, message, isError: isError, preview: preview);
  }
}

class _AccordionSection extends StatefulWidget {
  const _AccordionSection({
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
    this.withDivider = true,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;
  final bool withDivider;

  @override
  State<_AccordionSection> createState() => _AccordionSectionState();
}

class _AccordionSectionState extends State<_AccordionSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: HoverBuilder(
            builder: (context, isHovered) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: colorScheme.onSurface.withValues(
                          alpha: isHovered ? 0.9 : 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.trailing != null) ...[
                      widget.trailing!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: AppMotion.base,
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        AnimatedSize(
          duration: AppMotion.base,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.md,
                  ),
                  child: widget.child,
                ),
        ),
        if (widget.withDivider) const Divider(height: 1),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColorsDark.tint(alpha: 0.06)
                  : AppColorsLight.tint(alpha: 0.05),
              border: Border.all(
                color: isDark
                    ? AppColorsDark.border(alpha: 0.06)
                    : AppColorsLight.border(alpha: 0.06),
              ),
              borderRadius: AppRadius.all(7),
            ),
            child: Icon(
              icon,
              size: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDarkMode;

    return HoverBuilder(
      builder: (context, isHovered) {
        final background = primary
            ? colorScheme.primary.withValues(alpha: isHovered ? 0.85 : 1)
            : isHovered
            ? (isDark
                  ? AppColorsDark.tint(alpha: 0.08)
                  : AppColorsLight.tint(alpha: 0.06))
            : Colors.transparent;
        final border = primary
            ? Colors.transparent
            : isDark
            ? AppColorsDark.border(alpha: isHovered ? 0.25 : 0.12)
            : AppColorsLight.border(alpha: isHovered ? 0.3 : 0.15);
        final foreground = primary
            ? colorScheme.onPrimary
            : colorScheme.onSurface.withValues(alpha: isHovered ? 0.95 : 0.7);

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border),
              borderRadius: AppRadius.all(6),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: foreground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDarkMode;

    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        builder: (context, isHovered) {
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 26,
              height: 24,
              decoration: BoxDecoration(
                color: isHovered
                    ? (isDark
                          ? AppColorsDark.tint(alpha: 0.08)
                          : AppColorsLight.tint(alpha: 0.06))
                    : Colors.transparent,
                border: Border.all(
                  color: isDark
                      ? AppColorsDark.border(alpha: isHovered ? 0.25 : 0.12)
                      : AppColorsLight.border(alpha: isHovered ? 0.3 : 0.15),
                ),
                borderRadius: AppRadius.all(6),
              ),
              child: Icon(
                icon,
                size: 12,
                color: colorScheme.onSurface.withValues(
                  alpha: isHovered ? 0.95 : 0.7,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InsetPanel extends StatelessWidget {
  const _InsetPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColorsDark.tint(alpha: 0.02)
            : AppColorsLight.tint(alpha: 0.02),
        border: Border.all(
          color: isDark
              ? AppColorsDark.border(alpha: 0.05)
              : AppColorsLight.border(alpha: 0.05),
        ),
        borderRadius: AppRadius.allSm,
      ),
      child: child,
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final live = AppColorsLight.statusLive;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - AppSpacing.xxs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: live.withValues(alpha: 0.12),
        borderRadius: AppRadius.all(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          const StatusDotIndicator(isBooted: true),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 8.5,
              letterSpacing: 0.8,
              color: live,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow(this.propertyKey, this.value);

  final String propertyKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            propertyKey,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: onSurface.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w600,
              color: onSurface.withValues(alpha: 0.8),
              fontSize: 9.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDarkMode;

    return HoverBuilder(
      builder: (context, isHovered) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xxs,
              vertical: AppSpacing.xs + AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark
                        ? AppColorsDark.tint(alpha: 0.08)
                        : AppColorsLight.tint(alpha: 0.06))
                  : Colors.transparent,
              border: Border.all(
                color: isDark
                    ? AppColorsDark.border(alpha: isHovered ? 0.25 : 0.12)
                    : AppColorsLight.border(alpha: isHovered ? 0.3 : 0.15),
              ),
              borderRadius: AppRadius.all(AppRadius.full),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: colorScheme.onSurface.withValues(
                  alpha: isHovered ? 0.95 : 0.65,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.width,
  });

  final T? value;
  final String? hint;
  final double? width;
  final List<({T value, String label})> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDarkMode;

    return Container(
      width: width,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark
            ? AppColorsDark.tint(alpha: 0.04)
            : AppColorsLight.tint(alpha: 0.03),
        border: Border.all(
          color: isDark
              ? AppColorsDark.border(alpha: 0.12)
              : AppColorsLight.border(alpha: 0.15),
        ),
        borderRadius: AppRadius.all(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
          borderRadius: AppRadius.allSm,
          dropdownColor: isDark
              ? AppColorsDark.surfaceOverlay
              : AppColorsLight.surface,
          icon: Icon(
            CupertinoIcons.chevron_up_chevron_down,
            size: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(value: item.value, child: Text(item.label)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

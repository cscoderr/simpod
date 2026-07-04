import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/core/core.dart';
import 'package:web/web.dart' as web;

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _tokenController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _pair() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    setState(() => _submitting = true);

    web.window.location.href = '/pair?t=${Uri.encodeQueryComponent(token)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xlg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.qr_code_2_rounded, size: 56, color: scheme.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Pair this device',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Run `simpod pair` on the machine hosting the simulator and '
                  'scan the QR with this device, or paste the access token '
                  'below.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xlg),
                TextField(
                  controller: _tokenController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Access token',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _pair(),
                ),
                const SizedBox(height: AppSpacing.md),
                SimpodFilledButton(
                  onTap: _submitting ? null : _pair,
                  text: 'Pair',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

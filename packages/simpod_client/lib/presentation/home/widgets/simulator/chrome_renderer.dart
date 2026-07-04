import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_client/presentation/home/notifier/device_chrome_provider.dart';
import 'package:simpod_client/presentation/home/notifier/device_definition_provider.dart';
import 'package:simpod_client/presentation/home/widgets/simulator/chrome_layout.dart';

class ChromeRenderer extends ConsumerWidget {
  const ChromeRenderer({
    super.key,
    required this.udid,
    required this.baseUrl,
    required this.child,
  });
  final String udid;
  final String baseUrl;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(deviceChromeProvider(udid))
        .when(
          data: (data) =>
              _ChromeFrame(chrome: data, baseUrl: baseUrl, child: child),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phonelink_erase_outlined,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load device',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(deviceDefinitionProvider(udid)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          loading: () => Center(child: CircularProgressIndicator.adaptive()),
        );
  }
}

/// Warms every chrome image (bezel + each button's rest/pressed) into the image
/// cache before showing the frame, so the device appears in one shot instead of
/// the bezel and buttons popping in one-by-one as their requests resolve.
class _ChromeFrame extends StatefulWidget {
  const _ChromeFrame({
    required this.chrome,
    required this.baseUrl,
    required this.child,
  });

  final SimulatorChromeConfig chrome;
  final String baseUrl;
  final Widget child;

  @override
  State<_ChromeFrame> createState() => _ChromeFrameState();
}

class _ChromeFrameState extends State<_ChromeFrame> {
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _precache();
  }

  @override
  void didUpdateWidget(_ChromeFrame old) {
    super.didUpdateWidget(old);
    if (old.chrome != widget.chrome) {
      _ready = false;
      _precache();
    }
  }

  Future<void> _precache() async {
    final urls = <String>{
      widget.chrome.bezelImage.rest,
      for (final b in widget.chrome.buttons) ...[
        b.images.rest,
        b.images.pressed,
      ],
    };

    await Future.wait(
      urls.map(
        (u) =>
            precacheImage(NetworkImage(u), context).catchError((Object _) {}),
      ),
    );

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return ChromeLayout(
      chrome: widget.chrome,
      baseUrl: widget.baseUrl,
      child: widget.child,
    );
  }
}

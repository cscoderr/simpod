import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/widgets/widgets.dart';

class SimulatorWidget extends ConsumerStatefulWidget {
  const SimulatorWidget({
    required this.udid,
    required this.streamUrl,
    required this.simulatorFocusNode,
    required this.webSocketService,
    required this.inputController,
    required this.axOverlayController,
    required this.onOverlayTap,
    required this.onBoot,
    this.isDisconnected = false,
    super.key,
  });

  final String udid;
  final String? streamUrl;
  final FocusNode simulatorFocusNode;
  final WebSocketService webSocketService;
  final SimulatorInputController inputController;
  final AXOverlayController axOverlayController;
  final VoidCallback onOverlayTap;
  final VoidCallback onBoot;
  final bool isDisconnected;

  @override
  ConsumerState<SimulatorWidget> createState() => _SimulatorWidgetState();
}

class _SimulatorWidgetState extends ConsumerState<SimulatorWidget> {
  @override
  Widget build(BuildContext context) {
    final showPlaceholder = widget.streamUrl == null;

    return SimulatorPointerListener(
      inputController: widget.inputController,
      child: Focus(
        focusNode: widget.simulatorFocusNode,
        autofocus: true,
        child: ChromeRenderer(
          key: widget.inputController.simulatorKey,
          udid: widget.udid,
          baseUrl: ApiConfig.baseUrl,
          child: AXOverlayScope(
            controller: widget.axOverlayController,
            onTap: widget.onOverlayTap,
            child: showPlaceholder
                ? _buildShutdownPlaceholder()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildStreamWidget(),
                      if (widget.isDisconnected) _buildDisconnectedOverlay(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildShutdownPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: widget.onBoot,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Simulator is Powered Off',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Click to boot simulator',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.wifi_slash,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Disconnected',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The simulator was closed or lost connection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: widget.onBoot,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
                label: const Text('Reconnect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamWidget() {
    if (widget.webSocketService.streamFormat == .avcc) {
      return HtmlElementView(viewType: AvccStreamRenderer.canvasId);
    }
    return StreamBuilder(
      stream: widget.webSocketService.mjpegStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        return Image.memory(
          snapshot.data! as Uint8List,
          gaplessPlayback: true,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

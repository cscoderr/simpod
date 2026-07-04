import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_core/simpod_core.dart';

final axOverlayControllerProvider = ChangeNotifierProvider.autoDispose
    .family<AXOverlayController, String>((ref, udid) {
      final controller = AXOverlayController();
      ref.onDispose(controller.dispose);
      return controller;
    });

class AXOverlayController extends ChangeNotifier {
  List<AXNode> _nodes = [];
  List<AXNode> get nodes => _nodes;

  AXNode? _root;
  AXNode? get root => _root;

  AXNode? _focused;
  AXNode? get focused => _focused;

  bool _showAllNodesOverlay = false;
  bool get showAllNodesOverlay => _showAllNodesOverlay;

  void setShowAllNodesOverlay(bool value) {
    if (_showAllNodesOverlay == value) return;
    _showAllNodesOverlay = value;
    notifyListeners();
  }

  bool get isActive => _nodes.isNotEmpty || _showAllNodesOverlay;

  void highlightWithChildren(AXNode node) {
    _nodes = [node, ...node.children];
    _focused = node;

    notifyListeners();
  }

  List<AXNode> get allOtherNodes {
    if (_root == null) return [];
    final result = <AXNode>[];
    final stack = <AXNode>[];
    stack.addAll(_root!.children.reversed);
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      result.add(node);
      for (int i = node.children.length - 1; i >= 0; i--) {
        stack.add(node.children[i]);
      }
    }
    return result;
  }

  void setRoot(AXNode node) {
    _root = node;
    notifyListeners();
  }

  void focusNode(AXNode node) {
    if (!_nodes.contains(node)) return;
    _focused = node;
    notifyListeners();
  }

  void clearFocus() {
    _focused = null;
    _nodes = [];
    notifyListeners();
  }

  void clear() {
    _nodes = [];
    _focused = null;
    _root = null;
    _showAllNodesOverlay = false;
    notifyListeners();
  }
}

class AXOverlayScope extends StatefulWidget {
  const AXOverlayScope({
    super.key,
    required this.controller,
    this.onTap,
    required this.child,
  });

  final AXOverlayController controller;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<AXOverlayScope> createState() => _AXOverlayScopeState();
}

class _AXOverlayScopeState extends State<AXOverlayScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(AXOverlayScope old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isActive) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: _AXMultiHighlightOverlay(
            controller: widget.controller,
            onTap: widget.onTap,
          ),
        ),
      ],
    );
  }
}

class _AXMultiHighlightOverlay extends StatelessWidget {
  const _AXMultiHighlightOverlay({required this.controller, this.onTap});
  final AXOverlayController controller;
  final VoidCallback? onTap;

  Rect _frameOf(AXNode n) =>
      Rect.fromLTWH(n.frameX, n.frameY, n.frameWidth, n.frameHeight);

  Rect _deviceRect(AXOverlayController ctrl) {
    final root = ctrl.root;
    if (root != null && root.frameWidth > 0 && root.frameHeight > 0) {
      return _frameOf(root);
    }
    final frames = ctrl.nodes.where((n) => n.hasFrame).map(_frameOf);
    if (frames.isEmpty) return Rect.zero;
    return frames.reduce((a, b) => a.expandToInclude(b));
  }

  /// Maps a device-point [frame] into the rendered screen [box] (pixels).
  Rect _mapRect(Rect frame, Rect device, Size box) {
    if (device.width <= 0 || device.height <= 0) return frame;
    final sx = box.width / device.width;
    final sy = box.height / device.height;
    return Rect.fromLTWH(
      (frame.left - device.left) * sx,
      (frame.top - device.top) * sy,
      frame.width * sx,
      frame.height * sy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, child) {
        final nodes = ctrl.nodes;
        final focused = ctrl.focused;
        final device = _deviceRect(ctrl);

        return LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            Rect map(AXNode n) => _mapRect(_frameOf(n), device, box);

            final focusedFrame = focused != null ? map(focused) : null;

            // The highlighted element rects are "holes": taps there fall through
            // to the simulator so the underlying control stays interactive,
            // while the surrounding (non-overlay) area absorbs taps.
            final holes = <Rect>[];
            if (ctrl.showAllNodesOverlay && ctrl.root != null) {
              for (final n in ctrl.allOtherNodes) {
                final r = map(n);
                if (!r.isEmpty) holes.add(r);
              }
            }
            for (final n in nodes) {
              if (n == ctrl.root) continue;
              final r = map(n);
              if (!r.isEmpty) holes.add(r);
            }

            return _CutoutHitTest(
              holes: holes,
              child: Stack(
                children: [
                  // Absorbs taps everywhere except the holes (handled by
                  // _CutoutHitTest above), keeping them off the simulator.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                    ),
                  ),
                  IgnorePointer(
                    child: Stack(
                      children: [
                        if (ctrl.showAllNodesOverlay && ctrl.root != null)
                          CustomPaint(
                            size: box,
                            painter: _ScrimPainter(
                              frames: ctrl.allOtherNodes.map(map).toList(),
                            ),
                          ),
                        CustomPaint(
                          size: box,
                          painter: FramesPainter(
                            nodes: nodes,
                            focusedNode: focused,
                            parentNode: ctrl.root,
                            frameOf: map,
                          ),
                        ),
                        if (focusedFrame != null && focusedFrame != Rect.zero)
                          _Tooltip(
                            frame: focusedFrame,
                            node: focused!,
                            screenSize: box,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CutoutHitTest extends SingleChildRenderObjectWidget {
  const _CutoutHitTest({required this.holes, required super.child});

  final List<Rect> holes;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCutoutHitTest(holes);

  @override
  void updateRenderObject(BuildContext context, _RenderCutoutHitTest ro) {
    ro.holes = holes;
  }
}

class _RenderCutoutHitTest extends RenderProxyBox {
  _RenderCutoutHitTest(this._holes);

  List<Rect> _holes;
  set holes(List<Rect> value) {
    if (listEquals(_holes, value)) return;
    _holes = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    for (final hole in _holes) {
      if (hole.contains(position)) return false;
    }
    return super.hitTest(result, position: position);
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.frames});
  final List<Rect> frames;

  @override
  void paint(Canvas canvas, Size size) {
    final color = AppColorsDark.axHighlight;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0x00000000));
    for (final frame in frames) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(5)),
        paint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(5)),
        Paint()..color = color.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.frames != frames;
}

class FramesPainter extends CustomPainter {
  const FramesPainter({
    required this.nodes,
    required this.frameOf,
    this.focusedNode,
    this.parentNode,
  });

  final List<AXNode> nodes;
  final AXNode? focusedNode;
  final AXNode? parentNode;
  final Rect Function(AXNode) frameOf;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      final frame = frameOf(node);
      if (frame.isEmpty) continue;
      if (node == parentNode) continue;
      final color = (focusedNode == node
          ? AppColorsDark.axFocused
          : AppColorsDark.axHighlight);

      final paint = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(5)),
        paint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(5)),
        Paint()..color = color.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(FramesPainter old) =>
      old.nodes != nodes || old.focusedNode != focusedNode;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.frame,
    required this.node,
    required this.screenSize,
  });

  final Rect frame;
  final AXNode node;
  final Size screenSize;

  static const _tooltipH = 38.0;
  static const _gap = AppSpacing.sm - AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    final showBelow = frame.top < _tooltipH + _gap * 2;
    final top = showBelow ? frame.bottom + _gap : frame.top - _tooltipH;
    final left = frame.left.clamp(AppSpacing.sm, screenSize.width - 120.0);

    return Positioned(
      left: left,
      top: top,
      child: _TooltipCard(node: node),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({required this.node});
  final AXNode node;

  @override
  Widget build(BuildContext context) {
    final label = node.label ?? node.title ?? node.identifier;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xxs,
          vertical: AppSpacing.sm - AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColorsDark.tooltipBackground,
          borderRadius: BorderRadius.circular(AppSpacing.sm - AppSpacing.xxs),
          border: Border.all(color: AppColorsDark.tooltipBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, AppSpacing.xs),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label ?? node.role,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColorsDark.axChipText,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${node.frameWidth.toInt()}×${node.frameHeight.toInt()}',
              style: context.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: AppColorsDark.textDimmed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

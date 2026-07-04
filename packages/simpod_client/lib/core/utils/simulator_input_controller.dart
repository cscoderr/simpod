import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/finger_indicators.dart';
import 'package:simpod_core/simpod_core.dart';

final class SimulatorInputController extends ChangeNotifier {
  SimulatorInputController({
    required this.webSocketService,
    this.shouldRequestAccessibility,
  });

  final WebSocketService webSocketService;

  bool Function()? shouldRequestAccessibility;

  /// Invoked when the pointer leaves the simulator surface
  VoidCallback? onExit;

  bool singleTouch = false;
  bool isMultiTouchActive = false;
  bool isAltPinchActive = false;
  FingerIndicators? fingerIndicators;
  int? activeEdgeZone;

  final GlobalKey simulatorKey = GlobalKey();
  final GlobalKey stackKey = GlobalKey();

  final Map<int, _FingerContact> _activeContacts = {};

  static const double _edgeThreshold = 0.05;

  Offset _getNormalizedCoords(Offset position) {
    final box = simulatorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final localPos = box.globalToLocal(position);
    return Offset(
      (localPos.dx / box.size.width).clamp(0.0, 1.0),
      (localPos.dy / box.size.height).clamp(0.0, 1.0),
    );
  }

  Offset normalizedToStackOffset(double normX, double normY) {
    final screenBox =
        simulatorKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (screenBox == null || stackBox == null) return Offset.zero;
    final screenOriginInStack = stackBox.globalToLocal(
      screenBox.localToGlobal(Offset.zero),
    );
    return Offset(
      screenOriginInStack.dx + normX * screenBox.size.width,
      screenOriginInStack.dy + normY * screenBox.size.height,
    );
  }

  List<_FingerContact> _orderedContacts() =>
      _activeContacts.values.toList()
        ..sort((a, b) => a.pointerId.compareTo(b.pointerId));

  FingerIndicators? _currentIndicators() {
    final contacts = _orderedContacts();
    if (contacts.isEmpty) return null;
    if (contacts.length == 1) {
      final p = contacts.first.position;
      return FingerIndicators(x1: p.dx, y1: p.dy, x2: p.dx, y2: p.dy);
    }
    final p1 = contacts[0].position;
    final p2 = contacts[1].position;
    return FingerIndicators(x1: p1.dx, y1: p1.dy, x2: p2.dx, y2: p2.dy);
  }

  void _notify({
    bool? singleTouch,
    bool? isMultiTouchActive,
    bool? isAltPinchActive,
    FingerIndicators? fingerIndicators,
    int? activeEdgeZone,
    bool clearFingerIndicators = false,
    bool clearEdgeZone = false,
    bool clearAltPinch = false,
  }) {
    if (singleTouch != null) this.singleTouch = singleTouch;
    if (isMultiTouchActive != null)
      this.isMultiTouchActive = isMultiTouchActive;
    if (isAltPinchActive != null) this.isAltPinchActive = isAltPinchActive;
    if (fingerIndicators != null) this.fingerIndicators = fingerIndicators;
    if (activeEdgeZone != null) this.activeEdgeZone = activeEdgeZone;
    if (clearFingerIndicators) this.fingerIndicators = null;
    if (clearEdgeZone) this.activeEdgeZone = null;
    if (clearAltPinch) this.isAltPinchActive = false;
    notifyListeners();
  }

  void handlePointerDown(PointerDownEvent event) {
    final norm = _getNormalizedCoords(event.position);
    _activeContacts[event.pointer] = _FingerContact(event.pointer, norm);

    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (isAltPressed && _activeContacts.length == 1) {
      final mirrored = Offset(1.0 - norm.dx, 1.0 - norm.dy);
      _notify(
        singleTouch: false,
        isAltPinchActive: true,
        isMultiTouchActive: true,
        fingerIndicators: FingerIndicators(
          x1: norm.dx,
          y1: norm.dy,
          x2: mirrored.dx,
          y2: mirrored.dy,
        ),
      );
      webSocketService.sendMultiTouch(
        type: 'begin',
        x1: norm.dx,
        y1: norm.dy,
        x2: mirrored.dx,
        y2: mirrored.dy,
      );
      return;
    }

    final indicators = _currentIndicators();
    if (indicators == null) return;

    if (_activeContacts.length == 1) {
      int? edgeZone;
      if (norm.dy >= (1.0 - _edgeThreshold)) {
        edgeZone = SimpodTouchEdge.bottom.value;
      } else if (norm.dy <= _edgeThreshold) {
        edgeZone = SimpodTouchEdge.top.value;
      }
      _notify(
        singleTouch: true,
        isMultiTouchActive: false,
        fingerIndicators: indicators,
        activeEdgeZone: edgeZone,
        clearEdgeZone: edgeZone == null,
      );
      webSocketService.sendTouch(
        type: 'begin',
        x: indicators.x1,
        y: indicators.y1,
        edge: edgeZone,
      );
      return;
    }

    if (_activeContacts.length >= 2) {
      _notify(
        singleTouch: false,
        isMultiTouchActive: true,
        fingerIndicators: indicators,
      );
      webSocketService.sendMultiTouch(
        type: 'begin',
        x1: indicators.x1,
        y1: indicators.y1,
        x2: indicators.x2,
        y2: indicators.y2,
      );
    }
  }

  void handlePointerMove(PointerMoveEvent event) {
    final norm = _getNormalizedCoords(event.position);
    final contact = _activeContacts[event.pointer];
    if (contact == null) return;
    contact.position = norm;

    if (isAltPinchActive) {
      final mirrored = Offset(1.0 - norm.dx, 1.0 - norm.dy);
      _notify(
        fingerIndicators: FingerIndicators(
          x1: norm.dx,
          y1: norm.dy,
          x2: mirrored.dx,
          y2: mirrored.dy,
        ),
      );
      webSocketService.sendMultiTouch(
        type: 'move',
        x1: norm.dx,
        y1: norm.dy,
        x2: mirrored.dx,
        y2: mirrored.dy,
      );
      return;
    }

    final indicators = _currentIndicators();
    if (indicators == null) return;

    if (isMultiTouchActive && _activeContacts.length >= 2) {
      _notify(fingerIndicators: indicators);
      webSocketService.sendMultiTouch(
        type: 'move',
        x1: indicators.x1,
        y1: indicators.y1,
        x2: indicators.x2,
        y2: indicators.y2,
      );
      return;
    }

    if (!isMultiTouchActive) {
      _notify(fingerIndicators: indicators);
      webSocketService.sendTouch(
        type: 'move',
        x: indicators.x1,
        y: indicators.y1,
        edge: activeEdgeZone,
      );
    }
  }

  void handlePointerUp(PointerUpEvent event) {
    final lifted = _activeContacts.remove(event.pointer);

    if (isAltPinchActive && lifted != null) {
      final mirrored = Offset(
        1.0 - lifted.position.dx,
        1.0 - lifted.position.dy,
      );
      webSocketService.sendMultiTouch(
        type: 'end',
        x1: lifted.position.dx,
        y1: lifted.position.dy,
        x2: mirrored.dx,
        y2: mirrored.dy,
      );
      _notify(
        isAltPinchActive: false,
        isMultiTouchActive: false,
        singleTouch: false,
        clearFingerIndicators: true,
        clearEdgeZone: true,
      );
      if (shouldRequestAccessibility?.call() ?? false) {
        webSocketService.sendAccessiblity();
      }
      return;
    }

    if (isMultiTouchActive) {
      final remaining = _orderedContacts();
      FingerIndicators? indicators;
      if (remaining.length >= 2) {
        final p1 = remaining[0].position;
        final p2 = remaining[1].position;
        indicators = FingerIndicators(
          x1: p1.dx,
          y1: p1.dy,
          x2: p2.dx,
          y2: p2.dy,
        );
      } else if (lifted != null) {
        indicators = FingerIndicators(
          x1: lifted.position.dx,
          y1: lifted.position.dy,
          x2: lifted.position.dx,
          y2: lifted.position.dy,
        );
      }

      if (indicators != null) {
        webSocketService.sendMultiTouch(
          type: 'end',
          x1: indicators.x1,
          y1: indicators.y1,
          x2: indicators.x2,
          y2: indicators.y2,
        );
      }

      _notify(
        isMultiTouchActive: false,
        singleTouch: false,
        clearFingerIndicators: true,
        clearEdgeZone: true,
      );
      if (shouldRequestAccessibility?.call() ?? false) {
        webSocketService.sendAccessiblity();
      }
      return;
    }

    if (lifted != null) {
      webSocketService.sendTouch(
        type: 'end',
        x: lifted.position.dx,
        y: lifted.position.dy,
        edge: activeEdgeZone,
      );
    }

    _notify(
      singleTouch: false,
      clearFingerIndicators: true,
      clearEdgeZone: true,
    );
    if (shouldRequestAccessibility?.call() ?? false) {
      webSocketService.sendAccessiblity();
    }
  }

  void handleMouseHover(PointerHoverEvent event) {
    if (isAltPinchActive || isMultiTouchActive) return;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;
    final norm = _getNormalizedCoords(event.position);

    if (isAltPressed) {
      _notify(
        singleTouch: true,
        fingerIndicators: FingerIndicators(
          x1: norm.dx,
          y1: norm.dy,
          x2: 1.0 - norm.dx,
          y2: 1.0 - norm.dy,
        ),
      );
    } else if (fingerIndicators != null) {
      _notify(clearFingerIndicators: true);
    }
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _activeContacts.remove(event.pointer);
    _activeContacts.clear();
    _notify(
      isAltPinchActive: false,
      isMultiTouchActive: false,
      singleTouch: false,
      clearFingerIndicators: true,
      clearEdgeZone: true,
    );
  }
}

class _FingerContact {
  _FingerContact(this.pointerId, this.position);
  final int pointerId;
  Offset position;
}

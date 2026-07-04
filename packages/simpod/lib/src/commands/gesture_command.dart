import 'dart:convert';

import 'package:simpod/simpod.dart';

class GestureCommand extends SimpodCommand {
  @override
  final String name = 'gesture';

  @override
  final String description = 'Send a multi-step touch/pinch gesture (JSON)';

  static const _touchCoordKeys = ['x', 'y'];
  static const _pinchCoordKeys = ['x1', 'y1', 'x2', 'y2'];
  static const _phases = {'begin', 'move', 'end'};

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      usageException(
        'Missing JSON gesture payload. Usage: simpod gesture <json>',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(rest.first);
    } catch (e) {
      usageException('Invalid JSON format: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      usageException('Gesture JSON must be an object with "type" and "data".');
    }

    final type = decoded['type'];
    final data = decoded['data'];
    if (type is! String) {
      usageException('Gesture "type" must be a string ("touch" or "pinch").');
    }
    if (data is! Map<String, dynamic>) {
      usageException('Gesture "data" must be an object.');
    }

    switch (type) {
      case 'touch':
        _requireNumbers(data, _touchCoordKeys);
        _validateOptionalEdge(data);
      case 'pinch':
        _requireNumbers(data, _pinchCoordKeys);
      default:
        usageException(
          'Unsupported gesture type "$type". Use "touch" or "pinch" — '
          'button, rotate and type have their own commands.',
        );
    }
    _requirePhase(data);

    await client.sendGesture(type: type, data: data);
  }

  void _requireNumbers(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data[key] is! num) {
        usageException(
          'Gesture "data.$key" must be a number (normalized 0..1).',
        );
      }
    }
  }

  void _requirePhase(Map<String, dynamic> data) {
    final phase = data['phase'];
    if (phase is! String || !_phases.contains(phase)) {
      usageException(
        'Gesture "data.phase" must be one of: ${_phases.join(', ')}.',
      );
    }
  }

  /// `edge` is optional, but when present it must be an integer (0..4) or null.
  void _validateOptionalEdge(Map<String, dynamic> data) {
    if (data.containsKey('edge') &&
        data['edge'] != null &&
        data['edge'] is! int) {
      usageException('Gesture "data.edge" must be an integer (0..4) or null.');
    }
  }
}

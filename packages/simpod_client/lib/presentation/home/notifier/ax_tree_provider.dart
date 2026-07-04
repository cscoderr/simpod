import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_core/simpod_core.dart';

final axTreeProvider = NotifierProvider.autoDispose
    .family<AxTreeNotifier, AXNode?, String>(AxTreeNotifier.new);

class AxTreeNotifier extends Notifier<AXNode?> {
  AxTreeNotifier(this.udid);

  final String udid;

  @override
  AXNode? build() {
    // The server's SSE loop always pushes the current tree as its first
    // event, so no separate snapshot fetch is needed.
    final service = AxStreamService();
    final sub = service.stream.listen(_onPayload);
    service.connect(udid);
    ref.onDispose(() {
      unawaited(sub.cancel());
      unawaited(service.dispose());
    });
    return null;
  }

  void _onPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      final root = switch (decoded) {
        final List<dynamic> nodes when nodes.isNotEmpty => AXNode.fromJson(
          nodes.first as Map<String, dynamic>,
        ),
        final Map<String, dynamic> node when !node.containsKey('error') =>
          AXNode.fromJson(node),
        _ => null,
      };
      if (root != null) state = root;
    } catch (_) {}
  }
}

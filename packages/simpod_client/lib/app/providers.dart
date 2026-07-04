import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/home/notifier/home_notifier.dart';
import 'package:simpod_client/presentation/home/notifier/home_state.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() {
    unawaited(service.close());
  });
  return service;
});

final homeNotifierProvider = NotifierProvider.autoDispose
    .family<HomeNotifier, HomeState, String>(HomeNotifier.new);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Holds the dashboard's light/dark mode.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

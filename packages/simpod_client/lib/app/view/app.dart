import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:simpod_client/app/providers.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/device_selection/device_selection.dart';
import 'package:simpod_client/presentation/home/home.dart';
import 'package:simpod_client/presentation/pairing/widgets/auth_gate.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) {
        final device = state.uri.queryParameters['device'];
        if (device != null) {
          return HomePage(udid: device);
        }
        return const DeviceSelectionPage();
      },
    ),
  ],
);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: SimpodLightTheme().themeData,
      darkTheme: SimpodDarkTheme().themeData,
      themeMode: themeMode,
      builder: (context, child) =>
          AuthGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

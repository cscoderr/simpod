import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/presentation/pairing/notifier/auth_status_provider.dart';
import 'package:simpod_client/presentation/pairing/view/pairing_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(authStatusProvider)
        .when(
          loading: () => const StatusView.loading(message: 'Connecting…'),
          error: (_, _) => StatusView.error(
            title: 'Unable to reach simpod',
            message: 'Make sure the simpod server is running.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(authStatusProvider),
          ),
          data: (status) => switch (status) {
            AuthStatus.authorized => child,
            AuthStatus.needsPairing => const PairingPage(),
            AuthStatus.unreachable => StatusView.error(
              title: 'Could not reach simpod',
              message: 'Make sure the simpod server is running.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(authStatusProvider),
            ),
          },
        );
  }
}

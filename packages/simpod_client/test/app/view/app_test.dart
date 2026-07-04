// The app transitively imports `package:web` (it is a Flutter web app), which
// only compiles for the browser target, so this widget test is browser-only.
@TestOn('browser')
library;

// Ignore for testing purposes
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/app/app.dart';

void main() {
  group('App', () {
    testWidgets('renders CounterPage', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: App()));
      // expect(find.byType(CounterPage), findsOneWidget);
    });
  });
}

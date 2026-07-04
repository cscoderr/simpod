import 'package:flutter_test/flutter_test.dart';
import 'package:simpod_client/core/utils/result.dart';

class _TestException implements Exception {
  const _TestException(this.message);
  final String message;
}

void main() {
  group('Result', () {
    test('Success exposes its value', () {
      const result = Success<Exception, int>(42);
      expect(result.value, 42);
    });

    test('Failure exposes its exception', () {
      const result = Failure<_TestException, int>(_TestException('boom'));
      expect(result.exception.message, 'boom');
    });

    group('fold', () {
      test('invokes the success branch for Success', () {
        const Result<Exception, int> result = Success(7);

        final folded = result.fold(
          (e) => 'error',
          (value) => 'value: $value',
        );

        expect(folded, 'value: 7');
      });

      test('invokes the failure branch for Failure', () {
        const Result<_TestException, int> result = Failure(
          _TestException('nope'),
        );

        final folded = result.fold(
          (e) => 'error: ${e.message}',
          (value) => 'value',
        );

        expect(folded, 'error: nope');
      });

      test('does not invoke the other branch', () {
        const Result<Exception, int> success = Success(1);
        var failureCalled = false;
        success.fold((_) => failureCalled = true, (_) => null);
        expect(failureCalled, isFalse);

        const Result<_TestException, int> failure = Failure(
          _TestException('x'),
        );
        var successCalled = false;
        failure.fold((_) => null, (_) => successCalled = true);
        expect(successCalled, isFalse);
      });
    });
  });
}

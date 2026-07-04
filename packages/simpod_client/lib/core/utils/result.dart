sealed class Result<E extends Exception, T> {
  const Result();
}

class Success<E extends Exception, T> extends Result<E, T> {
  const Success(this.value);
  final T value;
}

class Failure<E extends Exception, T> extends Result<E, T> {
  const Failure(this.exception);
  final E exception;
}

extension ResultEx<E extends Exception, T> on Result<E, T> {
  R fold<R>(R Function(E exception) failure, R Function(T data) success) {
    return switch (this) {
      Success<E, T>(:final value) => success(value),
      Failure<E, T>(:final exception) => failure(exception),
    };
  }
}

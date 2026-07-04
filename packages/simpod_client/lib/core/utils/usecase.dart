import 'package:equatable/equatable.dart';

import 'result.dart';

abstract class Usecase<T, P> {
  Future<Result<Exception, T>> call(P params);
}

class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => [];
}

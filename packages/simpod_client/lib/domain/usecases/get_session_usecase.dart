import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/repositories/device_repository_impl.dart';
import 'package:simpod_client/domain/repositories/device_repository.dart';
import 'package:simpod_core/simpod_core.dart';

final getSessionUseCaseProvider = Provider.autoDispose<GetSessionUseCase>((
  ref,
) {
  return GetSessionUseCase(ref.watch(deviceRepositoryProvider));
});

class GetSessionUseCase implements Usecase<SimpodSession, String> {
  const GetSessionUseCase(this.repository);

  final DeviceRepository repository;

  Future<Result<Exception, SimpodSession>> call(String udid) {
    return repository.getSession(udid);
  }
}

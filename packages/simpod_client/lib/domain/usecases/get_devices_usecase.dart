import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/repositories/device_repository_impl.dart';
import 'package:simpod_client/domain/repositories/device_repository.dart';
import 'package:simpod_core/simpod_core.dart';

final getDevicesUseCaseProvider = Provider.autoDispose<GetDevicesUseCase>((
  ref,
) {
  return GetDevicesUseCase(ref.watch(deviceRepositoryProvider));
});

class GetDevicesUseCase implements Usecase<List<DeviceInfo>, NoParams> {
  const GetDevicesUseCase(this.repository);

  final DeviceRepository repository;

  Future<Result<Exception, List<DeviceInfo>>> call([
    params = const NoParams(),
  ]) {
    return repository.getDevices();
  }
}

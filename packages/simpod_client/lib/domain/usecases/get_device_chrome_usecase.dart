import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_client/data/repositories/device_repository_impl.dart';
import 'package:simpod_client/domain/repositories/device_repository.dart';

final getDeviceChromeUsecaseProvider =
    Provider.autoDispose<GetDeviceChromeUsecase>((ref) {
      return GetDeviceChromeUsecase(
        repository: ref.watch(deviceRepositoryProvider),
      );
    });

class GetDeviceChromeUsecase extends Usecase<SimulatorChromeConfig, String> {
  GetDeviceChromeUsecase({required DeviceRepository repository})
    : _repository = repository;

  final DeviceRepository _repository;

  @override
  Future<Result<Exception, SimulatorChromeConfig>> call(String params) async {
    return _repository.getDeviceChrome(params);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_client/data/repositories/device_repository_impl.dart';
import 'package:simpod_client/domain/repositories/device_repository.dart';

final getDeviceDefintionUsecaseProvider =
    Provider.autoDispose<GetDeviceDefinitionUsecase>((ref) {
      return GetDeviceDefinitionUsecase(
        repository: ref.watch(deviceRepositoryProvider),
      );
    });

class GetDeviceDefinitionUsecase extends Usecase<SimulatorDefinition, String> {
  GetDeviceDefinitionUsecase({required DeviceRepository repository})
    : _repository = repository;

  final DeviceRepository _repository;

  @override
  Future<Result<Exception, SimulatorDefinition>> call(String params) async {
    return _repository.getDeviceDefinition(params);
  }
}

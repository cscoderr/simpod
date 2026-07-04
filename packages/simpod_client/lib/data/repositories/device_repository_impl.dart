import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/utils/result.dart';
import 'package:simpod_client/data/datasources/device_remote_data_source.dart';
import 'package:simpod_client/data/models/simulator_chrome_config.dart';
import 'package:simpod_client/data/models/simulator_definition.dart';
import 'package:simpod_client/domain/repositories/device_repository.dart';
import 'package:simpod_core/simpod_core.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepositoryImpl(
    remoteDataSource: ref.watch(deviceRemoteDataSourceProvider),
  );
});

class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl({required DeviceRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final DeviceRemoteDataSource _remoteDataSource;

  @override
  Future<Result<Exception, List<DeviceInfo>>> getDevices() async {
    try {
      final result = await _remoteDataSource.getDevices();
      return Success(result);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  @override
  Future<Result<Exception, SimpodSession>> getSession(String udid) async {
    try {
      final result = await _remoteDataSource.getSession(udid);
      return Success(result);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  @override
  Future<Result<Exception, SimulatorDefinition>> getDeviceDefinition(
    String udid,
  ) async {
    try {
      final result = await _remoteDataSource.getDeviceDefinition(udid);
      return Success(result);
    } catch (e) {
      print("Error ${e.toString()}");
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  @override
  Future<Result<Exception, SimulatorChromeConfig>> getDeviceChrome(
    String udid,
  ) async {
    try {
      final result = await _remoteDataSource.getDeviceChrome(udid);
      return Success(result);
    } catch (e) {
      print("Error ${e.toString()}");
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}

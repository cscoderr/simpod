import 'package:simpod_client/core/utils/result.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_core/simpod_core.dart';

abstract class DeviceRepository {
  Future<Result<Exception, List<DeviceInfo>>> getDevices();
  Future<Result<Exception, SimpodSession>> getSession(String udid);
  Future<Result<Exception, SimulatorDefinition>> getDeviceDefinition(
    String udid,
  );
  Future<Result<Exception, SimulatorChromeConfig>> getDeviceChrome(String udid);
}

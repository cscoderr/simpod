import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/utils/result.dart';
import 'package:simpod_client/domain/usecases/get_devices_usecase.dart';
import 'package:simpod_client/presentation/device_selection/notifier/devices_provider.dart';
import 'package:simpod_core/simpod_core.dart';

final polledDevicesProvider = StreamProvider.autoDispose<List<DeviceInfo>>((
  ref,
) async* {
  final getDevices = ref.read(getDevicesUseCaseProvider);
  List<DeviceInfo>? last;
  while (true) {
    final result = await getDevices.call();
    // Only emit when something actually changed — every yield rebuilds the
    // whole home page.
    if (result case Success(:final value)) {
      final sorted = sortDevices(value);
      if (!_sameDevices(last, sorted)) {
        last = List<DeviceInfo>.unmodifiable(sorted);
        yield last;
      }
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

bool _sameDevices(List<DeviceInfo>? a, List<DeviceInfo> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].udid != b[i].udid ||
        a[i].state != b[i].state ||
        a[i].name != b[i].name) {
      return false;
    }
  }
  return true;
}

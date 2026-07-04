import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/domain/usecases/get_devices_usecase.dart';
import 'package:simpod_core/simpod_core.dart';

final devicesProvider = FutureProvider.autoDispose<List<DeviceInfo>>((
  ref,
) async {
  final result = await ref.read(getDevicesUseCaseProvider).call();
  return result.fold((l) => throw l, sortDevices);
});

final _runtimeRegex = RegExp(r'iOS-(\d+)-(\d+)');

/// Booted devices first, then newest iOS runtime first.
List<DeviceInfo> sortDevices(List<DeviceInfo> devices) {
  (int bootedRank, int major, int minor) key(DeviceInfo d) {
    final match = _runtimeRegex.firstMatch(d.runtime);
    return (
      d.state == DeviceState.booted ? 0 : 1,
      match != null ? int.parse(match.group(1) ?? '0') : 0,
      match != null ? int.parse(match.group(2) ?? '0') : 0,
    );
  }

  final keyed = [for (final d in devices) (key: key(d), device: d)];
  keyed.sort((a, b) {
    if (a.key.$1 != b.key.$1) return a.key.$1.compareTo(b.key.$1);
    if (a.key.$2 != b.key.$2) return b.key.$2.compareTo(a.key.$2);
    return b.key.$3.compareTo(a.key.$3);
  });
  return [for (final e in keyed) e.device];
}

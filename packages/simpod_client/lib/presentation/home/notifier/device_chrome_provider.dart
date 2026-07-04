import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_client/domain/usecases/get_device_chrome_usecase.dart';

final deviceChromeProvider = FutureProvider.autoDispose
    .family<SimulatorChromeConfig, String>((ref, udid) async {
      final result = await ref.read(getDeviceChromeUsecaseProvider).call(udid);
      return result.fold((l) => throw l, (r) => r);
    });

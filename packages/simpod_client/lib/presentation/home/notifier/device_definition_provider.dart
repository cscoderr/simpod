import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_client/domain/usecases/get_device_definition_usecase.dart';

final deviceDefinitionProvider = FutureProvider.autoDispose
    .family<SimulatorDefinition, String>((ref, udid) async {
      final result = await ref
          .read(getDeviceDefintionUsecaseProvider)
          .call(udid);
      return result.fold((l) => throw l, (r) => r);
    });

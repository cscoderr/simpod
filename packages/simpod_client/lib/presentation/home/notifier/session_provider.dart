import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_client/domain/usecases/get_session_usecase.dart';
import 'package:simpod_core/simpod_core.dart';
import 'package:web/web.dart' as web;

final sessionProvider = FutureProvider.autoDispose
    .family<SimpodSession, String>((ref, udid) async {
      final result = await ref.read(getSessionUseCaseProvider).call(udid);
      return result.fold((l) => throw l, (r) {
        web.window.sessionStorage.setItem('streamUrl', r.streamUrl);
        web.window.sessionStorage.setItem('wsUrl', r.wsUrl);
        return r;
      });
    });

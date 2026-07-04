import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:simpod_client/core/utils/api_config.dart';

enum AuthStatus { authorized, needsPairing, unreachable }

final authStatusProvider = FutureProvider<AuthStatus>((ref) async {
  try {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/health'),
      headers: ApiConfig.headers,
    );
    if (response.statusCode == HttpStatus.ok) return AuthStatus.authorized;
    if (response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.unauthorized) {
      return AuthStatus.needsPairing;
    }
    return AuthStatus.unreachable;
  } catch (_) {
    return AuthStatus.unreachable;
  }
});

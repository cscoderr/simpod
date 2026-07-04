import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:simpod_client/core/utils/api_config.dart';
import 'package:simpod_client/data/models/models.dart';
import 'package:simpod_core/simpod_core.dart';

final deviceRemoteDataSourceProvider = Provider<DeviceRemoteDataSource>((ref) {
  return DeviceRemoteDataSourceImpl();
});

abstract class DeviceRemoteDataSource {
  Future<List<DeviceInfo>> getDevices();
  Future<SimpodSession> getSession(String udid);
  Future<SimulatorDefinition> getDeviceDefinition(String udid);
  Future<SimulatorChromeConfig> getDeviceChrome(String udid);
}

class DeviceRemoteDataSourceImpl implements DeviceRemoteDataSource {
  DeviceRemoteDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<DeviceInfo>> getDevices() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/devices'),
      headers: ApiConfig.headers,
    );

    if (response.statusCode == HttpStatus.ok) {
      final decodedResponse = jsonDecode(response.body) as List<dynamic>;
      return decodedResponse
          .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw HttpException('Failed to fetch devices: ${response.statusCode}');
    }
  }

  @override
  Future<SimpodSession> getSession(String udid) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/session/$udid'),
      headers: ApiConfig.headers,
    );

    if (response.statusCode == HttpStatus.ok) {
      final decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;
      return SimpodSession.fromJson(decodedResponse);
    } else {
      throw HttpException('Failed to fetch session: ${response.statusCode}');
    }
  }

  @override
  Future<SimulatorDefinition> getDeviceDefinition(String udid) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/device/$udid/definition.json'),
      headers: ApiConfig.headers,
    );

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SimulatorDefinition.fromJson(data);
    } else {
      throw HttpException(
        'Failed to fetch device bezel: ${response.statusCode}',
      );
    }
  }

  @override
  Future<SimulatorChromeConfig> getDeviceChrome(String udid) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/device/$udid/chrome-profile'),
      headers: ApiConfig.headers,
    );

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SimulatorChromeConfig.fromJson(data);
    } else {
      throw HttpException(
        'Failed to fetch device bezel: ${response.statusCode}',
      );
    }
  }
}

import 'package:banking_mobile/core/network/dio_provider.dart';
import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemInfoApiService {
  SystemInfoApiService(this._dio);

  final Dio _dio;

  Future<SystemInfo> fetchSystemInfo() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/system/info',
    );

    final data = response.data;

    if (data == null) {
      throw const FormatException('The system-info response body was empty.');
    }

    return SystemInfo.fromJson(data);
  }
}

final systemInfoApiServiceProvider = Provider<SystemInfoApiService>((ref) {
  final dio = ref.watch(dioProvider);

  return SystemInfoApiService(dio);
});

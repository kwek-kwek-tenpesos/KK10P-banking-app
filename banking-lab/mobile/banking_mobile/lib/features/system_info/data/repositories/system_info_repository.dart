import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/data/services/system_info_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemInfoRepository {
  SystemInfoRepository(this._apiService);

  final SystemInfoApiService _apiService;

  Future<SystemInfo> getSystemInfo() async {
    try {
      return await _apiService.fetchSystemInfo();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }
}

final systemInfoRepositoryProvider = Provider<SystemInfoRepository>((ref) {
  final apiService = ref.watch(systemInfoApiServiceProvider);

  return SystemInfoRepository(apiService);
});

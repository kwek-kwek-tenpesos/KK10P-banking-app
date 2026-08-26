import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/data/services/system_info_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemInfoRepository {
  SystemInfoRepository(this._apiService);

  final SystemInfoApiService _apiService;

  Future<SystemInfo> getSystemInfo() {
    return _apiService.fetchSystemInfo();
  }
}

final systemInfoRepositoryProvider = Provider<SystemInfoRepository>((ref) {
  final apiService = ref.watch(systemInfoApiServiceProvider);

  return SystemInfoRepository(apiService);
});

import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_compatibility_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class ClientCompatibilityApiService {
  Future<ClientCompatibilityResult> check(ClientBuildInfo build);
}

class DioClientCompatibilityApiService
    implements ClientCompatibilityApiService {
  DioClientCompatibilityApiService(this._dio);

  final Dio _dio;

  @override
  Future<ClientCompatibilityResult> check(ClientBuildInfo build) async {
    _requireSecureConnection();
    try {
      final response = await _dio.get<Object>('/api/v1/client/compatibility');
      final parsed = ClientCompatibilityResult.tryParse(response.data, build);
      if (parsed == null) throw const InvalidResponseFailure();
      return parsed;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }

  void _requireSecureConnection() {
    final uri = Uri.tryParse(_dio.options.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      throw const SecureConnectionRequiredFailure();
    }
  }
}

final clientCompatibilityApiServiceProvider =
    Provider<ClientCompatibilityApiService>((ref) {
      return DioClientCompatibilityApiService(ref.watch(dioProvider));
    });

import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/development_funding/data/models/development_funding_receipt.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevelopmentFundingApiService {
  DevelopmentFundingApiService(this._dio);
  final Dio _dio;

  Future<DevelopmentFundingReceipt> fund({
    required String token,
    required String idempotencyKey,
  }) async {
    final uri = Uri.tryParse(_dio.options.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const SecureConnectionRequiredFailure();
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/development/funding/me',
        data: <String, dynamic>{},
        options: Options(
          contentType: Headers.jsonContentType,
          followRedirects: false,
          maxRedirects: 0,
          headers: {
            'Authorization': 'Bearer $token',
            'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (![200, 201].contains(response.statusCode) || response.data == null) {
        throw const InvalidResponseFailure();
      }
      return DevelopmentFundingReceipt.fromJson(response.data!);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (error.response?.statusCode == 409 && data is Map) {
        return switch (data['code']) {
          'account_not_opened' =>
            throw const DevelopmentAccountRequiredFailure(),
          'development_funding_daily_limit_reached' =>
            throw const DevelopmentFundingLimitFailure(),
          'idempotency_conflict' => throw const IdempotencyConflictFailure(),
          _ => throw ServerFailure(statusCode: error.response?.statusCode),
        };
      }
      throw mapApiError(error);
    } on FormatException {
      throw const InvalidResponseFailure();
    }
  }
}

final developmentFundingApiServiceProvider =
    Provider<DevelopmentFundingApiService>(
      (ref) => DevelopmentFundingApiService(ref.watch(dioProvider)),
    );

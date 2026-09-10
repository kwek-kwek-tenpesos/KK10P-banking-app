import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityApiService {
  ActivityApiService(this._dio);

  final Dio _dio;

  Future<ActivityPage> readPage(
    String token, {
    ActivityFilters filters = const ActivityFilters(),
    String? cursor,
    int limit = 20,
  }) => _get(
    '/api/v1/accounts/me/transactions',
    token,
    queryParameters: {
      'limit': limit,
      'cursor': ?cursor,
      if (filters.direction case final direction?)
        'direction': activityDirectionQuery(direction),
      if (filters.type case final type?) 'type': activityTypeQuery(type),
    },
    parse: ActivityPage.fromJson,
  );

  Future<ActivityDetail> readDetail(String token, String transactionId) => _get(
    '/api/v1/accounts/me/transactions/$transactionId',
    token,
    parse: ActivityDetail.fromJson,
  );

  Future<T> _get<T>(
    String path,
    String token, {
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) parse,
  }) async {
    final uri = Uri.tryParse(_dio.options.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const SecureConnectionRequiredFailure();
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: Options(
          followRedirects: false,
          maxRedirects: 0,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw InvalidResponseFailure(
          requestId: response.headers.value('x-request-id'),
        );
      }
      try {
        return parse(response.data!);
      } on FormatException {
        throw InvalidResponseFailure(
          requestId: response.headers.value('x-request-id'),
        );
      }
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      final requestId = _requestId(error.response);
      if (error.response?.statusCode == 404 && code == 'account_not_opened') {
        throw ActivityAccountRequiredFailure(requestId: requestId);
      }
      if (error.response?.statusCode == 404 &&
          code == 'transaction_not_found') {
        throw ActivityTransactionNotFoundFailure(requestId: requestId);
      }
      throw mapApiError(error);
    }
  }

  static String? _requestId(Response<dynamic>? response) {
    final header = response?.headers.value('x-request-id')?.trim();
    if (header != null && header.isNotEmpty) return header;
    final data = response?.data;
    if (data is Map) {
      final traceId = data['traceId']?.toString().trim();
      if (traceId != null && traceId.isNotEmpty) return traceId;
    }
    return null;
  }
}

final activityApiServiceProvider = Provider<ActivityApiService>(
  (ref) => ActivityApiService(ref.watch(dioProvider)),
);

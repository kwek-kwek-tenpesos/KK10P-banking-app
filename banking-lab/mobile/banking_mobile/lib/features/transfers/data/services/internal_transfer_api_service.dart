import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/transfers/data/models/internal_transfer_receipt.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InternalTransferApiService {
  InternalTransferApiService(this._dio);

  final Dio _dio;

  Future<InternalTransferReceipt> transfer({
    required String token,
    required String idempotencyKey,
    required String destinationAccountReference,
    required BigInt amountMinor,
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
        '/api/v1/transfers/internal',
        data: <String, dynamic>{
          'destinationAccountReference': destinationAccountReference,
          'amountMinor': amountMinor.toString(),
        },
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
        throw InvalidResponseFailure(
          requestId: response.headers.value('x-request-id'),
        );
      }
      try {
        return InternalTransferReceipt.fromJson(response.data!);
      } on FormatException {
        throw InvalidResponseFailure(
          requestId: response.headers.value('x-request-id'),
        );
      }
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      final requestId = _requestId(error.response);
      if (error.response?.statusCode == 404 && code == 'recipient_not_found') {
        throw TransferRecipientNotFoundFailure(requestId: requestId);
      }
      if (error.response?.statusCode == 409) {
        switch (code) {
          case 'account_not_opened':
            throw TransferAccountRequiredFailure(requestId: requestId);
          case 'self_transfer_not_allowed':
            throw TransferSelfNotAllowedFailure(requestId: requestId);
          case 'idempotency_conflict':
            throw TransferIdempotencyConflictFailure(requestId: requestId);
          case 'insufficient_funds':
            throw TransferInsufficientFundsFailure(requestId: requestId);
          case 'outgoing_daily_limit_reached':
            throw TransferDailyLimitFailure(requestId: requestId);
        }
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

final internalTransferApiServiceProvider = Provider<InternalTransferApiService>(
  (ref) => InternalTransferApiService(ref.watch(dioProvider)),
);

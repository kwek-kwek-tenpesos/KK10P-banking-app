import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:dio/dio.dart';

AppFailure mapApiError(Object error) {
  if (error is AppFailure) {
    return error;
  }

  if (error is FormatException) {
    return const InvalidResponseFailure();
  }

  if (error is! DioException) {
    return const UnexpectedFailure();
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => const TimeoutFailure(),

    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate => const NetworkFailure(),

    DioExceptionType.badResponse => _mapBadResponse(error.response),

    DioExceptionType.cancel => const RequestCancelledFailure(),

    DioExceptionType.unknown => const UnexpectedFailure(),
  };
}

AppFailure _mapBadResponse(Response<dynamic>? response) {
  final statusCode = response?.statusCode;
  final data = response?.data;
  final requestId = _requestId(response);

  if (statusCode == 401) {
    return const UnauthenticatedFailure();
  }

  if (statusCode == 429) {
    return RateLimitedFailure(
      retryAfterSeconds: int.tryParse(
        response?.headers.value('retry-after') ?? '',
      ),
      requestId: requestId,
    );
  }

  if (statusCode == 400 && data is Map<String, dynamic>) {
    final detail = data['detail'] as String? ?? 'Validation error occurred.';
    final errorsData = data['errors'];
    final fieldErrors = <String, List<String>>{};

    if (errorsData is Map) {
      for (final entry in errorsData.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          fieldErrors[key] = value.map((e) => e.toString()).toList();
        } else if (value != null) {
          fieldErrors[key] = [value.toString()];
        }
      }
    }

    return ValidationFailure(
      detail,
      fieldErrors: fieldErrors,
      requestId: requestId,
    );
  }

  return ServerFailure(statusCode: statusCode, requestId: requestId);
}

String? _requestId(Response<dynamic>? response) {
  final header = response?.headers.value('x-request-id')?.trim();
  if (header != null && header.isNotEmpty) return header;
  final data = response?.data;
  if (data is Map) {
    final traceId = data['traceId']?.toString().trim();
    if (traceId != null && traceId.isNotEmpty) return traceId;
  }
  return null;
}

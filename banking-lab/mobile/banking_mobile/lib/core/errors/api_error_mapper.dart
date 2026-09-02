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

    DioExceptionType.badResponse => ServerFailure(
      statusCode: error.response?.statusCode,
    ),

    DioExceptionType.cancel => const RequestCancelledFailure(),

    DioExceptionType.unknown => const UnexpectedFailure(),
  };
}

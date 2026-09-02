import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapApiError', () {
    test('maps a connection error to NetworkFailure', () {
      final error = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );

      final failure = mapApiError(error);

      expect(failure, isA<NetworkFailure>());
    });

    test('maps a timeout to TimeoutFailure', () {
      final error = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.receiveTimeout,
      );

      final failure = mapApiError(error);

      expect(failure, isA<TimeoutFailure>());
    });

    test('maps invalid response data to InvalidResponseFailure', () {
      const error = FormatException('Invalid test response');

      final failure = mapApiError(error);

      expect(failure, isA<InvalidResponseFailure>());
    });

    test('maps an unrecognized exception to UnexpectedFailure', () {
      final error = Exception('Test error');

      final failure = mapApiError(error);

      expect(failure, isA<UnexpectedFailure>());
    });

    test('maps a response transformation timeout to TimeoutFailure', () {
      final error = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.transformTimeout,
      );

      final failure = mapApiError(error);

      expect(failure, isA<TimeoutFailure>());
    });

    test('maps a bad response to ServerFailure with its status code', () {
      final requestOptions = RequestOptions();

      final error = DioException.badResponse(
        statusCode: 503,
        requestOptions: requestOptions,
        response: Response<void>(
          requestOptions: requestOptions,
          statusCode: 503,
        ),
      );

      final failure = mapApiError(error);

      expect(failure, isA<ServerFailure>());

      final serverFailure = failure as ServerFailure;

      expect(serverFailure.statusCode, 503);
    });

    test('maps a cancelled request to RequestCancelledFailure', () {
      final error = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
      );

      final failure = mapApiError(error);

      expect(failure, isA<RequestCancelledFailure>());
    });

    test('keeps an existing AppFailure unchanged', () {
      const originalFailure = NetworkFailure();

      final mappedFailure = mapApiError(originalFailure);

      expect(identical(mappedFailure, originalFailure), isTrue);
    });
  });
}

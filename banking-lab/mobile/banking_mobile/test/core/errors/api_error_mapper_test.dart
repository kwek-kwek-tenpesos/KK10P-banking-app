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

    test('maps only a strict trusted 426 contract to upgrade required', () {
      final requestOptions = RequestOptions();
      final response = Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 426,
        data: {
          'code': 'client_upgrade_required',
          'platform': 'ANDROID',
          'currentBuild': 1,
          'minimumBuild': 2,
          'updateUri': 'https://downloads.example.test/kk10p',
          'traceId': 'request-upgrade',
        },
      );

      final failure = mapApiError(
        DioException.badResponse(
          statusCode: 426,
          requestOptions: requestOptions,
          response: response,
        ),
      );

      expect(failure, isA<ClientUpgradeRequiredFailure>());
      final upgrade = failure as ClientUpgradeRequiredFailure;
      expect(upgrade.currentBuild, 1);
      expect(upgrade.minimumBuild, 2);
      expect(upgrade.updateUri.scheme, 'https');
      expect(upgrade.requestId, 'request-upgrade');
    });

    test('fails closed to ServerFailure for an untrusted 426 update URI', () {
      final requestOptions = RequestOptions();
      final response = Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 426,
        data: {
          'code': 'client_upgrade_required',
          'platform': 'ANDROID',
          'currentBuild': 1,
          'minimumBuild': 2,
          'updateUri': 'http://downloads.example.test/kk10p',
        },
      );

      final failure = mapApiError(
        DioException.badResponse(
          statusCode: 426,
          requestOptions: requestOptions,
          response: response,
        ),
      );

      expect(failure, isA<ServerFailure>());
    });

    test('fails closed to ServerFailure for an oversized 426 update URI', () {
      final requestOptions = RequestOptions();
      final response = Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 426,
        data: {
          'code': 'client_upgrade_required',
          'platform': 'ANDROID',
          'currentBuild': 1,
          'minimumBuild': 2,
          'updateUri': 'https://downloads.example.test/${'a' * 2050}',
        },
      );

      final failure = mapApiError(
        DioException.badResponse(
          statusCode: 426,
          requestOptions: requestOptions,
          response: response,
        ),
      );

      expect(failure, isA<ServerFailure>());
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

    test(
      'maps a 400 bad response with validation errors to ValidationFailure',
      () {
        final requestOptions = RequestOptions();

        final error = DioException.badResponse(
          statusCode: 400,
          requestOptions: requestOptions,
          response: Response<Map<String, dynamic>>(
            requestOptions: requestOptions,
            statusCode: 400,
            data: {
              'detail': 'Check the registration fields and try again.',
              'errors': {
                'email': ['Enter a valid email address.'],
                'password': ['Password is too short.'],
              },
            },
          ),
        );

        final failure = mapApiError(error);

        expect(failure, isA<ValidationFailure>());
        final validationFailure = failure as ValidationFailure;
        expect(
          validationFailure.message,
          'Check the registration fields and try again.',
        );
        expect(validationFailure.fieldErrors['email'], [
          'Enter a valid email address.',
        ]);
        expect(validationFailure.fieldErrors['password'], [
          'Password is too short.',
        ]);
      },
    );
  });
}

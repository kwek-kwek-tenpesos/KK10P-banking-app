import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthenticationApiService', () {
    test('rejects HTTP before a credential request reaches Dio', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
      addTearDown(() => dio.close(force: true));
      var requestCount = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      await expectLater(
        AuthenticationApiService(dio).register(
          const RegistrationRequest(
            email: 'customer@example.test',
            password: 'Correct Horse Battery Staple!',
          ),
        ),
        throwsA(isA<SecureConnectionRequiredFailure>()),
      );
      expect(requestCount, 0);
    });

    test('posts registration and parses response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));

      addTearDown(() {
        dio.close(force: true);
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.followRedirects, isFalse);
            expect(options.maxRedirects, 0);
            expect(
              options.uri.toString(),
              'https://example.test/api/v1/auth/register',
            );
            expect(options.data, {
              'email': 'customer@example.test',
              'password': 'Password12345!',
              'displayName': 'Test Customer',
            });

            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 202,
                data: <String, dynamic>{
                  'outcome': 0,
                  'message': 'If registration can proceed, check your email for the next step.',
                },
              ),
            );
          },
        ),
      );

      final service = AuthenticationApiService(dio);

      final response = await service.register(
        const RegistrationRequest(
          email: 'customer@example.test',
          password: 'Password12345!',
          displayName: 'Test Customer',
        ),
      );

      expect(response.outcome, 0);
      expect(
        response.message,
        'If registration can proceed, check your email for the next step.',
      );
    });

    test('throws FormatException when response body is null', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));

      addTearDown(() {
        dio.close(force: true);
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 202,
                data: null,
              ),
            );
          },
        ),
      );

      final service = AuthenticationApiService(dio);

      await expectLater(
        service.register(
          const RegistrationRequest(
            email: 'customer@example.test',
            password: 'Password12345!',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

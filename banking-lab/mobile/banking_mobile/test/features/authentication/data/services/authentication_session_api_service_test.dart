import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login posts without redirects and parses credentials', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.path, '/api/v1/auth/login');
          expect(options.followRedirects, isFalse);
          expect(options.maxRedirects, 0);
          expect(options.data, {
            'email': 'customer@example.test',
            'password': 'secret',
          });
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'accessToken': 'access',
                'refreshToken': 'refresh',
                'tokenType': 'Bearer',
                'expiresInSeconds': 300,
              },
            ),
          );
        },
      ),
    );

    final result = await AuthenticationApiService(dio).login(
      const LoginRequest(email: 'customer@example.test', password: 'secret'),
    );

    expect(result.accessToken, 'access');
    expect(result.refreshToken, 'refresh');
  });

  test('login maps a generic 401 to invalid credentials', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.badResponse(
            statusCode: 401,
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 401),
          ),
        ),
      ),
    );

    await expectLater(
      AuthenticationApiService(dio).login(
        const LoginRequest(email: 'customer@example.test', password: 'wrong'),
      ),
      throwsA(isA<InvalidCredentialsFailure>()),
    );
  });

  test('session and verification requests match backend endpoints', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    addTearDown(() => dio.close(force: true));
    final visited = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          visited.add('${options.method} ${options.uri.path}');
          expect(options.followRedirects, isFalse);
          expect(options.maxRedirects, 0);
          if (options.uri.path == '/api/v1/auth/refresh') {
            expect(options.data, {'refreshToken': 'old-refresh'});
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                  'tokenType': 'Bearer',
                  'expiresInSeconds': 300,
                },
              ),
            );
          } else if (options.uri.path == '/api/v1/auth/me') {
            expect(options.headers['Authorization'], 'Bearer new-access');
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'id': 'customer-id',
                  'displayName': 'Chris',
                },
              ),
            );
          } else if (options.uri.path == '/api/v1/auth/resend-verification') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 202,
                data: <String, dynamic>{'message': 'Check your email.'},
              ),
            );
          } else {
            handler.resolve(Response(requestOptions: options, statusCode: 204));
          }
        },
      ),
    );

    final service = AuthenticationApiService(dio);
    final refreshed = await service.refresh('old-refresh');
    final customer = await service.getCurrentCustomer(refreshed.accessToken);
    await service.confirmEmail(userId: 'customer-id', token: 'encoded-token');
    expect(
      await service.resendVerification('customer@example.test'),
      'Check your email.',
    );
    await service.logout('new-refresh');

    expect(customer.displayName, 'Chris');
    expect(visited, [
      'POST /api/v1/auth/refresh',
      'GET /api/v1/auth/me',
      'POST /api/v1/auth/verify-email',
      'POST /api/v1/auth/resend-verification',
      'POST /api/v1/auth/logout',
    ]);
  });

  test('all credential operations reject HTTP before Dio', () async {
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
    final service = AuthenticationApiService(dio);

    final operations = <Future<void> Function()>[
      () async => service.login(
        const LoginRequest(email: 'a@example.test', password: 'secret'),
      ),
      () async => service.refresh('refresh'),
      () => service.logout('refresh'),
      () async => service.getCurrentCustomer('access'),
      () => service.confirmEmail(userId: 'id', token: 'token'),
      () async => service.resendVerification('a@example.test'),
    ];
    for (final operation in operations) {
      await expectLater(
        operation(),
        throwsA(isA<SecureConnectionRequiredFailure>()),
      );
    }
    expect(requestCount, 0);
  });
}

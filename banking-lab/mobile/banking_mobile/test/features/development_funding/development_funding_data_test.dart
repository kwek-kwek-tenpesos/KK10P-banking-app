import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/development_funding/data/models/development_funding_receipt.dart';
import 'package:banking_mobile/features/development_funding/data/services/development_funding_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const receiptJson = <String, dynamic>{
  'transactionId': '11111111-1111-4111-8111-111111111111',
  'accountId': '22222222-2222-4222-8222-222222222222',
  'currency': 'PHP',
  'creditedAmountMinor': '5000000',
  'balanceAfterMinor': '5000000',
  'createdAtUtc': '2026-09-08T12:00:00Z',
  'replayed': false,
};

void main() {
  test('receipt uses exact integer minor units and UTC timestamps', () {
    final receipt = DevelopmentFundingReceipt.fromJson(receiptJson);
    expect(receipt.creditedAmountMinor, 5000000);
    expect(receipt.balanceAfterMinor, 5000000);
    for (final invalid in <Map<String, dynamic>>[
      {'creditedAmountMinor': 5000000},
      {'creditedAmountMinor': '-1'},
      {'balanceAfterMinor': '-1'},
      {'currency': 'USD'},
      {'createdAtUtc': '2026-09-08T12:00:00'},
      {'replayed': 'false'},
    ]) {
      expect(
        () => DevelopmentFundingReceipt.fromJson({...receiptJson, ...invalid}),
        throwsFormatException,
      );
    }
  });

  test('service sends exact empty POST, bearer, and idempotency key', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    late RequestOptions seen;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seen = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: receiptJson,
            ),
          );
        },
      ),
    );
    final receipt = await DevelopmentFundingApiService(dio).fund(
      token: 'test-token',
      idempotencyKey: '11111111-1111-4111-8111-111111111111',
    );
    expect(receipt.balanceAfterMinor, 5000000);
    expect(seen.method, 'POST');
    expect(seen.path, '/api/v1/development/funding/me');
    expect(seen.data, isEmpty);
    expect(seen.headers['Authorization'], 'Bearer test-token');
    expect(
      seen.headers['Idempotency-Key'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(seen.followRedirects, isFalse);
    expect(seen.maxRedirects, 0);
    dio.close();
  });

  test('service maps only known funding conflict codes', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    var code = 'account_not_opened';
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.badResponse(
            statusCode: 409,
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 409,
              data: {'code': code},
            ),
          ),
        ),
      ),
    );
    final api = DevelopmentFundingApiService(dio);
    Future<void> request() async =>
        api.fund(token: 'token', idempotencyKey: 'key');
    await expectLater(
      request(),
      throwsA(isA<DevelopmentAccountRequiredFailure>()),
    );
    code = 'development_funding_daily_limit_reached';
    await expectLater(
      request(),
      throwsA(isA<DevelopmentFundingLimitFailure>()),
    );
    code = 'idempotency_conflict';
    await expectLater(request(), throwsA(isA<IdempotencyConflictFailure>()));
    code = 'unknown';
    await expectLater(request(), throwsA(isA<ServerFailure>()));
    dio.close();
  });

  test('HTTP origins are rejected before sending credentials', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5255'));
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (_, handler) => requests++),
    );
    await expectLater(
      DevelopmentFundingApiService(dio)
          .fund(token: 'token', idempotencyKey: 'key'),
      throwsA(isA<SecureConnectionRequiredFailure>()),
    );
    expect(requests, 0);
    dio.close();
  });
}

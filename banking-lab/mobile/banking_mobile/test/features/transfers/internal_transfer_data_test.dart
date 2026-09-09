import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/transfers/data/models/internal_transfer_receipt.dart';
import 'package:banking_mobile/features/transfers/data/repositories/internal_transfer_repository.dart';
import 'package:banking_mobile/features/transfers/data/services/internal_transfer_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transfer_test_support.dart';
import '../accounts/account_test_support.dart';

const receiptJson = <String, dynamic>{
  'transactionId': '55555555-5555-4555-8555-555555555555',
  'sourceAccountReference': sourceReference,
  'destinationAccountReference': destinationReference,
  'currency': 'PHP',
  'amountMinor': '1050',
  'sourceBalanceAfterMinor': '98950',
  'status': 'COMPLETED',
  'createdAtUtc': '2026-09-09T01:02:03Z',
  'replayed': false,
};

void main() {
  test('strict receipt accepts exact integer strings and UTC server time', () {
    final receipt = InternalTransferReceipt.fromJson(receiptJson);
    expect(receipt.formattedAmount, 'PHP 10.50');
    expect(receipt.formattedSourceBalanceAfter, 'PHP 989.50');

    for (final invalid in <Map<String, dynamic>>[
      {'amountMinor': 1050},
      {'amountMinor': '01050'},
      {'sourceBalanceAfterMinor': '-1'},
      {'currency': 'USD'},
      {'status': 'PENDING'},
      {'createdAtUtc': '2026-09-09T01:02:03'},
      {'replayed': 'false'},
      {'transactionId': 'NOT-A-UUID'},
    ]) {
      expect(
        () => InternalTransferReceipt.fromJson({...receiptJson, ...invalid}),
        throwsFormatException,
      );
    }
  });

  test('strict receipt rejects zero identifiers', () {
    final json = <String, dynamic>{
      ...receiptJson,
      'transactionId': '00000000-0000-0000-0000-000000000000',
    };

    expect(() => InternalTransferReceipt.fromJson(json), throwsFormatException);
  });

  test(
    'service sends the exact transfer contract and accepts replay',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      late RequestOptions seen;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {...receiptJson, 'replayed': true},
              ),
            );
          },
        ),
      );
      final receipt = await InternalTransferApiService(dio).transfer(
        token: 'access-token',
        idempotencyKey: idempotencyKey,
        destinationAccountReference: destinationReference,
        amountMinor: BigInt.from(1050),
      );
      expect(receipt.replayed, isTrue);
      expect(seen.path, '/api/v1/transfers/internal');
      expect(seen.method, 'POST');
      expect(seen.data, {
        'destinationAccountReference': destinationReference,
        'amountMinor': '1050',
      });
      expect(seen.headers['Authorization'], 'Bearer access-token');
      expect(seen.headers['Idempotency-Key'], idempotencyKey);
      expect(seen.followRedirects, isFalse);
      expect(seen.maxRedirects, 0);
      dio.close();
    },
  );

  test('service maps every stable transfer failure code', () async {
    final cases = <(int, String, Type)>[
      (404, 'recipient_not_found', TransferRecipientNotFoundFailure),
      (409, 'account_not_opened', TransferAccountRequiredFailure),
      (409, 'self_transfer_not_allowed', TransferSelfNotAllowedFailure),
      (409, 'idempotency_conflict', TransferIdempotencyConflictFailure),
      (409, 'insufficient_funds', TransferInsufficientFundsFailure),
      (409, 'outgoing_daily_limit_reached', TransferDailyLimitFailure),
    ];
    for (final item in cases) {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException.badResponse(
              statusCode: item.$1,
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: item.$1,
                data: {'code': item.$2, 'traceId': 'request-123'},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        InternalTransferApiService(dio).transfer(
          token: 'token',
          idempotencyKey: idempotencyKey,
          destinationAccountReference: destinationReference,
          amountMinor: BigInt.one,
        ),
        throwsA(
          isA<AppFailure>()
              .having((failure) => failure.runtimeType, 'type', item.$3)
              .having(
                (failure) => failure.requestId,
                'requestId',
                'request-123',
              ),
        ),
      );
      dio.close();
    }
  });

  test('HTTP origin is rejected before credentials are sent', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5255'));
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (_, handler) => requests++),
    );
    await expectLater(
      InternalTransferApiService(dio).transfer(
        token: 'token',
        idempotencyKey: idempotencyKey,
        destinationAccountReference: destinationReference,
        amountMinor: BigInt.one,
      ),
      throwsA(isA<SecureConnectionRequiredFailure>()),
    );
    expect(requests, 0);
    dio.close();
  });

  test(
    'repository refreshes once and resends the identical envelope',
    () async {
      final sessionStore = MemoryAccountStore();
      final authApi = AccountAuthApi();
      final authentication = AuthenticationRepository(
        sessionStore,
        apiService: authApi,
      );
      await authentication.login(email: 'chris@example.test', password: 'pass');
      final transferApi = _RefreshingTransferApi();
      final repository = InternalTransferRepository(
        transferApi,
        authentication,
      );
      final pending = samplePending();

      final receipt = await repository.transfer(pending);

      expect(receipt.transactionId, sampleTransferReceipt.transactionId);
      expect(transferApi.tokens, ['chris@example.test', 'renewed']);
      expect(transferApi.keys, [idempotencyKey, idempotencyKey]);
      expect(transferApi.destinations, [
        destinationReference,
        destinationReference,
      ]);
      expect(authApi.refreshCalls, 1);
    },
  );
}

class _RefreshingTransferApi extends InternalTransferApiService {
  _RefreshingTransferApi() : super(Dio());

  final tokens = <String>[];
  final keys = <String>[];
  final destinations = <String>[];

  @override
  Future<InternalTransferReceipt> transfer({
    required String token,
    required String idempotencyKey,
    required String destinationAccountReference,
    required BigInt amountMinor,
  }) async {
    tokens.add(token);
    keys.add(idempotencyKey);
    destinations.add(destinationAccountReference);
    if (tokens.length == 1) throw const UnauthenticatedFailure();
    return sampleTransferReceipt;
  }
}

import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/data/repositories/accounts_repository.dart';
import 'package:banking_mobile/features/accounts/data/services/accounts_api_service.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  test('balance parsing and formatting use integer minor units', () {
    expect(sampleAccount.formattedBalance, 'PHP 0.00');
    final exact = AccountSummary(
      id: sampleAccount.id,
      currency: 'PHP',
      balanceMinor: BigInt.parse('9007199254740993'),
      openedAtUtc: sampleAccount.openedAtUtc,
    );
    expect(exact.formattedBalance, 'PHP 90071992547409.93');
    for (final invalid in <Map<String, dynamic>>[
      {'balanceMinor': 0},
      {'balanceMinor': '0.00'},
      {'balanceMinor': '1'},
      {'balanceMinor': '-1'},
      {'currency': 'USD'},
      {'id': 'bad'},
      {'openedAtUtc': 'bad'},
      {'openedAtUtc': '2026-09-06T00:00:00'},
    ]) {
      expect(
        () => AccountSummary.fromJson({...accountJson, ...invalid}),
        throwsFormatException,
      );
    }
  });

  test(
    'service sends only empty PUT with bearer and redirects disabled',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final seen = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: accountJson,
                statusCode: options.method == 'PUT' ? 201 : 200,
              ),
            );
          },
        ),
      );
      final api = AccountsApiService(dio);
      expect((await api.open('test-token')).formattedBalance, 'PHP 0.00');
      await api.read('test-token');
      expect(seen.first.method, 'PUT');
      expect(seen.first.data, isEmpty);
      expect(seen.last.method, 'GET');
      expect(seen.last.data, isNull);
      for (final request in seen) {
        expect(request.path, '/api/v1/accounts/me');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
      }
      dio.close();
    },
  );

  test(
    'HTTP and credential-bearing origins are rejected before any request',
    () async {
      for (final url in [
        'http://localhost:5255',
        'https://user:pass@example.test',
      ]) {
        final dio = Dio(BaseOptions(baseUrl: url));
        var requests = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (_, handler) {
              requests++;
            },
          ),
        );
        await expectLater(
          AccountsApiService(dio).read('token'),
          throwsA(isA<SecureConnectionRequiredFailure>()),
        );
        expect(requests, 0);
        dio.close();
      }
    },
  );

  test('only explicit account_not_opened 404 maps to unopened', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    var status = 404;
    dynamic body = {'code': 'account_not_opened'};
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.badResponse(
            statusCode: status,
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: status,
              data: body,
            ),
          ),
        ),
      ),
    );
    final api = AccountsApiService(dio);
    expect(await api.read('token'), isNull);
    body = {'code': 'other'};
    await expectLater(api.read('token'), throwsA(isA<ServerFailure>()));
    status = 503;
    await expectLater(api.read('token'), throwsA(isA<ServerFailure>()));
    status = 401;
    await expectLater(
      api.read('token'),
      throwsA(isA<UnauthenticatedFailure>()),
    );
    status = 429;
    await expectLater(api.read('token'), throwsA(isA<RateLimitedFailure>()));
    dio.close();
  });

  test(
    '401 refreshes once and retries once without an infinite loop',
    () async {
      final authApi = AccountAuthApi();
      final auth = AuthenticationRepository(
        MemoryAccountStore(),
        apiService: authApi,
      );
      await auth.login(email: 'first', password: 'test-only');
      final api = StubAccountsApi()
        ..onRead = (token) async => token == 'renewed'
            ? sampleAccount
            : throw const UnauthenticatedFailure();
      final repo = AccountsRepository(api, auth);
      expect(await repo.read(), sampleAccount);
      expect(authApi.refreshCalls, 1);
      expect(api.reads, 2);
      api.onRead = (_) async => throw const UnauthenticatedFailure();
      await expectLater(repo.read(), throwsA(isA<UnauthenticatedFailure>()));
      expect(authApi.refreshCalls, 2);
      expect(api.reads, 4);
    },
  );

  test('concurrent 401 responses share in-flight refresh', () async {
    final authApi = AccountAuthApi()
      ..refreshGate = Completer<AuthenticationTokens>();
    final auth = AuthenticationRepository(
      MemoryAccountStore(),
      apiService: authApi,
    );
    await auth.login(email: 'first', password: 'test-only');
    final api = StubAccountsApi()
      ..onRead = (token) async => token == 'renewed'
          ? sampleAccount
          : throw const UnauthenticatedFailure();
    final repo = AccountsRepository(api, auth);
    final first = repo.read();
    final second = repo.read();
    await Future<void>.delayed(Duration.zero);
    expect(authApi.refreshCalls, 1);
    authApi.refreshGate!.complete(authApi.tokens('renewed'));
    expect(await Future.wait([first, second]), [sampleAccount, sampleAccount]);
  });

  test('late account response is discarded after another login', () async {
    final auth = AuthenticationRepository(
      MemoryAccountStore(),
      apiService: AccountAuthApi(),
    );
    await auth.login(email: 'first', password: 'test-only');
    final gate = Completer<AccountSummary?>();
    final api = StubAccountsApi()..onRead = (_) => gate.future;
    final pending = AccountsRepository(api, auth).read();
    final check = expectLater(pending, throwsA(isA<RequestCancelledFailure>()));
    await Future<void>.delayed(Duration.zero);
    await auth.login(email: 'second', password: 'test-only');
    gate.complete(sampleAccount);
    await check;
    expect(auth.currentCustomer?.id, 'second');
  });
}

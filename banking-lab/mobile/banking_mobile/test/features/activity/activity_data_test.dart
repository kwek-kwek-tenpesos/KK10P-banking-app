import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/data/repositories/activity_repository.dart';
import 'package:banking_mobile/features/activity/data/services/activity_api_service.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'activity_test_support.dart';
import '../accounts/account_test_support.dart';

void main() {
  test('strict Activity models parse money, direction, and references', () {
    final item = ActivityItem.fromJson(activityItemJson);
    expect(item.formattedAmount, '-PHP 10.50');
    expect(item.counterpartyLabel, 'Account •••• 4444');
    final detail = ActivityDetail.fromJson(activityDetailJson);
    expect(detail.counterpartyAccountReference, counterpartyReference);

    for (final invalid in <Map<String, dynamic>>[
      {'amountMinor': 1050},
      {'amountMinor': '01050'},
      {'currency': 'USD'},
      {'status': 'PENDING'},
      {'occurredAtUtc': '2026-09-09T01:02:03'},
      {'direction': 'SIDEWAYS'},
      {'counterpartyReferenceSuffix': '4444'},
      {'counterpartyReferenceSuffix': null},
      {'type': 'DEVELOPMENT_FUNDING'},
      {
        'counterpartyType': 'SIMULATOR_ISSUER',
        'counterpartyReferenceSuffix': '12344444',
      },
    ]) {
      expect(
        () => ActivityItem.fromJson({...activityItemJson, ...invalid}),
        throwsFormatException,
      );
    }
    expect(
      () => ActivityItem.fromJson({...activityItemJson, 'unexpected': true}),
      throwsFormatException,
    );
    expect(
      () => ActivityDetail.fromJson({
        ...activityDetailJson,
        'counterpartyType': 'SIMULATOR_ISSUER',
        'counterpartyAccountReference': null,
      }),
      throwsFormatException,
    );
  });

  test('page rejects duplicate transaction IDs and invalid cursors', () {
    expect(
      () => ActivityPage.fromJson({
        'items': [activityItemJson, activityItemJson],
        'nextCursor': null,
      }),
      throwsFormatException,
    );
    expect(
      () => ActivityPage.fromJson({'items': const [], 'nextCursor': 'x' * 65}),
      throwsFormatException,
    );
    expect(
      () => ActivityPage.fromJson({
        'items': const [],
        'nextCursor': 'not a url-safe cursor',
      }),
      throwsFormatException,
    );
  });

  test('service sends exact pagination/filter contract over HTTPS', () async {
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
              data: {
                'items': [activityItemJson],
                'nextCursor': 'cursor-1',
              },
            ),
          );
        },
      ),
    );
    final page = await ActivityApiService(dio).readPage(
      'token',
      filters: const ActivityFilters(
        direction: ActivityDirection.outgoing,
        type: ActivityType.internalTransfer,
      ),
      cursor: 'cursor-0',
    );
    expect(page.nextCursor, 'cursor-1');
    expect(seen.method, 'GET');
    expect(seen.path, '/api/v1/accounts/me/transactions');
    expect(seen.queryParameters, {
      'limit': 20,
      'cursor': 'cursor-0',
      'direction': 'OUTGOING',
      'type': 'INTERNAL_TRANSFER',
    });
    expect(seen.headers['Authorization'], 'Bearer token');
    expect(seen.followRedirects, isFalse);
    dio.close();
  });

  test(
    'service maps stable Activity 404 codes without leaking detail',
    () async {
      for (final item in <(String, Type)>[
        ('account_not_opened', ActivityAccountRequiredFailure),
        ('transaction_not_found', ActivityTransactionNotFoundFailure),
      ]) {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException.badResponse(
                statusCode: 404,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'code': item.$1, 'traceId': 'request-7'},
                ),
              ),
            ),
          ),
        );
        final future = item.$1 == 'account_not_opened'
            ? ActivityApiService(dio).readPage('token')
            : ActivityApiService(dio).readDetail('token', transactionId);
        await expectLater(
          future,
          throwsA(
            isA<AppFailure>()
                .having((failure) => failure.runtimeType, 'type', item.$2)
                .having(
                  (failure) => failure.requestId,
                  'requestId',
                  'request-7',
                ),
          ),
        );
        dio.close();
      }
    },
  );

  test(
    'HTTP origin is rejected before the Activity credential is sent',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5255'));
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(onRequest: (_, _) => requests++),
      );
      await expectLater(
        ActivityApiService(dio).readPage('token'),
        throwsA(isA<SecureConnectionRequiredFailure>()),
      );
      expect(requests, 0);
      dio.close();
    },
  );

  test(
    'repository refreshes once and retries the same Activity read',
    () async {
      final authApi = AccountAuthApi();
      final authentication = AuthenticationRepository(
        MemoryAccountStore(),
        apiService: authApi,
      );
      await authentication.login(email: 'chris', password: 'test-only');
      final api = _RefreshingActivityApi();
      final repository = ActivityRepository(api, authentication);

      final page = await repository.readPage(
        filters: const ActivityFilters(direction: ActivityDirection.incoming),
        cursor: 'cursor-1',
      );

      expect(page.items, hasLength(1));
      expect(api.tokens, ['chris', 'renewed']);
      expect(api.cursors, ['cursor-1', 'cursor-1']);
      expect(api.directions, [
        ActivityDirection.incoming,
        ActivityDirection.incoming,
      ]);
      expect(authApi.refreshCalls, 1);
    },
  );
}

class _RefreshingActivityApi extends ActivityApiService {
  _RefreshingActivityApi() : super(Dio());

  final tokens = <String>[];
  final cursors = <String?>[];
  final directions = <ActivityDirection?>[];

  @override
  Future<ActivityPage> readPage(
    String token, {
    ActivityFilters filters = const ActivityFilters(),
    String? cursor,
    int limit = 20,
  }) async {
    tokens.add(token);
    cursors.add(cursor);
    directions.add(filters.direction);
    if (tokens.length == 1) throw const UnauthenticatedFailure();
    return ActivityPage(items: [sampleActivityItem]);
  }
}

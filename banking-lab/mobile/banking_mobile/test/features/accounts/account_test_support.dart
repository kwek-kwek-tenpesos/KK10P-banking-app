import 'dart:async';

import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/data/repositories/accounts_repository.dart';
import 'package:banking_mobile/features/accounts/data/services/accounts_api_service.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:dio/dio.dart';

final sampleAccount = AccountSummary.fromJson(accountJson);
const accountJson = <String, dynamic>{
  'id': '11111111-1111-1111-1111-111111111111',
  'currency': 'PHP',
  'balanceMinor': '0',
  'openedAtUtc': '2026-09-06T00:00:00Z',
};

class MemoryAccountStore implements SecureSessionStore {
  String? token;
  @override
  Future<String?> readRefreshToken() async => token;
  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    token = refreshToken;
  }

  @override
  Future<void> clearRefreshToken() async {
    token = null;
  }
}

class AccountAuthApi extends AuthenticationApiService {
  AccountAuthApi() : super(Dio());
  int refreshCalls = 0;
  Completer<AuthenticationTokens>? refreshGate;
  Object? refreshError;
  AuthenticationTokens tokens(String label) => AuthenticationTokens(
    accessToken: label,
    refreshToken: 'refresh-$label',
    tokenType: 'Bearer',
    expiresInSeconds: 300,
  );
  @override
  Future<AuthenticationTokens> login(LoginRequest request) async =>
      tokens(request.email);
  @override
  Future<AuthenticatedCustomer> getCurrentCustomer(String accessToken) async =>
      AuthenticatedCustomer(id: accessToken, displayName: accessToken);
  @override
  Future<AuthenticationTokens> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return refreshGate?.future ?? tokens('renewed');
  }

  @override
  Future<void> logout(String refreshToken) async {}
}

class StubAccountsApi extends AccountsApiService {
  StubAccountsApi() : super(Dio());
  Future<AccountSummary?> Function(String)? onRead;
  Future<AccountSummary> Function(String)? onOpen;
  int reads = 0;
  int opens = 0;
  @override
  Future<AccountSummary?> read(String token) async {
    reads++;
    return onRead == null ? null : await onRead!(token);
  }

  @override
  Future<AccountSummary> open(String token) async {
    opens++;
    return onOpen == null ? sampleAccount : await onOpen!(token);
  }
}

class StubAccountsRepository implements AccountsRepository {
  Future<AccountSummary?> Function()? onRead;
  Future<AccountSummary> Function()? onOpen;
  int reads = 0;
  int opens = 0;
  @override
  Future<AccountSummary?> read() async {
    reads++;
    return onRead == null ? null : await onRead!();
  }

  @override
  Future<AccountSummary> open() async {
    opens++;
    return onOpen == null ? sampleAccount : await onOpen!();
  }
}

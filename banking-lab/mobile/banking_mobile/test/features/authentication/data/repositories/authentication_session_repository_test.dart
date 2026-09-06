import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login stores refresh token and loads safe customer profile', () async {
    final store = _MemorySessionStore();
    final api = _SessionApi();
    final repository = AuthenticationRepository(store, apiService: api);

    final session = await repository.login(
      email: ' customer@example.test ',
      password: 'secret',
    );

    expect(api.loginRequest?.email, ' customer@example.test ');
    expect(store.refreshToken, 'new-refresh');
    expect(session.customer.displayName, 'Chris');
    expect(repository.currentCustomer?.id, 'customer-id');
  });

  test('rejected stored refresh token is cleared', () async {
    final store = _MemorySessionStore(refreshToken: 'rejected');
    final api = _SessionApi(refreshError: const UnauthenticatedFailure());
    final repository = AuthenticationRepository(store, apiService: api);

    expect(await repository.restoreSession(), isNull);
    expect(store.refreshToken, isNull);
  });

  test('temporary restore failure preserves refresh token for retry', () async {
    final store = _MemorySessionStore(refreshToken: 'keep-me');
    final api = _SessionApi(refreshError: const NetworkFailure());
    final repository = AuthenticationRepository(store, apiService: api);

    await expectLater(
      repository.restoreSession(),
      throwsA(isA<NetworkFailure>()),
    );
    expect(store.refreshToken, 'keep-me');
  });

  test('concurrent refresh callers share one rotation', () async {
    final store = _MemorySessionStore(refreshToken: 'old-refresh');
    final gate = Completer<AuthenticationTokens>();
    final api = _SessionApi(refreshGate: gate);
    final repository = AuthenticationRepository(store, apiService: api);

    final first = repository.refreshSession();
    final second = repository.refreshSession();
    expect(identical(first, second), isTrue);
    gate.complete(_SessionApi.tokens);

    await Future.wait([first, second]);
    expect(api.refreshCalls, 1);
    expect(store.refreshToken, 'new-refresh');
  });

  test(
    'logout clears local credentials when server revocation fails',
    () async {
      final store = _MemorySessionStore(refreshToken: 'refresh');
      final api = _SessionApi(logoutError: const NetworkFailure());
      final repository = AuthenticationRepository(store, apiService: api);

      await expectLater(repository.logout(), throwsA(isA<NetworkFailure>()));
      expect(store.refreshToken, isNull);
      expect(repository.currentCustomer, isNull);
    },
  );

  test('late refresh cannot restore credentials after logout', () async {
    final store = _MemorySessionStore(refreshToken: 'old-refresh');
    final gate = Completer<AuthenticationTokens>();
    final api = _SessionApi(refreshGate: gate);
    final repository = AuthenticationRepository(store, apiService: api);
    final refresh = repository.refreshSession();
    final check = expectLater(refresh, throwsA(isA<RequestCancelledFailure>()));
    await Future<void>.delayed(Duration.zero);
    await repository.logout();
    gate.complete(_SessionApi.tokens);
    await check;
    expect(store.refreshToken, isNull);
    expect(repository.currentCustomer, isNull);
    expect(api.logoutTokens, ['old-refresh']);
  });

  test(
    'logout waits for pending secure write then revokes its rotated token',
    () async {
      final store = _MemorySessionStore(refreshToken: 'old-refresh');
      final api = _SessionApi();
      final repository = AuthenticationRepository(store, apiService: api);
      store.saveGate = Completer<void>();
      final refresh = repository.refreshSession();
      final check = expectLater(
        refresh,
        throwsA(isA<RequestCancelledFailure>()),
      );
      await store.saveStarted.future;
      final logout = repository.logout();
      store.saveGate!.complete();
      await Future.wait([check, logout]);
      expect(store.refreshToken, isNull);
      expect(repository.currentCustomer, isNull);
      expect(api.logoutTokens, ['new-refresh']);
    },
  );

  test(
    'old refresh cannot overwrite a newer login during secure write',
    () async {
      final store = _MemorySessionStore(refreshToken: 'old-refresh');
      final api = _SessionApi();
      final repository = AuthenticationRepository(store, apiService: api);
      store.saveGate = Completer<void>();
      final refresh = repository.refreshSession();
      final check = expectLater(
        refresh,
        throwsA(isA<RequestCancelledFailure>()),
      );
      await store.saveStarted.future;
      final login = repository.login(
        email: 'second@example.test',
        password: 'test-only',
      );
      store.saveGate!.complete();
      await check;
      await login;
      expect(store.refreshToken, 'new-refresh');
      expect(repository.currentCustomer, isNotNull);
      expect(api.loginRequest?.email, 'second@example.test');
    },
  );

  test('failed secure write revokes new server token best-effort', () async {
    final store = _MemorySessionStore(
      saveError: Exception('secure write failed'),
    );
    final api = _SessionApi();
    final repository = AuthenticationRepository(store, apiService: api);

    await expectLater(
      repository.login(email: 'customer@example.test', password: 'secret'),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(api.logoutTokens, ['new-refresh']);
    expect(repository.currentCustomer, isNull);
  });
}

final class _MemorySessionStore implements SecureSessionStore {
  _MemorySessionStore({this.refreshToken, this.saveError});

  String? refreshToken;
  final Object? saveError;
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    if (saveError != null) throw saveError!;
    if (!saveStarted.isCompleted) saveStarted.complete();
    await saveGate?.future;
    this.refreshToken = refreshToken;
  }
}

final class _SessionApi implements AuthenticationApiService {
  _SessionApi({this.refreshError, this.logoutError, this.refreshGate});

  static const tokens = AuthenticationTokens(
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
    tokenType: 'Bearer',
    expiresInSeconds: 300,
  );

  final Object? refreshError;
  final Object? logoutError;
  final Completer<AuthenticationTokens>? refreshGate;
  int refreshCalls = 0;
  LoginRequest? loginRequest;
  final List<String> logoutTokens = [];

  @override
  Future<AuthenticationTokens> login(LoginRequest request) async {
    loginRequest = request;
    return tokens;
  }

  @override
  Future<AuthenticationTokens> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return refreshGate?.future ?? tokens;
  }

  @override
  Future<AuthenticatedCustomer> getCurrentCustomer(String accessToken) async =>
      const AuthenticatedCustomer(id: 'customer-id', displayName: 'Chris');

  @override
  Future<void> logout(String refreshToken) async {
    logoutTokens.add(refreshToken);
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<void> confirmEmail({required String userId, required String token}) =>
      throw UnimplementedError();

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) =>
      throw UnimplementedError();

  @override
  Future<String> resendVerification(String email) => throw UnimplementedError();
}

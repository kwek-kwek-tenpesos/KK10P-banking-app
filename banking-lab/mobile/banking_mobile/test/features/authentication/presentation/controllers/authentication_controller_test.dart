import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_app_preferences_store.dart';

void main() {
  test('successful restoration attaches the known-account marker', () async {
    final repository = _StubAuthenticationRepository()
      ..restoreResult = _session();
    final preferences = AppPreferencesController(MemoryAppPreferencesStore());
    addTearDown(preferences.dispose);
    final controller = AuthenticationController(repository, preferences);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.state.status, AuthenticationStatus.signedIn);
    expect(preferences.state.knownAccountAttached, isTrue);
  });

  test('retryable restoration failure preserves an attached marker', () async {
    final repository = _StubAuthenticationRepository()
      ..restoreError = const NetworkFailure();
    final preferences = AppPreferencesController(
      MemoryAppPreferencesStore(
        introductionCompleted: true,
        knownAccountAttached: true,
      ),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    final controller = AuthenticationController(repository, preferences);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.state.status, AuthenticationStatus.signedOut);
    expect(controller.state.canRetryRestore, isTrue);
    expect(preferences.state.knownAccountAttached, isTrue);
  });

  test('rapid repeated login remains single flight', () async {
    final repository = _StubAuthenticationRepository();
    final preferences = AppPreferencesController(MemoryAppPreferencesStore());
    addTearDown(preferences.dispose);
    final controller = AuthenticationController(repository, preferences);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AuthenticationStatus.signedOut);

    final gate = Completer<AuthenticationSession>();
    repository.onLogin = ({required email, required password}) => gate.future;

    final first = controller.login(
      email: 'customer@example.test',
      password: 'Correct Horse Battery Staple!',
    );
    final duplicate = controller.login(
      email: 'customer@example.test',
      password: 'Correct Horse Battery Staple!',
    );

    expect(await duplicate, isFalse);
    expect(repository.logins, 1);
    expect(controller.state.status, AuthenticationStatus.submitting);

    gate.complete(_session());

    expect(await first, isTrue);
    expect(repository.logins, 1);
    expect(controller.state.status, AuthenticationStatus.signedIn);
    expect(preferences.state.knownAccountAttached, isTrue);
  });

  test(
    'explicit logout clears marker after local credentials are cleared',
    () async {
      final repository = _StubAuthenticationRepository();
      final preferences = AppPreferencesController(
        MemoryAppPreferencesStore(
          introductionCompleted: true,
          knownAccountAttached: true,
        ),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      final controller = AuthenticationController(repository, preferences);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      await controller.logout();

      expect(preferences.state.knownAccountAttached, isFalse);
      expect(controller.state.status, AuthenticationStatus.signedOut);
    },
  );

  test(
    'uncertain secure-storage deletion preserves known-account marker',
    () async {
      final repository = _StubAuthenticationRepository()
        ..logoutError = const SessionStorageFailure();
      final preferences = AppPreferencesController(
        MemoryAppPreferencesStore(
          introductionCompleted: true,
          knownAccountAttached: true,
        ),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      final controller = AuthenticationController(repository, preferences);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      await controller.logout();

      expect(preferences.state.knownAccountAttached, isTrue);
      expect(controller.state.errorMessage, contains('could not be cleared'));
    },
  );
}

typedef _LoginHandler = Future<AuthenticationSession> Function({
  required String email,
  required String password,
});

final class _StubAuthenticationRepository extends AuthenticationRepository {
  _StubAuthenticationRepository() : super(_StubSecureSessionStore());

  _LoginHandler? onLogin;
  int logins = 0;
  Object? logoutError;
  AuthenticationSession? restoreResult;
  Object? restoreError;

  @override
  Future<AuthenticationSession?> restoreSession() async {
    if (restoreError case final error?) throw error;
    return restoreResult;
  }

  @override
  Future<AuthenticationSession> login({
    required String email,
    required String password,
  }) {
    logins++;
    return onLogin!(email: email, password: password);
  }

  @override
  Future<void> logout() async {
    if (logoutError case final error?) throw error;
  }
}

AuthenticationSession _session() => AuthenticationSession(
  customer: const AuthenticatedCustomer(
    id: 'customer-id',
    displayName: 'Customer',
  ),
  accessToken: 'access-token',
  accessTokenExpiresAt: DateTime.utc(2030),
);

final class _StubSecureSessionStore implements SecureSessionStore {
  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}
}

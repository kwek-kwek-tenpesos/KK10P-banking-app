import 'dart:async';

import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rapid repeated login remains single flight', () async {
    final repository = _StubAuthenticationRepository();
    final controller = AuthenticationController(repository);
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

    gate.complete(
      AuthenticationSession(
        customer: const AuthenticatedCustomer(
          id: 'customer-id',
          displayName: 'Customer',
        ),
        accessToken: 'access-token',
        accessTokenExpiresAt: DateTime.utc(2030),
      ),
    );

    expect(await first, isTrue);
    expect(repository.logins, 1);
    expect(controller.state.status, AuthenticationStatus.signedIn);
  });
}

typedef _LoginHandler = Future<AuthenticationSession> Function({
  required String email,
  required String password,
});

final class _StubAuthenticationRepository extends AuthenticationRepository {
  _StubAuthenticationRepository() : super(_StubSecureSessionStore());

  _LoginHandler? onLogin;
  int logins = 0;

  @override
  Future<AuthenticationSession?> restoreSession() async => null;

  @override
  Future<AuthenticationSession> login({
    required String email,
    required String password,
  }) {
    logins++;
    return onLogin!(email: email, password: password);
  }
}

final class _StubSecureSessionStore implements SecureSessionStore {
  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}
}

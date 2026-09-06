import 'dart:async';

import 'package:banking_mobile/app/app.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/data/services/accounts_api_service.dart';
import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/core/storage/secure_session_store_provider.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/accounts/account_test_support.dart';

void main() {
  testWidgets('signed-out customer can open API diagnostics', (tester) async {
    final store = _MemorySessionStore();
    await tester.pumpWidget(
      _testApp(store: store, api: _FakeAuthenticationApi()),
    );
    await tester.pumpAndSettle();

    expect(find.text('KK10P Bank'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'KK10P Bank',
    );
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Open API diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Banking API'), findsOneWidget);
    expect(find.text('Version: v1.0.0'), findsOneWidget);
    expect(find.text('Environment: Test'), findsOneWidget);
  });

  testWidgets('customer can sign in, enter protected home, and sign out', (
    tester,
  ) async {
    final store = _MemorySessionStore();
    final api = _FakeAuthenticationApi();
    await tester.pumpWidget(_testApp(store: store, api: api));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Email address'),
      'customer@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'fake-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Chris'), findsOneWidget);
    expect(
      find.text('Your authenticated simulator session is active.'),
      findsOneWidget,
    );
    expect(store.refreshToken, 'new-refresh');

    await tester.tap(find.widgetWithText(FilledButton, 'Open account'));
    await tester.pumpAndSettle();
    expect(find.text('PHP 0.00'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(store.refreshToken, isNull);
    expect(api.loggedOutTokens, ['new-refresh']);
  });

  testWidgets('final account 401 clears session and redirects to sign-in', (
    tester,
  ) async {
    final store = _MemorySessionStore();
    final accounts = StubAccountsApi()
      ..onRead = (_) async => throw const UnauthenticatedFailure();
    await tester.pumpWidget(
      _testApp(store: store, api: _FakeAuthenticationApi(), accounts: accounts),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Email address'),
      'customer@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'fake-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(store.refreshToken, isNull);
    expect(find.text('Simulator funds'), findsNothing);
  });

  testWidgets('logout while account request is pending discards late data', (
    tester,
  ) async {
    final store = _MemorySessionStore();
    final gate = Completer<AccountSummary?>();
    final accounts = StubAccountsApi()..onRead = (_) => gate.future;
    await tester.pumpWidget(
      _testApp(store: store, api: _FakeAuthenticationApi(), accounts: accounts),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Email address'),
      'customer@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'fake-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loading your account…'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    gate.complete(sampleAccount);
    await tester.pumpAndSettle();
    expect(store.refreshToken, isNull);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('PHP 0.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({
  required _MemorySessionStore store,
  required _FakeAuthenticationApi api,
  StubAccountsApi? accounts,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(apiBaseUrl: 'https://example.test'),
      ),
      secureSessionStoreProvider.overrideWithValue(store),
      authenticationApiServiceProvider.overrideWithValue(api),
      accountsApiServiceProvider.overrideWithValue(
        accounts ?? StubAccountsApi(),
      ),
      systemInfoProvider.overrideWith(
        (ref) async => const SystemInfo(
          name: 'Banking API',
          version: 'v1.0.0',
          environment: 'Test',
        ),
      ),
    ],
    child: const BankingLabApp(),
  );
}

final class _MemorySessionStore implements SecureSessionStore {
  String? refreshToken;

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    this.refreshToken = refreshToken;
  }
}

final class _FakeAuthenticationApi implements AuthenticationApiService {
  final List<String> loggedOutTokens = [];

  @override
  Future<AuthenticationTokens> login(LoginRequest request) async =>
      const AuthenticationTokens(
        accessToken: 'access-token',
        refreshToken: 'new-refresh',
        tokenType: 'Bearer',
        expiresInSeconds: 300,
      );

  @override
  Future<AuthenticatedCustomer> getCurrentCustomer(String accessToken) async =>
      const AuthenticatedCustomer(id: 'customer-id', displayName: 'Chris');

  @override
  Future<void> logout(String refreshToken) async {
    loggedOutTokens.add(refreshToken);
  }

  @override
  Future<AuthenticationTokens> refresh(String refreshToken) =>
      throw const UnauthenticatedFailure();

  @override
  Future<void> confirmEmail({required String userId, required String token}) =>
      throw UnimplementedError();

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) =>
      throw UnimplementedError();

  @override
  Future<String> resendVerification(String email) => throw UnimplementedError();
}

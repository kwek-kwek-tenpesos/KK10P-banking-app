import 'package:banking_mobile/app/app.dart';
import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/core/preferences/app_preferences_provider.dart';
import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:banking_mobile/core/storage/secure_session_store_provider.dart';
import 'package:banking_mobile/features/accounts/data/services/accounts_api_service.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:banking_mobile/features/client_compatibility/presentation/controllers/client_compatibility_controller.dart';
import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/account_test_support.dart';
import '../../support/memory_app_preferences_store.dart';

void main() {
  testWidgets('Home shows only truthful one-account content', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Hello, Chris'), findsOneWidget);
    expect(
      find.text(
        'Educational fake-money simulator. No real funds or payment services.',
      ),
      findsOneWidget,
    );
    expect(find.text('Simulator funds'), findsOneWidget);
    expect(find.text('PHP 0.00'), findsOneWidget);
    expect(find.byTooltip('API diagnostics'), findsOneWidget);
    expect(find.text('Transfer funds'), findsOneWidget);
    expect(find.text('View activity'), findsOneWidget);
    expect(find.text('Copy account reference'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    for (final unsupported in [
      'Quick Send',
      'Transfer',
      'Pay Bills',
      'Recent transactions',
      'View All (6)',
    ]) {
      expect(find.text(unsupported), findsNothing);
    }
  });

  testWidgets('blank display name uses Customer fallback', (tester) async {
    await _pumpHome(tester, displayName: '   ');

    expect(find.text('Hello, Customer'), findsOneWidget);
  });

  testWidgets('Home remains scroll-reachable at 320 width and 200% text', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      displayName: 'A Customer With A Deliberately Long Display Name',
      width: 320,
      textScale: 2,
      appearance: AppAppearance.dark,
    );

    expect(tester.takeException(), isNull);
    final signOut = find.text('Sign out');
    await tester.ensureVisible(signOut);
    await tester.pump();
    expect(signOut, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Diagnostics remains reachable from authenticated Home', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.tap(find.byTooltip('API diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Banking API'), findsOneWidget);
    expect(find.text('Environment: Test'), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  String? displayName = 'Chris',
  double width = 412,
  double textScale = 1,
  AppAppearance appearance = AppAppearance.light,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final sessionStore = MemoryAccountStore()..token = 'existing-refresh';
  final authApi = _HomeAuthenticationApi(displayName);
  final accountsApi = StubAccountsApi()..onRead = (_) async => sampleAccount;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'https://example.test'),
        ),
        secureSessionStoreProvider.overrideWithValue(sessionStore),
        appPreferencesStoreProvider.overrideWithValue(
          MemoryAppPreferencesStore(
            appearance: appearance,
            introductionCompleted: true,
            knownAccountAttached: true,
          ),
        ),
        authenticationApiServiceProvider.overrideWithValue(authApi),
        clientCompatibilityChecksEnabledProvider.overrideWithValue(false),
        accountsApiServiceProvider.overrideWithValue(accountsApi),
        systemInfoProvider.overrideWith(
          (ref) async => const SystemInfo(
            name: 'Banking API',
            version: 'v1.0.0',
            environment: 'Test',
          ),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1200),
          textScaler: TextScaler.linear(textScale),
        ),
        child: const BankingLabApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _HomeAuthenticationApi extends AccountAuthApi {
  _HomeAuthenticationApi(this.displayName);

  final String? displayName;

  @override
  Future<AuthenticatedCustomer> getCurrentCustomer(String accessToken) async {
    return AuthenticatedCustomer(id: 'customer-id', displayName: displayName);
  }
}

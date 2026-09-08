import 'package:banking_mobile/core/preferences/app_preferences_provider.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/email_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_app_preferences_store.dart';

void main() {
  testWidgets('missing link data presents the safe invalid state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const EmailVerificationScreen(userId: null, token: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invalid verification link'), findsOneWidget);
    expect(
      find.textContaining('Request a new verification message'),
      findsOneWidget,
    );
    expect(find.text('Confirm email'), findsNothing);
  });

  testWidgets('confirmation submits the token without rendering it', (
    tester,
  ) async {
    final repository = _VerificationRepository();
    await tester.pumpWidget(
      _app(
        const EmailVerificationScreen(
          userId: 'customer-id',
          token: 'secret-one-use-token',
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('secret-one-use-token'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm email'));
    await tester.pumpAndSettle();

    expect(repository.confirmations, 1);
    expect(find.text('Email verified'), findsOneWidget);
    expect(find.text('secret-one-use-token'), findsNothing);
  });

  testWidgets('verification remains usable at 320 width and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _app(
        const EmailVerificationScreen(userId: 'customer-id', token: 'token'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm email'));

    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget home, {AuthenticationRepository? repository}) {
  return ProviderScope(
    overrides: [
      appPreferencesStoreProvider.overrideWithValue(
        MemoryAppPreferencesStore(introductionCompleted: true),
      ),
      if (repository != null)
        authenticationRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(theme: KkTheme.light(), home: home),
  );
}

final class _VerificationRepository extends AuthenticationRepository {
  _VerificationRepository() : super(_StubSessionStore());

  int confirmations = 0;

  @override
  Future<void> confirmEmail({
    required String userId,
    required String token,
  }) async {
    confirmations++;
  }
}

final class _StubSessionStore implements SecureSessionStore {
  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}
}

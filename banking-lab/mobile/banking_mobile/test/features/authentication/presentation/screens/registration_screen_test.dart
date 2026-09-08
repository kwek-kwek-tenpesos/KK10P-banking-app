import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/preferences/app_preferences_provider.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_app_preferences_store.dart';

void main() {
  group('RegistrationScreen', () {
    late _FakeAuthRepository fakeRepository;

    setUp(() {
      fakeRepository = _FakeAuthRepository();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          authenticationRepositoryProvider.overrideWithValue(fakeRepository),
          appPreferencesStoreProvider.overrideWithValue(
            MemoryAppPreferencesStore(introductionCompleted: true),
          ),
        ],
        child: MaterialApp(
          theme: KkTheme.light(),
          home: const RegistrationScreen(),
        ),
      );
    }

    testWidgets('renders all registration form inputs and submit button', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Create account'), findsNWidgets(2));
      expect(find.text('Create your KK10P account'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Display name (optional)'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation errors when submitted empty', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('toggles password visibility icon', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final passwordFieldFinder = find.widgetWithText(TextField, 'Password');
      expect(passwordFieldFinder, findsOneWidget);

      final initialField = tester.widget<TextField>(passwordFieldFinder);
      expect(initialField.obscureText, isTrue);
      expect(find.byTooltip('Show password'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final toggledField = tester.widget<TextField>(passwordFieldFinder);
      expect(toggledField.obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('submits form and displays success confirmation view', (
      tester,
    ) async {
      fakeRepository.response = const RegistrationResponse(
        outcome: 0,
        message: 'Check your email to verify.',
      );

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'customer@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'ValidPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name (optional)'),
        'Chris',
      );

      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Registration submitted'), findsOneWidget);
      expect(find.text('Check your email to verify.'), findsOneWidget);
      expect(
        find.text(
          'To protect account privacy, we do not disclose whether an email is already registered.',
        ),
        findsOneWidget,
      );
      expect(find.text('Return to sign in'), findsOneWidget);
    });

    testWidgets('displays error banner when repository throws failure', (
      tester,
    ) async {
      fakeRepository.error = const NetworkFailure();

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'customer@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'ValidPassword123!',
      );

      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    for (final width in [320.0, 360.0, 412.0, 768.0]) {
      testWidgets('remains scrollable at width $width and 200% text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(createTestWidget());
        await tester.ensureVisible(find.text('Create account').last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Create account'), findsNWidgets(2));
      });
    }
  });
}

final class _FakeAuthRepository extends AuthenticationRepository {
  _FakeAuthRepository() : super(_StubSessionStore());

  RegistrationResponse? response;
  Object? error;

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    if (error != null) {
      throw error!;
    }
    return response ??
        const RegistrationResponse(
          outcome: 0,
          message: 'Default success message',
        );
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

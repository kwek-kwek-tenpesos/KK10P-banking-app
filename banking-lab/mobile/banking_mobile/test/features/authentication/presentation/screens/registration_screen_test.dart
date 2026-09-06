import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        ],
        child: const MaterialApp(home: RegistrationScreen()),
      );
    }

    testWidgets('renders all registration form inputs and submit button', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Join KK10P Bank'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Display name (optional)'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitted empty', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
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

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final toggledField = tester.widget<TextField>(passwordFieldFinder);
      expect(toggledField.obscureText, isFalse);
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

      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pumpAndSettle();

      expect(find.text('Registration Submitted'), findsOneWidget);
      expect(find.text('Check your email to verify.'), findsOneWidget);
      expect(
        find.text(
          'To protect account privacy, we do not disclose whether an email is already registered.',
        ),
        findsOneWidget,
      );
      expect(find.text('Return to App'), findsOneWidget);
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

      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });
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

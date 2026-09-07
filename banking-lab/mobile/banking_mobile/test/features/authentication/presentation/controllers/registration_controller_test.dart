import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/registration_controller.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/registration_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationController', () {
    test(
      'rejects ASCII passwords of 12-14 characters before API submission',
      () async {
        for (final length in [12, 13, 14, 129]) {
          final repository = _MockAuthenticationRepository();
          final controller = RegistrationController(repository);
          addTearDown(controller.dispose);
          expect(
            await controller.register(
              email: 'user@example.test',
              password: 'A' * length,
            ),
            isFalse,
          );
          expect(repository.lastRequest, isNull);
          expect(controller.state.fieldErrors['password'], isNotNull);
        }
      },
    );

    test(
      'passes bounded Unicode unchanged for server NFC validation',
      () async {
        final repository = _MockAuthenticationRepository();
        final controller = RegistrationController(repository);
        addTearDown(controller.dispose);
        final decomposed = 'e\u0301' * 128;
        await controller.register(
          email: 'user@example.test',
          password: decomposed,
          displayName: '😀' * 60,
        );
        expect(repository.lastRequest?.password, decomposed);
        expect(repository.lastRequest?.displayName, '😀' * 60);
      },
    );

    test('displays server-normalized Unicode password failures', () async {
      final repository = _MockAuthenticationRepository()
        ..error = const ValidationFailure(
          'Check registration fields.',
          fieldErrors: {
            'password': ['Use at least 15 characters.'],
          },
        );
      final controller = RegistrationController(repository);
      addTearDown(controller.dispose);
      expect(
        await controller.register(
          email: 'user@example.test',
          password: '😀' * 14,
        ),
        isFalse,
      );
      expect(
        controller.state.fieldErrors['password'],
        'Use at least 15 characters.',
      );
    });

    test(
      'bounds raw Unicode input without a normalization dependency',
      () async {
        final repository = _MockAuthenticationRepository();
        final controller = RegistrationController(repository);
        addTearDown(controller.dispose);
        expect(
          await controller.register(
            email: 'user@example.test',
            password: '😀' * 513,
          ),
          isFalse,
        );
        expect(repository.lastRequest, isNull);
      },
    );

    late _MockAuthenticationRepository repository;
    late RegistrationController controller;

    setUp(() {
      repository = _MockAuthenticationRepository();
      controller = RegistrationController(repository);
    });

    test('initial state is idle with no errors', () {
      expect(controller.state.status, RegistrationStatus.idle);
      expect(controller.state.fieldErrors, isEmpty);
      expect(controller.state.generalErrorMessage, isNull);
      expect(controller.state.successMessage, isNull);
    });

    test('validates required and format for email', () async {
      final success = await controller.register(
        email: '',
        password: 'ValidPassword123!',
      );

      expect(success, isFalse);
      expect(controller.state.status, RegistrationStatus.failure);
      expect(controller.state.fieldErrors['email'], 'Email is required.');

      final invalidFormat = await controller.register(
        email: 'invalid-email',
        password: 'ValidPassword123!',
      );

      expect(invalidFormat, isFalse);
      expect(
        controller.state.fieldErrors['email'],
        'Enter a valid email address.',
      );
    });

    test('validates password minimum length of 15', () async {
      final success = await controller.register(
        email: 'user@example.test',
        password: 'short',
      );

      expect(success, isFalse);
      expect(controller.state.status, RegistrationStatus.failure);
      expect(
        controller.state.fieldErrors['password'],
        'Password must be at least 15 characters long.',
      );
    });

    test('validates display name max length of 60', () async {
      final longName = 'A' * 61;
      final success = await controller.register(
        email: 'user@example.test',
        password: 'ValidPassword123!',
        displayName: longName,
      );

      expect(success, isFalse);
      expect(controller.state.status, RegistrationStatus.failure);
      expect(
        controller.state.fieldErrors['displayName'],
        'Display name cannot exceed 60 characters.',
      );
    });

    test('transitions to success on successful registration', () async {
      repository.response = const RegistrationResponse(
        outcome: 0,
        message: 'Registration accepted.',
      );

      final success = await controller.register(
        email: 'customer@example.test',
        password: 'Correct Horse Battery Staple!',
        displayName: 'Chris',
      );

      expect(success, isTrue);
      expect(controller.state.status, RegistrationStatus.success);
      expect(controller.state.successMessage, 'Registration accepted.');
      expect(controller.state.fieldErrors, isEmpty);
      expect(repository.lastRequest?.email, 'customer@example.test');
      expect(repository.lastRequest?.displayName, 'Chris');
    });

    test('rapid repeated registration remains single flight', () async {
      final gate = Completer<RegistrationResponse>();
      repository.onRegister = (_) => gate.future;

      final first = controller.register(
        email: 'customer@example.test',
        password: 'Correct Horse Battery Staple!',
      );
      final duplicate = controller.register(
        email: 'customer@example.test',
        password: 'Correct Horse Battery Staple!',
      );

      expect(await duplicate, isFalse);
      expect(repository.calls, 1);
      expect(controller.state.status, RegistrationStatus.submitting);

      gate.complete(
        const RegistrationResponse(
          outcome: 0,
          message: 'Registration accepted.',
        ),
      );
      expect(await first, isTrue);
      expect(repository.calls, 1);
    });

    test('maps ValidationFailure to field errors and message', () async {
      repository.error = const ValidationFailure(
        'Validation failed.',
        fieldErrors: {
          'email': ['Email is already taken.'],
        },
      );

      final success = await controller.register(
        email: 'taken@example.test',
        password: 'ValidPassword123!',
      );

      expect(success, isFalse);
      expect(controller.state.status, RegistrationStatus.failure);
      expect(controller.state.fieldErrors['email'], 'Email is already taken.');
      expect(controller.state.generalErrorMessage, 'Validation failed.');
    });

    test('maps NetworkFailure to general error message', () async {
      repository.error = const NetworkFailure();

      final success = await controller.register(
        email: 'user@example.test',
        password: 'ValidPassword123!',
      );

      expect(success, isFalse);
      expect(controller.state.status, RegistrationStatus.failure);
      expect(controller.state.fieldErrors, isEmpty);
      expect(
        controller.state.generalErrorMessage,
        'Unable to reach the server. Check your connection and try again.',
      );
    });

    test('reset restores initial state', () async {
      repository.error = const NetworkFailure();
      await controller.register(
        email: 'user@example.test',
        password: 'ValidPassword123!',
      );
      expect(controller.state.isFailure, isTrue);

      controller.reset();
      expect(controller.state.status, RegistrationStatus.idle);
      expect(controller.state.fieldErrors, isEmpty);
      expect(controller.state.generalErrorMessage, isNull);
    });
  });
}

final class _MockAuthenticationRepository extends AuthenticationRepository {
  _MockAuthenticationRepository() : super(_StubSecureSessionStore());

  RegistrationResponse? response;
  Object? error;
  RegistrationRequest? lastRequest;
  Future<RegistrationResponse> Function(RegistrationRequest)? onRegister;
  int calls = 0;

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    calls++;
    lastRequest = request;
    final handler = onRegister;
    if (handler != null) return handler(request);
    if (error != null) {
      throw error!;
    }
    return response ??
        const RegistrationResponse(outcome: 0, message: 'Default success');
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

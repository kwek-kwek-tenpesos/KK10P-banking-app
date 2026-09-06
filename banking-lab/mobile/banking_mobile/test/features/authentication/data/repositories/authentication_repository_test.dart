import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/core/storage/secure_session_store_provider.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthenticationRepository', () {
    test(
      'propagates a storage read failure without clearing the token',
      () async {
        final storageError = Exception('Simulated storage read failure');

        final sessionStore = _FakeSecureSessionStore(
          refreshToken: 'fake-refresh-token',
          readError: storageError,
        );
        final repository = AuthenticationRepository(sessionStore);

        await expectLater(
          repository.hasStoredRefreshToken(),
          throwsA(same(storageError)),
        );

        expect(sessionStore.refreshToken, 'fake-refresh-token');
      },
    );

    test(
      'propagates a storage clear failure without reporting success',
      () async {
        final storageError = Exception('Simulated storage clear failure');

        final sessionStore = _FakeSecureSessionStore(
          refreshToken: 'fake-refresh-token',
          clearError: storageError,
        );
        final repository = AuthenticationRepository(sessionStore);

        await expectLater(
          repository.clearLocalSession(),
          throwsA(same(storageError)),
        );

        expect(sessionStore.refreshToken, 'fake-refresh-token');
      },
    );

    test('returns false when no refresh token is stored', () async {
      final sessionStore = _FakeSecureSessionStore();
      final repository = AuthenticationRepository(sessionStore);

      final hasStoredToken = await repository.hasStoredRefreshToken();

      expect(hasStoredToken, isFalse);
    });

    test('returns false when the stored refresh token is empty', () async {
      final sessionStore = _FakeSecureSessionStore(refreshToken: '');
      final repository = AuthenticationRepository(sessionStore);

      final hasStoredToken = await repository.hasStoredRefreshToken();

      expect(hasStoredToken, isFalse);
    });

    test('returns true when a refresh token is stored', () async {
      final sessionStore = _FakeSecureSessionStore(
        refreshToken: 'fake-refresh-token',
      );
      final repository = AuthenticationRepository(sessionStore);

      final hasStoredToken = await repository.hasStoredRefreshToken();

      expect(hasStoredToken, isTrue);
    });

    test('clears the local session', () async {
      final sessionStore = _FakeSecureSessionStore(
        refreshToken: 'fake-refresh-token',
      );
      final repository = AuthenticationRepository(sessionStore);

      await repository.clearLocalSession();

      expect(sessionStore.refreshToken, isNull);
    });

    test('provider uses the configured secure session store', () async {
      final sessionStore = _FakeSecureSessionStore(
        refreshToken: 'fake-refresh-token',
      );

      final container = ProviderContainer(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(sessionStore),
          authenticationApiServiceProvider.overrideWithValue(
            _FakeAuthenticationApiService(),
          ),
        ],
      );

      addTearDown(container.dispose);

      final repository = container.read(authenticationRepositoryProvider);

      final hasStoredToken = await repository.hasStoredRefreshToken();

      expect(hasStoredToken, isTrue);
    });

    test('register calls apiService and returns response', () async {
      final sessionStore = _FakeSecureSessionStore();
      final apiService = _FakeAuthenticationApiService(
        response: const RegistrationResponse(outcome: 0, message: 'Success'),
      );

      final repository = AuthenticationRepository(
        sessionStore,
        apiService: apiService,
      );

      final response = await repository.register(
        const RegistrationRequest(
          email: 'user@example.test',
          password: 'Password123!',
        ),
      );

      expect(response.outcome, 0);
      expect(response.message, 'Success');
      expect(apiService.lastRequest?.email, 'user@example.test');
    });

    test('register maps ApiError on exception', () async {
      final sessionStore = _FakeSecureSessionStore();
      final apiService = _FakeAuthenticationApiService(
        error: const FormatException('Bad data'),
      );

      final repository = AuthenticationRepository(
        sessionStore,
        apiService: apiService,
      );

      await expectLater(
        repository.register(
          const RegistrationRequest(
            email: 'user@example.test',
            password: 'Password123!',
          ),
        ),
        throwsA(isA<InvalidResponseFailure>()),
      );
    });

    test(
      'register throws StateError if apiService is not configured',
      () async {
        final sessionStore = _FakeSecureSessionStore();
        final repository = AuthenticationRepository(sessionStore);

        expect(
          () => repository.register(
            const RegistrationRequest(
              email: 'user@example.test',
              password: 'Password123!',
            ),
          ),
          throwsStateError,
        );
      },
    );
  });
}

final class _FakeAuthenticationApiService implements AuthenticationApiService {
  _FakeAuthenticationApiService({this.response, this.error});

  final RegistrationResponse? response;
  final Object? error;
  RegistrationRequest? lastRequest;

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    lastRequest = request;
    if (error != null) {
      throw error!;
    }
    return response!;
  }

  @override
  Future<void> confirmEmail({required String userId, required String token}) =>
      throw UnimplementedError();

  @override
  Future<AuthenticatedCustomer> getCurrentCustomer(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<AuthenticationTokens> login(LoginRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();

  @override
  Future<AuthenticationTokens> refresh(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<String> resendVerification(String email) => throw UnimplementedError();
}

final class _FakeSecureSessionStore implements SecureSessionStore {
  _FakeSecureSessionStore({this.refreshToken, this.readError, this.clearError});

  String? refreshToken;

  final Object? readError;
  final Object? clearError;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> readRefreshToken() async {
    final error = readError;

    if (error != null) {
      throw error;
    }

    return refreshToken;
  }

  @override
  Future<void> clearRefreshToken() async {
    final error = clearError;

    if (error != null) {
      throw error;
    }

    refreshToken = null;
  }
}

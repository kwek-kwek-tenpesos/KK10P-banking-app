import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/core/storage/secure_session_store_provider.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:banking_mobile/features/authentication/data/services/authentication_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthenticationRepository {
  AuthenticationRepository(this._secureSessionStore, {this._apiService});

  final SecureSessionStore _secureSessionStore;
  final AuthenticationApiService? _apiService;
  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  AuthenticatedCustomer? _customer;
  Future<AuthenticationSession>? _refreshInFlight;
  int _generation = 0;
  Future<void> _storageTail = Future<void>.value();

  int get sessionGeneration => _generation;

  void requireGeneration(int generation) {
    if (generation != _generation) throw const RequestCancelledFailure();
  }

  int _beginGeneration() {
    _generation++;
    _refreshInFlight = null;
    _clearMemorySession();
    return _generation;
  }

  // Serialize secure-storage access: an old write finishes before logout reads
  // and clears it, or a new login clears it and saves its own credentials.
  Future<T> _storage<T>(Future<T> Function() action) {
    final result = _storageTail.then((_) => action());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  AuthenticatedCustomer? get currentCustomer => _customer;

  Future<bool> hasStoredRefreshToken() async {
    final refreshToken = await _storage(_secureSessionStore.readRefreshToken);

    return refreshToken != null && refreshToken.isNotEmpty;
  }

  Future<void> clearLocalSession() {
    _beginGeneration();
    return _storage(_secureSessionStore.clearRefreshToken);
  }

  Future<RegistrationResponse> register(RegistrationRequest request) async {
    final api = _requireApiService();
    try {
      return await api.register(request);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }

  Future<AuthenticationSession> login({
    required String email,
    required String password,
  }) async {
    final api = _requireApiService();
    final generation = _beginGeneration();
    try {
      await _storage(_secureSessionStore.clearRefreshToken);
      requireGeneration(generation);
      final tokens = await api.login(
        LoginRequest(email: email, password: password),
      );
      return await _acceptTokens(tokens, generation);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }

  Future<AuthenticationSession?> restoreSession() async {
    final generation = _generation;
    final refreshToken = await _storage(_secureSessionStore.readRefreshToken);
    requireGeneration(generation);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      return await refreshSession();
    } on UnauthenticatedFailure {
      requireGeneration(generation);
      await clearLocalSession();
      return null;
    }
  }

  Future<AuthenticationSession> refreshSession() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    late final Future<AuthenticationSession> operation;
    operation = _refreshSessionCore().whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<String> getValidAccessToken() async {
    final token = _accessToken;
    final expiresAt = _accessTokenExpiresAt;
    final safeDeadline = DateTime.now().toUtc().add(
      const Duration(seconds: 15),
    );
    if (token != null && expiresAt != null && expiresAt.isAfter(safeDeadline)) {
      return token;
    }

    return (await refreshSession()).accessToken;
  }

  Future<void> confirmEmail({
    required String userId,
    required String token,
  }) async {
    final api = _requireApiService();
    try {
      await api.confirmEmail(userId: userId, token: token);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }

  Future<String> resendVerification(String email) async {
    final api = _requireApiService();
    try {
      return await api.resendVerification(email);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }

  Future<void> logout() async {
    final api = _requireApiService();
    _beginGeneration();
    String? refreshToken;
    try {
      refreshToken = await _storage(() async {
        String? token;
        try {
          token = await _secureSessionStore.readRefreshToken();
        } finally {
          await _secureSessionStore.clearRefreshToken();
        }
        return token;
      });
    } catch (_) {
      throw const SessionStorageFailure();
    }
    AppFailure? remoteFailure;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await api.logout(refreshToken);
      } on Object catch (error) {
        remoteFailure = mapApiError(error);
      }
    }

    if (remoteFailure != null) throw remoteFailure;
  }

  Future<AuthenticationSession> _refreshSessionCore() async {
    final api = _requireApiService();
    final generation = _generation;
    final refreshToken = await _storage(_secureSessionStore.readRefreshToken);
    requireGeneration(generation);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const UnauthenticatedFailure();
    }

    try {
      final tokens = await api.refresh(refreshToken);
      return await _acceptTokens(tokens, generation);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapApiError(error), stackTrace);
    }
  }

  Future<AuthenticationSession> _acceptTokens(
    AuthenticationTokens tokens,
    int generation,
  ) async {
    final api = _requireApiService();
    requireGeneration(generation);
    try {
      await _storage(() async {
        requireGeneration(generation);
        await _secureSessionStore.saveRefreshToken(tokens.refreshToken);
        if (generation != _generation) {
          // The queued generation change owns cleanup. In particular, logout
          // must read this latest rotated token so it can revoke the family.
          throw const RequestCancelledFailure();
        }
      });
    } on RequestCancelledFailure {
      rethrow;
    } catch (_) {
      try {
        await api.logout(tokens.refreshToken);
      } catch (_) {
        // Best effort: server-side expiry still limits the uncertain session.
      }
      if (generation == _generation) _clearMemorySession();
      throw const SessionStorageFailure();
    }

    final expiresAt = DateTime.now().toUtc().add(
      Duration(seconds: tokens.expiresInSeconds),
    );

    try {
      final customer = await api.getCurrentCustomer(tokens.accessToken);
      requireGeneration(generation);
      _customer = customer;
      _accessToken = tokens.accessToken;
      _accessTokenExpiresAt = expiresAt;
    } on Object catch (error, stackTrace) {
      requireGeneration(generation);
      final failure = mapApiError(error);
      if (failure is UnauthenticatedFailure) {
        try {
          await _storage(() async {
            requireGeneration(generation);
            await _secureSessionStore.clearRefreshToken();
          });
        } catch (_) {
          requireGeneration(generation);
          _clearMemorySession();
          throw const SessionStorageFailure();
        }
        requireGeneration(generation);
        _clearMemorySession();
      }
      Error.throwWithStackTrace(failure, stackTrace);
    }

    return AuthenticationSession(
      customer: _customer!,
      accessToken: tokens.accessToken,
      accessTokenExpiresAt: _accessTokenExpiresAt!,
    );
  }

  AuthenticationApiService _requireApiService() {
    final api = _apiService;
    if (api == null) {
      throw StateError('AuthenticationApiService is not configured.');
    }
    return api;
  }

  void _clearMemorySession() {
    _accessToken = null;
    _accessTokenExpiresAt = null;
    _customer = null;
  }
}

final authenticationRepositoryProvider = Provider<AuthenticationRepository>((
  ref,
) {
  final secureSessionStore = ref.watch(secureSessionStoreProvider);
  final apiService = ref.watch(authenticationApiServiceProvider);

  return AuthenticationRepository(secureSessionStore, apiService: apiService);
});

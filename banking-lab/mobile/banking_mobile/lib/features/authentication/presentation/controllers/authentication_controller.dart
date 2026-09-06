import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthenticationStatus { initializing, signedOut, submitting, signedIn }

class AuthenticationState {
  const AuthenticationState({
    required this.status,
    this.customer,
    this.errorMessage,
    this.canRetryRestore = false,
  });

  const AuthenticationState.initializing()
    : this(status: AuthenticationStatus.initializing);

  final AuthenticationStatus status;
  final AuthenticatedCustomer? customer;
  final String? errorMessage;
  final bool canRetryRestore;

  bool get isAuthenticated => customer != null;
  bool get isSubmitting => status == AuthenticationStatus.submitting;
}

class AuthenticationController extends StateNotifier<AuthenticationState> {
  AuthenticationController(this._repository)
    : super(const AuthenticationState.initializing()) {
    unawaited(initialize());
  }

  final AuthenticationRepository _repository;
  Future<void>? _initialization;
  int _operation = 0;

  Future<void> initialize() {
    return _initialization ??= _restore().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _restore() async {
    final operation = ++_operation;
    state = const AuthenticationState.initializing();
    try {
      final session = await _repository.restoreSession();
      if (!mounted || operation != _operation) return;
      state = session == null
          ? const AuthenticationState(status: AuthenticationStatus.signedOut)
          : AuthenticationState(
              status: AuthenticationStatus.signedIn,
              customer: session.customer,
            );
    } on AppFailure catch (failure) {
      if (!mounted || operation != _operation) return;
      state = AuthenticationState(
        status: AuthenticationStatus.signedOut,
        errorMessage: failure.message,
        canRetryRestore: true,
      );
    } catch (_) {
      if (!mounted || operation != _operation) return;
      state = const AuthenticationState(
        status: AuthenticationStatus.signedOut,
        errorMessage: 'The saved session could not be restored. Please retry.',
        canRetryRestore: true,
      );
    }
  }

  Future<bool> login({required String email, required String password}) async {
    if (state.isSubmitting) return false;
    final operation = ++_operation;
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      state = const AuthenticationState(
        status: AuthenticationStatus.signedOut,
        errorMessage: 'Enter your email address and password.',
      );
      return false;
    }

    state = const AuthenticationState(status: AuthenticationStatus.submitting);
    try {
      final session = await _repository.login(
        email: trimmedEmail,
        password: password,
      );
      if (!mounted || operation != _operation) return false;
      state = AuthenticationState(
        status: AuthenticationStatus.signedIn,
        customer: session.customer,
      );
      return true;
    } on AppFailure catch (failure) {
      if (!mounted || operation != _operation) return false;
      state = AuthenticationState(
        status: AuthenticationStatus.signedOut,
        errorMessage: failure.message,
      );
      return false;
    } catch (_) {
      if (!mounted || operation != _operation) return false;
      state = const AuthenticationState(
        status: AuthenticationStatus.signedOut,
        errorMessage: 'Sign-in could not be completed. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    if (state.isSubmitting) return;
    final operation = ++_operation;
    state = AuthenticationState(status: AuthenticationStatus.submitting);

    String? warning;
    try {
      await _repository.logout();
    } on SessionStorageFailure {
      warning = 'Secure session storage could not be cleared. Server logout is unconfirmed. Please retry sign-in.';
    } on AppFailure catch (failure) {
      warning = '${failure.message} Local credentials were removed.';
    } catch (_) {
      warning = 'Server logout could not be confirmed. Local credentials were removed.';
    }

    if (!mounted || operation != _operation) return;
    state = AuthenticationState(
      status: AuthenticationStatus.signedOut,
      errorMessage: warning,
    );
  }

  Future<void> invalidateSession(int generation) async {
    if (_repository.sessionGeneration != generation) return;
    final operation = ++_operation;
    state = const AuthenticationState(
      status: AuthenticationStatus.signedOut,
      errorMessage: 'Your session is no longer valid. Please sign in again.',
    );
    try {
      await _repository.clearLocalSession();
    } catch (_) {
      if (!mounted || operation != _operation) return;
      state = const AuthenticationState(
        status: AuthenticationStatus.signedOut,
        errorMessage: 'Secure session storage could not be cleared. Please retry sign-in.',
      );
    }
  }
}

final authenticationControllerProvider =
    StateNotifierProvider<AuthenticationController, AuthenticationState>((ref) {
      return AuthenticationController(
        ref.watch(authenticationRepositoryProvider),
      );
    });

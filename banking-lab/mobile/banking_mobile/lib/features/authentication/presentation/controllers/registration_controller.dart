import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/registration_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegistrationController extends StateNotifier<RegistrationState> {
  RegistrationController(this._repository) : super(const RegistrationState());

  final AuthenticationRepository _repository;

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (state.isSubmitting) return false;
    final trimmedEmail = email.trim();
    final trimmedDisplayName = displayName?.trim();

    final fieldErrors = <String, String>{};

    if (trimmedEmail.isEmpty) {
      fieldErrors['email'] = 'Email is required.';
    } else if (trimmedEmail.length > 254 ||
        !_emailRegExp.hasMatch(trimmedEmail)) {
      fieldErrors['email'] = 'Enter a valid email address.';
    }

    if (password.isEmpty) {
      fieldErrors['password'] = 'Password is required.';
    } else if (password.codeUnits.every((unit) => unit <= 0x7f)) {
      // ASCII is already NFC. The server owns normalization for other Unicode
      // input; raw UTF-16/rune length cannot predict its normalized length.
      if (password.length < 15) {
        fieldErrors['password'] =
            'Password must be at least 15 characters long.';
      } else if (password.length > 128) {
        fieldErrors['password'] = 'Password cannot exceed 128 characters.';
      }
    } else if (password.runes.length > 512) {
      fieldErrors['password'] =
          'Password input is too long. Use 15–128 characters.';
    }

    if (trimmedDisplayName != null && trimmedDisplayName.runes.length > 60) {
      fieldErrors['displayName'] = 'Display name cannot exceed 60 characters.';
    }

    if (fieldErrors.isNotEmpty) {
      state = state.copyWith(
        status: RegistrationStatus.failure,
        fieldErrors: fieldErrors,
        generalErrorMessage: null,
      );
      return false;
    }

    state = state.copyWith(
      status: RegistrationStatus.submitting,
      fieldErrors: const {},
      generalErrorMessage: null,
    );

    try {
      final response = await _repository.register(
        RegistrationRequest(
          email: trimmedEmail,
          password: password,
          displayName: trimmedDisplayName,
        ),
      );

      state = state.copyWith(
        status: RegistrationStatus.success,
        successMessage: response.message,
        fieldErrors: const {},
        generalErrorMessage: null,
      );
      return true;
    } on ValidationFailure catch (failure) {
      final flattenedErrors = <String, String>{};
      for (final entry in failure.fieldErrors.entries) {
        if (entry.value.isNotEmpty) {
          flattenedErrors[entry.key] = entry.value.first;
        }
      }

      state = state.copyWith(
        status: RegistrationStatus.failure,
        fieldErrors: flattenedErrors,
        generalErrorMessage: failure.message,
      );
      return false;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: RegistrationStatus.failure,
        generalErrorMessage: failure.message,
        fieldErrors: const {},
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: RegistrationStatus.failure,
        generalErrorMessage: 'An unexpected error occurred. Please try again.',
        fieldErrors: const {},
      );
      return false;
    }
  }

  void reset() {
    state = const RegistrationState();
  }
}

final registrationControllerProvider =
    StateNotifierProvider<RegistrationController, RegistrationState>((ref) {
      final repository = ref.watch(authenticationRepositoryProvider);
      return RegistrationController(repository);
    });

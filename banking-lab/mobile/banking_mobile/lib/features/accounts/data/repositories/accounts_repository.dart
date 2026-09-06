import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/data/services/accounts_api_service.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsRepository {
  AccountsRepository(this._api, this._authentication);
  final AccountsApiService _api;
  final AuthenticationRepository _authentication;

  Future<AccountSummary?> read() => _authorized(_api.read);
  Future<AccountSummary> open() => _authorized(_api.open);

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final generation = _authentication.sessionGeneration;
    final token = await _authentication.getValidAccessToken();
    _authentication.requireGeneration(generation);
    try {
      final result = await request(token);
      _authentication.requireGeneration(generation);
      return result;
    } on UnauthenticatedFailure {
      _authentication.requireGeneration(generation);
      final renewed = await _authentication.refreshSession();
      _authentication.requireGeneration(generation);
      final result = await request(renewed.accessToken);
      _authentication.requireGeneration(generation);
      return result;
    }
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(
    ref.watch(accountsApiServiceProvider),
    ref.watch(authenticationRepositoryProvider),
  ),
);

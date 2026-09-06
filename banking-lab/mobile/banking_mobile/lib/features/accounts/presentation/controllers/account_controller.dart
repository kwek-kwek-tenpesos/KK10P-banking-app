import 'dart:async';

import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/data/repositories/accounts_repository.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AccountStatus { loading, unopened, opening, loaded, error }

class AccountState {
  const AccountState(this.status, {this.account, this.message});
  final AccountStatus status;
  final AccountSummary? account;
  final String? message;
  bool get busy =>
      status == AccountStatus.loading || status == AccountStatus.opening;
}

class AccountController extends StateNotifier<AccountState> {
  AccountController(this._repository, this._isCurrent, this._invalidate)
    : super(const AccountState(AccountStatus.loading)) {
    unawaited(load());
  }
  final AccountsRepository _repository;
  final bool Function() _isCurrent;
  final Future<void> Function() _invalidate;
  bool _pending = false;
  bool _openingUncertain = false;

  Future<void> load() => _run(open: false);
  Future<void> open() async {
    if (state.status != AccountStatus.unopened) return;
    await _run(open: true);
  }

  Future<void> retry() =>
      _run(open: _openingUncertain, reconcile: _openingUncertain);

  Future<void> _run({required bool open, bool reconcile = false}) async {
    if (_pending || !mounted || !_isCurrent()) return;
    _pending = true;
    state = AccountState(open ? AccountStatus.opening : AccountStatus.loading);
    try {
      AccountSummary? result;
      if (reconcile) result = await _repository.read();
      if (!mounted || !_isCurrent()) return;
      result ??= open ? await _repository.open() : await _repository.read();
      if (!mounted || !_isCurrent()) return;
      _openingUncertain = false;
      state = AccountState(
        result == null ? AccountStatus.unopened : AccountStatus.loaded,
        account: result,
      );
    } on UnauthenticatedFailure {
      if (mounted && _isCurrent()) await _invalidate();
    } catch (error) {
      if (!mounted || !_isCurrent()) return;
      final failure = mapApiError(error);
      _openingUncertain = open;
      state = AccountState(
        AccountStatus.error,
        message: open
            ? '${failure.message} Account opening is unconfirmed. Retry to check its status.'
            : failure.message,
      );
    } finally {
      _pending = false;
    }
  }
}

final accountControllerProvider =
    StateNotifierProvider.autoDispose<AccountController, AccountState>((ref) {
      final customer = ref.watch(
        authenticationControllerProvider.select((state) => state.customer),
      );
      final authentication = ref.watch(authenticationRepositoryProvider);
      final generation = authentication.sessionGeneration;
      return AccountController(
        ref.watch(accountsRepositoryProvider),
        () =>
            customer != null &&
            authentication.sessionGeneration == generation &&
            ref.read(authenticationControllerProvider).customer?.id ==
                customer.id,
        () => ref
            .read(authenticationControllerProvider.notifier)
            .invalidateSession(generation),
      );
    });

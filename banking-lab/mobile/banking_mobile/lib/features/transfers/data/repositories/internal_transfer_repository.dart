import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/transfers/data/models/internal_transfer_receipt.dart';
import 'package:banking_mobile/features/transfers/data/models/pending_internal_transfer.dart';
import 'package:banking_mobile/features/transfers/data/services/internal_transfer_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InternalTransferRepository {
  InternalTransferRepository(this._api, this._authentication);

  final InternalTransferApiService _api;
  final AuthenticationRepository _authentication;

  Future<InternalTransferReceipt> transfer(
    PendingInternalTransfer pending,
  ) async {
    final generation = _authentication.sessionGeneration;
    final token = await _authentication.getValidAccessToken();
    _authentication.requireGeneration(generation);
    try {
      final receipt = await _send(token, pending);
      _authentication.requireGeneration(generation);
      return receipt;
    } on UnauthenticatedFailure {
      _authentication.requireGeneration(generation);
      final renewed = await _authentication.refreshSession();
      _authentication.requireGeneration(generation);
      final receipt = await _send(renewed.accessToken, pending);
      _authentication.requireGeneration(generation);
      return receipt;
    }
  }

  Future<InternalTransferReceipt> _send(
    String token,
    PendingInternalTransfer pending,
  ) => _api.transfer(
    token: token,
    idempotencyKey: pending.idempotencyKey,
    destinationAccountReference: pending.destinationAccountReference,
    amountMinor: pending.amountMinor,
  );
}

final internalTransferRepositoryProvider = Provider<InternalTransferRepository>(
  (ref) => InternalTransferRepository(
    ref.watch(internalTransferApiServiceProvider),
    ref.watch(authenticationRepositoryProvider),
  ),
);

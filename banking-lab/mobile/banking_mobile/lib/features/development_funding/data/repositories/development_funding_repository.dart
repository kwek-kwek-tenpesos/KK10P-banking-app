import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/development_funding/data/models/development_funding_receipt.dart';
import 'package:banking_mobile/features/development_funding/data/services/development_funding_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevelopmentFundingRepository {
  DevelopmentFundingRepository(this._api, this._authentication);
  final DevelopmentFundingApiService _api;
  final AuthenticationRepository _authentication;

  Future<DevelopmentFundingReceipt> fund(String idempotencyKey) async {
    final generation = _authentication.sessionGeneration;
    final token = await _authentication.getValidAccessToken();
    _authentication.requireGeneration(generation);
    try {
      final receipt = await _api.fund(
        token: token,
        idempotencyKey: idempotencyKey,
      );
      _authentication.requireGeneration(generation);
      return receipt;
    } on UnauthenticatedFailure {
      _authentication.requireGeneration(generation);
      final renewed = await _authentication.refreshSession();
      _authentication.requireGeneration(generation);
      final receipt = await _api.fund(
        token: renewed.accessToken,
        idempotencyKey: idempotencyKey,
      );
      _authentication.requireGeneration(generation);
      return receipt;
    }
  }
}

final developmentFundingRepositoryProvider =
    Provider<DevelopmentFundingRepository>(
      (ref) => DevelopmentFundingRepository(
        ref.watch(developmentFundingApiServiceProvider),
        ref.watch(authenticationRepositoryProvider),
      ),
    );

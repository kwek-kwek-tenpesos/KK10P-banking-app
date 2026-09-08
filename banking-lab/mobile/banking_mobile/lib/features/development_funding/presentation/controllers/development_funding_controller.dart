import 'dart:math';

import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/development_funding/data/models/development_funding_receipt.dart';
import 'package:banking_mobile/features/development_funding/data/repositories/development_funding_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DevelopmentFundingStatus { idle, submitting, success, error }

class DevelopmentFundingState {
  const DevelopmentFundingState(
    this.status, {
    this.receipt,
    this.message,
    this.canRetrySameRequest = false,
  });
  final DevelopmentFundingStatus status;
  final DevelopmentFundingReceipt? receipt;
  final String? message;
  final bool canRetrySameRequest;
  bool get busy => status == DevelopmentFundingStatus.submitting;
}

class DevelopmentFundingController
    extends StateNotifier<DevelopmentFundingState> {
  DevelopmentFundingController(
    this._repository,
    this._isCurrent,
    this._invalidateSession,
    this._refreshAccount,
  ) : super(const DevelopmentFundingState(DevelopmentFundingStatus.idle));

  final DevelopmentFundingRepository _repository;
  final bool Function() _isCurrent;
  final Future<void> Function() _invalidateSession;
  final void Function() _refreshAccount;
  String? _pendingKey;

  Future<void> fund() async {
    if (state.busy || !mounted || !_isCurrent()) return;
    _pendingKey ??= _newUuid();
    state = const DevelopmentFundingState(DevelopmentFundingStatus.submitting);
    try {
      final receipt = await _repository.fund(_pendingKey!);
      if (!mounted || !_isCurrent()) return;
      _pendingKey = null;
      state = DevelopmentFundingState(
        DevelopmentFundingStatus.success,
        receipt: receipt,
      );
      _refreshAccount();
    } on UnauthenticatedFailure {
      _pendingKey = null;
      if (mounted && _isCurrent()) await _invalidateSession();
    } catch (error) {
      if (!mounted || !_isCurrent()) return;
      final failure = mapApiError(error);
      final uncertain =
          failure is NetworkFailure ||
          failure is TimeoutFailure ||
          failure is ServerFailure ||
          failure is UnexpectedFailure ||
          failure is InvalidResponseFailure;
      if (!uncertain) _pendingKey = null;
      state = DevelopmentFundingState(
        DevelopmentFundingStatus.error,
        message: failure.message,
        canRetrySameRequest: uncertain,
      );
    }
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

final developmentFundingControllerProvider =
    StateNotifierProvider.autoDispose<
      DevelopmentFundingController,
      DevelopmentFundingState
    >((ref) {
      final customer = ref.watch(
        authenticationControllerProvider.select((state) => state.customer),
      );
      final authentication = ref.watch(authenticationRepositoryProvider);
      final generation = authentication.sessionGeneration;
      return DevelopmentFundingController(
        ref.watch(developmentFundingRepositoryProvider),
        () =>
            customer != null &&
            authentication.sessionGeneration == generation &&
            ref.read(authenticationControllerProvider).customer?.id ==
                customer.id,
        () => ref
            .read(authenticationControllerProvider.notifier)
            .invalidateSession(generation),
        () => ref.invalidate(accountControllerProvider),
      );
    });

import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_controller.dart';
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
    this._refreshActivity,
  ) : super(const DevelopmentFundingState(DevelopmentFundingStatus.idle));

  final DevelopmentFundingRepository _repository;
  final bool Function() _isCurrent;
  final Future<void> Function() _invalidateSession;
  final void Function() _refreshAccount;
  final void Function() _refreshActivity;
  String? _pendingKey;

  Future<void> fund() async {
    if (state.busy || !mounted || !_isCurrent()) return;
    _pendingKey ??= newSecureUuidV4();
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
      _refreshActivity();
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
        () => ref.invalidate(activityControllerProvider),
      );
    });

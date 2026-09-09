import 'dart:async';

import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/transfers/data/models/internal_transfer_receipt.dart';
import 'package:banking_mobile/features/transfers/data/models/pending_internal_transfer.dart';
import 'package:banking_mobile/features/transfers/data/repositories/internal_transfer_repository.dart';
import 'package:banking_mobile/features/transfers/data/storage/pending_internal_transfer_store.dart';
import 'package:banking_mobile/features/transfers/domain/internal_transfer_amount.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum InternalTransferStep { recipient, amount, review }

enum InternalTransferStatus {
  restoring,
  editing,
  persisting,
  submitting,
  retryableRejected,
  uncertain,
  definitiveFailure,
  success,
  storageFailure,
}

enum InternalTransferStorageAction {
  retrySave,
  retryClear,
  retryResolution,
  blockedCorrupt,
}

class InternalTransferState {
  const InternalTransferState({
    this.status = InternalTransferStatus.restoring,
    this.step = InternalTransferStep.recipient,
    this.recipientInput = '',
    this.amountInput = '',
    this.recipientError,
    this.amountError,
    this.message,
    this.requestId,
    this.pending,
    this.receipt,
    this.retryAfterSeconds,
    this.storageAction,
  });

  final InternalTransferStatus status;
  final InternalTransferStep step;
  final String recipientInput;
  final String amountInput;
  final String? recipientError;
  final String? amountError;
  final String? message;
  final String? requestId;
  final PendingInternalTransfer? pending;
  final InternalTransferReceipt? receipt;
  final int? retryAfterSeconds;
  final InternalTransferStorageAction? storageAction;

  bool get busy =>
      status == InternalTransferStatus.restoring ||
      status == InternalTransferStatus.persisting ||
      status == InternalTransferStatus.submitting;

  bool get canEdit =>
      status == InternalTransferStatus.editing ||
      status == InternalTransferStatus.definitiveFailure;

  InternalTransferState copyWith({
    InternalTransferStatus? status,
    InternalTransferStep? step,
    String? recipientInput,
    String? amountInput,
    Object? recipientError = _unset,
    Object? amountError = _unset,
    Object? message = _unset,
    Object? requestId = _unset,
    Object? pending = _unset,
    Object? receipt = _unset,
    Object? retryAfterSeconds = _unset,
    Object? storageAction = _unset,
  }) => InternalTransferState(
    status: status ?? this.status,
    step: step ?? this.step,
    recipientInput: recipientInput ?? this.recipientInput,
    amountInput: amountInput ?? this.amountInput,
    recipientError: identical(recipientError, _unset)
        ? this.recipientError
        : recipientError as String?,
    amountError: identical(amountError, _unset)
        ? this.amountError
        : amountError as String?,
    message: identical(message, _unset) ? this.message : message as String?,
    requestId: identical(requestId, _unset)
        ? this.requestId
        : requestId as String?,
    pending: identical(pending, _unset)
        ? this.pending
        : pending as PendingInternalTransfer?,
    receipt: identical(receipt, _unset)
        ? this.receipt
        : receipt as InternalTransferReceipt?,
    retryAfterSeconds: identical(retryAfterSeconds, _unset)
        ? this.retryAfterSeconds
        : retryAfterSeconds as int?,
    storageAction: identical(storageAction, _unset)
        ? this.storageAction
        : storageAction as InternalTransferStorageAction?,
  );
}

const Object _unset = Object();

class InternalTransferController extends StateNotifier<InternalTransferState> {
  InternalTransferController(
    this._repository,
    this._store,
    this._customerId,
    this._isCurrent,
    this._invalidateSession,
    this._refreshAccount, {
    String Function()? newId,
    DateTime Function()? now,
  }) : _newId = newId ?? newSecureUuidV4,
       _now = now ?? DateTime.now,
       super(const InternalTransferState()) {
    unawaited(_restore());
  }

  final InternalTransferRepository _repository;
  final PendingInternalTransferStore _store;
  final String _customerId;
  final bool Function() _isCurrent;
  final Future<void> Function() _invalidateSession;
  final void Function() _refreshAccount;
  final String Function() _newId;
  final DateTime Function() _now;
  bool _operationInFlight = false;

  Future<void> _restore() async {
    try {
      final pending = await _store.read(_customerId);
      if (!mounted || !_isCurrent()) return;
      if (pending == null) {
        state = const InternalTransferState(
          status: InternalTransferStatus.editing,
        );
        return;
      }
      state = InternalTransferState(
        status: InternalTransferStatus.uncertain,
        step: InternalTransferStep.review,
        recipientInput: pending.destinationAccountReference,
        amountInput: _editableAmount(pending.amountMinor),
        message: 'A previous transfer needs confirmation before you can start another one.',
        pending: pending,
      );
    } on PendingTransferStorageFailure catch (failure) {
      if (!mounted || !_isCurrent()) return;
      state = InternalTransferState(
        status: InternalTransferStatus.storageFailure,
        message: failure.message,
        storageAction: failure.corrupt
            ? InternalTransferStorageAction.blockedCorrupt
            : InternalTransferStorageAction.retryResolution,
      );
    }
  }

  void updateRecipient(String value) {
    if (!state.canEdit) return;
    state = state.copyWith(
      status: InternalTransferStatus.editing,
      recipientInput: value,
      recipientError: null,
      message: null,
      requestId: null,
    );
  }

  void updateAmount(String value) {
    if (!state.canEdit) return;
    state = state.copyWith(
      status: InternalTransferStatus.editing,
      amountInput: value,
      amountError: null,
      message: null,
      requestId: null,
    );
  }

  bool continueFromRecipient(String sourceAccountReference) {
    if (!state.canEdit) return false;
    final normalized = normalizeCanonicalUuid(state.recipientInput);
    final source = normalizeCanonicalUuid(sourceAccountReference);
    final error = normalized == null
        ? 'Enter a valid simulator account reference.'
        : normalized == source
        ? 'Choose another simulator account.'
        : null;
    if (error != null) {
      state = state.copyWith(recipientError: error, message: null);
      return false;
    }
    state = state.copyWith(
      status: InternalTransferStatus.editing,
      step: InternalTransferStep.amount,
      recipientInput: normalized,
      recipientError: null,
      message: null,
    );
    return true;
  }

  bool continueFromAmount(BigInt availableMinor) {
    if (!state.canEdit) return false;
    final error = InternalTransferAmount.validate(
      state.amountInput,
      availableMinor: availableMinor,
    );
    if (error != null) {
      state = state.copyWith(amountError: error, message: null);
      return false;
    }
    state = state.copyWith(
      status: InternalTransferStatus.editing,
      step: InternalTransferStep.review,
      amountError: null,
      message: null,
    );
    return true;
  }

  void goBack() {
    if (!state.canEdit) return;
    state = state.copyWith(
      status: InternalTransferStatus.editing,
      step: switch (state.step) {
        InternalTransferStep.recipient => InternalTransferStep.recipient,
        InternalTransferStep.amount => InternalTransferStep.recipient,
        InternalTransferStep.review => InternalTransferStep.amount,
      },
      message: null,
      requestId: null,
    );
  }

  Future<void> submit({
    required String sourceAccountReference,
    required BigInt availableMinor,
  }) async {
    if (_operationInFlight || !state.canEdit || !_isCurrent()) return;
    if (!continueFromRecipient(sourceAccountReference)) return;
    if (!continueFromAmount(availableMinor)) return;
    final amount = InternalTransferAmount.tryParse(state.amountInput)!;
    final pending = PendingInternalTransfer(
      customerId: _customerId,
      idempotencyKey: _newId(),
      destinationAccountReference: state.recipientInput,
      amountMinor: amount.minor,
      createdAtUtc: _now().toUtc(),
    );
    await _persistAndSend(pending);
  }

  Future<void> _persistAndSend(PendingInternalTransfer pending) async {
    if (_operationInFlight || !_isCurrent()) return;
    _operationInFlight = true;
    state = state.copyWith(
      status: InternalTransferStatus.persisting,
      pending: pending,
      message: null,
      requestId: null,
      storageAction: null,
    );
    try {
      await _store.save(pending);
    } on PendingTransferStorageFailure catch (failure) {
      if (mounted && _isCurrent()) {
        state = state.copyWith(
          status: InternalTransferStatus.storageFailure,
          message: '${failure.message} Nothing was sent.',
          pending: pending,
          storageAction: InternalTransferStorageAction.retrySave,
        );
      }
      _operationInFlight = false;
      return;
    }
    _operationInFlight = false;
    await _send(pending);
  }

  Future<void> _send(PendingInternalTransfer pending) async {
    if (_operationInFlight || !_isCurrent()) return;
    _operationInFlight = true;
    state = state.copyWith(
      status: InternalTransferStatus.submitting,
      pending: pending,
      message: null,
      requestId: null,
      retryAfterSeconds: null,
      storageAction: null,
    );
    try {
      final receipt = await _repository.transfer(pending);
      if (!mounted || !_isCurrent()) return;
      _refreshAccount();
      await _clearAfterSuccess(pending, receipt);
    } on UnauthenticatedFailure {
      if (mounted && _isCurrent()) {
        state = state.copyWith(
          status: InternalTransferStatus.uncertain,
          message: 'Your session ended before the transfer result could be confirmed. Sign in again to check it safely.',
          pending: pending,
        );
        await _invalidateSession();
      }
    } catch (error) {
      if (!mounted || !_isCurrent()) return;
      final failure = mapApiError(error);
      if (failure is RateLimitedFailure) {
        state = state.copyWith(
          status: InternalTransferStatus.retryableRejected,
          message: failure.message,
          requestId: failure.requestId,
          retryAfterSeconds: failure.retryAfterSeconds,
          pending: pending,
        );
      } else if (_isUncertain(failure)) {
        state = state.copyWith(
          status: InternalTransferStatus.uncertain,
          message: 'The server result could not be confirmed. The transfer may already have completed.',
          requestId: failure.requestId,
          pending: pending,
        );
      } else {
        await _resolveDefinitive(pending, failure);
      }
    } finally {
      _operationInFlight = false;
    }
  }

  Future<void> _clearAfterSuccess(
    PendingInternalTransfer pending,
    InternalTransferReceipt receipt,
  ) async {
    try {
      await _store.clear(_customerId);
      if (!mounted || !_isCurrent()) return;
      state = state.copyWith(
        status: InternalTransferStatus.success,
        pending: null,
        receipt: receipt,
        message: null,
        requestId: null,
      );
    } on PendingTransferStorageFailure catch (failure) {
      if (!mounted || !_isCurrent()) return;
      state = state.copyWith(
        status: InternalTransferStatus.storageFailure,
        pending: pending,
        receipt: receipt,
        message:
            '${failure.message} The transfer itself was confirmed and will not be sent again.',
        storageAction: InternalTransferStorageAction.retryClear,
      );
    }
  }

  Future<void> _resolveDefinitive(
    PendingInternalTransfer pending,
    AppFailure failure,
  ) async {
    try {
      await _store.clear(_customerId);
    } on PendingTransferStorageFailure catch (storageFailure) {
      if (!mounted || !_isCurrent()) return;
      state = state.copyWith(
        status: InternalTransferStatus.storageFailure,
        pending: pending,
        message:
            '${storageFailure.message} Check the request again before starting another transfer.',
        requestId: failure.requestId,
        storageAction: InternalTransferStorageAction.retryResolution,
      );
      return;
    }
    if (!mounted || !_isCurrent()) return;
    if (failure is TransferInsufficientFundsFailure ||
        failure is TransferAccountRequiredFailure) {
      _refreshAccount();
    }
    final target =
        failure is TransferRecipientNotFoundFailure ||
            failure is TransferSelfNotAllowedFailure
        ? InternalTransferStep.recipient
        : failure is TransferInsufficientFundsFailure ||
              failure is TransferDailyLimitFailure
        ? InternalTransferStep.amount
        : InternalTransferStep.review;
    state = state.copyWith(
      status: InternalTransferStatus.definitiveFailure,
      step: target,
      pending: null,
      message: failure.message,
      requestId: failure.requestId,
      recipientError: target == InternalTransferStep.recipient
          ? failure.message
          : null,
      amountError: target == InternalTransferStep.amount
          ? failure.message
          : null,
    );
  }

  Future<void> retryPending() async {
    if (_operationInFlight) return;
    final pending = state.pending;
    if (pending == null) return;
    await _send(pending);
  }

  Future<void> cancelRateLimited() async {
    if (_operationInFlight ||
        state.status != InternalTransferStatus.retryableRejected) {
      return;
    }
    final pending = state.pending;
    if (pending == null) return;
    _operationInFlight = true;
    try {
      await _store.clear(_customerId);
      if (!mounted || !_isCurrent()) return;
      state = state.copyWith(
        status: InternalTransferStatus.editing,
        step: InternalTransferStep.review,
        pending: null,
        message: null,
        requestId: null,
        retryAfterSeconds: null,
      );
    } on PendingTransferStorageFailure catch (failure) {
      if (!mounted || !_isCurrent()) return;
      state = state.copyWith(
        status: InternalTransferStatus.storageFailure,
        message: failure.message,
        storageAction: InternalTransferStorageAction.retryResolution,
      );
    } finally {
      _operationInFlight = false;
    }
  }

  Future<void> retryStorageAction() async {
    if (_operationInFlight) return;
    if (state.storageAction == InternalTransferStorageAction.retrySave) {
      final pending = state.pending;
      if (pending != null) await _persistAndSend(pending);
      return;
    }
    if (state.storageAction == InternalTransferStorageAction.retryClear) {
      final receipt = state.receipt;
      if (receipt == null) return;
      _operationInFlight = true;
      try {
        await _store.clear(_customerId);
        if (!mounted || !_isCurrent()) return;
        state = state.copyWith(
          status: InternalTransferStatus.success,
          pending: null,
          receipt: receipt,
          message: null,
          storageAction: null,
        );
      } on PendingTransferStorageFailure catch (failure) {
        if (mounted && _isCurrent()) {
          state = state.copyWith(message: failure.message);
        }
      } finally {
        _operationInFlight = false;
      }
      return;
    }
    if (state.storageAction == InternalTransferStorageAction.retryResolution) {
      final pending = state.pending;
      if (pending == null) {
        state = const InternalTransferState();
        await _restore();
      } else {
        await _send(pending);
      }
    }
  }

  static bool _isUncertain(AppFailure failure) =>
      failure is NetworkFailure ||
      failure is TimeoutFailure ||
      failure is ServerFailure ||
      failure is UnexpectedFailure ||
      failure is InvalidResponseFailure ||
      failure is RequestCancelledFailure;

  static String _editableAmount(BigInt amountMinor) {
    final whole = amountMinor ~/ BigInt.from(100);
    final cents = (amountMinor % BigInt.from(100)).toString().padLeft(2, '0');
    return '$whole.$cents';
  }
}

final internalTransferControllerProvider =
    StateNotifierProvider.autoDispose<
      InternalTransferController,
      InternalTransferState
    >((ref) {
      final customer = ref.watch(
        authenticationControllerProvider.select((state) => state.customer),
      );
      final authentication = ref.watch(authenticationRepositoryProvider);
      final generation = authentication.sessionGeneration;
      final customerId = customer?.id ?? '';
      return InternalTransferController(
        ref.watch(internalTransferRepositoryProvider),
        ref.watch(pendingInternalTransferStoreProvider),
        customerId,
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

import 'dart:async';

import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/data/repositories/activity_repository.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityDetailStatus { loading, loaded, notFound, error }

class ActivityDetailState {
  const ActivityDetailState(
    this.status, {
    this.detail,
    this.message,
    this.requestId,
  });

  final ActivityDetailStatus status;
  final ActivityDetail? detail;
  final String? message;
  final String? requestId;
}

class ActivityDetailController extends StateNotifier<ActivityDetailState> {
  ActivityDetailController(
    this._repository,
    this._transactionId,
    this._isCurrent,
    this._invalidateSession,
  ) : super(const ActivityDetailState(ActivityDetailStatus.loading)) {
    unawaited(load());
  }

  final ActivityRepository _repository;
  final String _transactionId;
  final bool Function() _isCurrent;
  final Future<void> Function() _invalidateSession;
  bool _pending = false;

  Future<void> load() async {
    if (_pending || !mounted || !_isCurrent()) return;
    final normalized = normalizeCanonicalUuid(_transactionId);
    if (normalized == null) {
      state = const ActivityDetailState(
        ActivityDetailStatus.notFound,
        message: 'That transaction reference is invalid.',
      );
      return;
    }
    _pending = true;
    state = const ActivityDetailState(ActivityDetailStatus.loading);
    try {
      final detail = await _repository.readDetail(normalized);
      if (!mounted || !_isCurrent()) return;
      state = ActivityDetailState(ActivityDetailStatus.loaded, detail: detail);
    } on UnauthenticatedFailure {
      if (mounted && _isCurrent()) await _invalidateSession();
    } on ActivityTransactionNotFoundFailure catch (failure) {
      if (!mounted || !_isCurrent()) return;
      state = ActivityDetailState(
        ActivityDetailStatus.notFound,
        message: failure.message,
        requestId: failure.requestId,
      );
    } catch (error) {
      if (!mounted || !_isCurrent()) return;
      final failure = mapApiError(error);
      state = ActivityDetailState(
        ActivityDetailStatus.error,
        message: failure.message,
        requestId: failure.requestId,
      );
    } finally {
      _pending = false;
    }
  }
}

final activityDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<ActivityDetailController, ActivityDetailState, String>((ref, id) {
      final customer = ref.watch(
        authenticationControllerProvider.select((state) => state.customer),
      );
      final authentication = ref.watch(authenticationRepositoryProvider);
      final generation = authentication.sessionGeneration;
      return ActivityDetailController(
        ref.watch(activityRepositoryProvider),
        id,
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

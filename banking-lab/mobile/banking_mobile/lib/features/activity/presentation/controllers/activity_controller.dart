import 'dart:async';

import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/data/repositories/activity_repository.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityStatus { loading, loaded, empty, error }

class ActivityState {
  const ActivityState({
    this.status = ActivityStatus.loading,
    this.items = const [],
    this.filters = const ActivityFilters(),
    this.nextCursor,
    this.message,
    this.requestId,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  });

  final ActivityStatus status;
  final List<ActivityItem> items;
  final ActivityFilters filters;
  final String? nextCursor;
  final String? message;
  final String? requestId;
  final bool isRefreshing;
  final bool isLoadingMore;

  ActivityState copyWith({
    ActivityStatus? status,
    List<ActivityItem>? items,
    ActivityFilters? filters,
    Object? nextCursor = _unset,
    Object? message = _unset,
    Object? requestId = _unset,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) => ActivityState(
    status: status ?? this.status,
    items: items ?? this.items,
    filters: filters ?? this.filters,
    nextCursor: identical(nextCursor, _unset)
        ? this.nextCursor
        : nextCursor as String?,
    message: identical(message, _unset) ? this.message : message as String?,
    requestId: identical(requestId, _unset)
        ? this.requestId
        : requestId as String?,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

const Object _unset = Object();

class ActivityController extends StateNotifier<ActivityState> {
  ActivityController(this._repository, this._isCurrent, this._invalidateSession)
    : super(const ActivityState()) {
    unawaited(refresh());
  }

  final ActivityRepository _repository;
  final bool Function() _isCurrent;
  final Future<void> Function() _invalidateSession;
  bool _pending = false;

  Future<void> refresh() async {
    if (_pending || !mounted || !_isCurrent()) return;
    _pending = true;
    final hasItems = state.items.isNotEmpty;
    state = state.copyWith(
      status: hasItems ? ActivityStatus.loaded : ActivityStatus.loading,
      isRefreshing: hasItems,
      isLoadingMore: false,
      message: null,
      requestId: null,
    );
    try {
      final page = await _repository.readPage(filters: state.filters);
      if (!mounted || !_isCurrent()) return;
      state = ActivityState(
        status: page.items.isEmpty
            ? ActivityStatus.empty
            : ActivityStatus.loaded,
        items: page.items,
        filters: state.filters,
        nextCursor: page.nextCursor,
      );
    } on UnauthenticatedFailure {
      if (mounted && _isCurrent()) await _invalidateSession();
    } catch (error) {
      if (!mounted || !_isCurrent()) return;
      final failure = mapApiError(error);
      state = state.copyWith(
        status: hasItems ? ActivityStatus.loaded : ActivityStatus.error,
        isRefreshing: false,
        message: failure.message,
        requestId: failure.requestId,
      );
    } finally {
      _pending = false;
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (_pending || cursor == null || !mounted || !_isCurrent()) return;
    _pending = true;
    state = state.copyWith(isLoadingMore: true, message: null, requestId: null);
    try {
      final page = await _repository.readPage(
        filters: state.filters,
        cursor: cursor,
      );
      if (!mounted || !_isCurrent()) return;
      final ids = state.items.map((item) => item.transactionId).toSet();
      if (page.items.any((item) => !ids.add(item.transactionId))) {
        throw const InvalidResponseFailure();
      }
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      );
    } on UnauthenticatedFailure {
      if (mounted && _isCurrent()) await _invalidateSession();
    } catch (error) {
      if (!mounted || !_isCurrent()) return;
      final failure = mapApiError(error);
      state = state.copyWith(
        isLoadingMore: false,
        message: failure.message,
        requestId: failure.requestId,
      );
    } finally {
      _pending = false;
    }
  }

  Future<void> applyFilters(ActivityFilters filters) async {
    if (_pending) return;
    state = ActivityState(filters: filters);
    await refresh();
  }

  void clearNotice() {
    state = state.copyWith(message: null, requestId: null);
  }
}

final activityControllerProvider =
    StateNotifierProvider.autoDispose<ActivityController, ActivityState>((ref) {
      final customer = ref.watch(
        authenticationControllerProvider.select((state) => state.customer),
      );
      final authentication = ref.watch(authenticationRepositoryProvider);
      final generation = authentication.sessionGeneration;
      return ActivityController(
        ref.watch(activityRepositoryProvider),
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

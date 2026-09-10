import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/data/services/activity_api_service.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityRepository {
  ActivityRepository(this._api, this._authentication);

  final ActivityApiService _api;
  final AuthenticationRepository _authentication;

  Future<ActivityPage> readPage({
    ActivityFilters filters = const ActivityFilters(),
    String? cursor,
  }) => _authorized(
    (token) => _api.readPage(token, filters: filters, cursor: cursor),
  );

  Future<ActivityDetail> readDetail(String transactionId) =>
      _authorized((token) => _api.readDetail(token, transactionId));

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

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(
    ref.watch(activityApiServiceProvider),
    ref.watch(authenticationRepositoryProvider),
  ),
);

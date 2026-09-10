import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/errors/client_upgrade_signal.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';
import 'package:banking_mobile/features/client_compatibility/data/services/client_compatibility_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ClientCompatibilityStatus {
  checking,
  supported,
  updateRequired,
  unavailable,
  invalidLocalBuild,
}

class ClientCompatibilityState {
  const ClientCompatibilityState({
    required this.status,
    this.failure,
    this.currentBuild,
    this.minimumBuild,
  });

  const ClientCompatibilityState.checking()
    : this(status: ClientCompatibilityStatus.checking);

  final ClientCompatibilityStatus status;
  final AppFailure? failure;
  final int? currentBuild;
  final int? minimumBuild;
}

class ClientCompatibilityController
    extends StateNotifier<ClientCompatibilityState> {
  ClientCompatibilityController(
    this._metadata,
    this._service,
    this._authentication, {
    bool checkAutomatically = true,
  }) : super(
         ClientCompatibilityState(
           status: checkAutomatically
               ? ClientCompatibilityStatus.checking
               : ClientCompatibilityStatus.supported,
         ),
       ) {
    if (checkAutomatically) {
      unawaited(check());
    } else {
      unawaited(_authentication.initialize());
    }
  }

  final ClientBuildMetadata _metadata;
  final ClientCompatibilityApiService _service;
  final AuthenticationController _authentication;
  Future<void>? _check;

  Future<void> check() {
    return _check ??= _performCheck().whenComplete(() => _check = null);
  }

  Future<void> _performCheck() async {
    final metadata = _metadata;
    if (metadata is! ValidClientBuildMetadata) {
      state = const ClientCompatibilityState(
        status: ClientCompatibilityStatus.invalidLocalBuild,
      );
      return;
    }
    final info = metadata.info;

    state = ClientCompatibilityState(
      status: ClientCompatibilityStatus.checking,
      currentBuild: info.build,
    );
    try {
      final result = await _service.check(info);
      await _authentication.initialize();
      if (!mounted ||
          state.status == ClientCompatibilityStatus.updateRequired) {
        return;
      }
      state = ClientCompatibilityState(
        status: ClientCompatibilityStatus.supported,
        currentBuild: result.currentBuild,
        minimumBuild: result.minimumBuild,
      );
    } on ClientUpgradeRequiredFailure catch (failure) {
      requireUpdate(failure);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      state = ClientCompatibilityState(
        status: ClientCompatibilityStatus.unavailable,
        failure: failure,
        currentBuild: info.build,
      );
    } catch (_) {
      if (!mounted) return;
      state = ClientCompatibilityState(
        status: ClientCompatibilityStatus.unavailable,
        failure: const UnexpectedFailure(),
        currentBuild: info.build,
      );
    }
  }

  void requireUpdate(ClientUpgradeRequiredFailure failure) {
    if (!mounted) return;
    state = ClientCompatibilityState(
      status: ClientCompatibilityStatus.updateRequired,
      failure: failure,
      currentBuild: failure.currentBuild,
      minimumBuild: failure.minimumBuild,
    );
  }
}

final clientCompatibilityChecksEnabledProvider = Provider<bool>((ref) => true);

final clientCompatibilityControllerProvider =
    StateNotifierProvider<
      ClientCompatibilityController,
      ClientCompatibilityState
    >((ref) {
      final controller = ClientCompatibilityController(
        ref.watch(clientBuildMetadataProvider),
        ref.watch(clientCompatibilityApiServiceProvider),
        ref.read(authenticationControllerProvider.notifier),
        checkAutomatically: ref.watch(clientCompatibilityChecksEnabledProvider),
      );
      ref.listen<ClientUpgradeRequiredFailure?>(clientUpgradeSignalProvider, (
        _,
        next,
      ) {
        if (next != null) controller.requireUpdate(next);
      });

      final pending = ref.read(clientUpgradeSignalProvider);
      if (pending != null) controller.requireUpdate(pending);
      return controller;
    });

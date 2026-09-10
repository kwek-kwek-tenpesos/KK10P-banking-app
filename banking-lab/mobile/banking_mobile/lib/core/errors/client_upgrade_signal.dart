import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClientUpgradeSignal extends StateNotifier<ClientUpgradeRequiredFailure?> {
  ClientUpgradeSignal() : super(null);

  void report(ClientUpgradeRequiredFailure failure) => state = failure;

  void clear() => state = null;
}

final clientUpgradeSignalProvider =
    StateNotifierProvider<ClientUpgradeSignal, ClientUpgradeRequiredFailure?>(
      (ref) => ClientUpgradeSignal(),
    );

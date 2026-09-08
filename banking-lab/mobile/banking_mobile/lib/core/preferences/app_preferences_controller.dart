import 'dart:async';

import 'package:banking_mobile/core/preferences/app_preferences_provider.dart';
import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppPreferencesStatus { loading, ready }

class AppPreferencesState {
  const AppPreferencesState({
    required this.status,
    this.appearance = AppAppearance.light,
    this.introductionCompleted = false,
    this.knownAccountAttached = false,
    this.warning,
  });

  const AppPreferencesState.loading()
    : this(status: AppPreferencesStatus.loading);

  final AppPreferencesStatus status;
  final AppAppearance appearance;
  final bool introductionCompleted;
  final bool knownAccountAttached;
  final String? warning;

  bool get isReady => status == AppPreferencesStatus.ready;
}

class AppPreferencesController extends StateNotifier<AppPreferencesState> {
  AppPreferencesController(this._store)
    : super(const AppPreferencesState.loading()) {
    unawaited(initialize());
  }

  final AppPreferencesStore _store;
  Future<void>? _initialization;

  Future<void> initialize() {
    if (state.isReady) return Future<void>.value();
    return _initialization ??= _load().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _load() async {
    try {
      final snapshot = await _store.read();
      if (!mounted) return;
      state = AppPreferencesState(
        status: AppPreferencesStatus.ready,
        appearance: snapshot.appearance,
        introductionCompleted: snapshot.introductionCompleted,
        knownAccountAttached: snapshot.knownAccountAttached,
      );
    } catch (_) {
      if (!mounted) return;
      state = const AppPreferencesState(
        status: AppPreferencesStatus.ready,
        warning: 'Appearance and first-install preferences could not be read. Safe defaults are active.',
      );
    }
  }

  Future<void> setAppearance(AppAppearance appearance) async {
    await initialize();
    if (!mounted) return;
    state = AppPreferencesState(
      status: AppPreferencesStatus.ready,
      appearance: appearance,
      introductionCompleted: state.introductionCompleted,
      knownAccountAttached: state.knownAccountAttached,
    );
    try {
      await _store.saveAppearance(appearance);
    } catch (_) {
      _setWarning('Your appearance choice could not be saved on this device.');
    }
  }

  Future<void> markIntroductionCompleted() async {
    await initialize();
    if (!mounted || state.introductionCompleted) return;
    state = AppPreferencesState(
      status: AppPreferencesStatus.ready,
      appearance: state.appearance,
      introductionCompleted: true,
      knownAccountAttached: state.knownAccountAttached,
    );
    try {
      await _store.markIntroductionCompleted();
    } catch (_) {
      _setWarning(
        'The first-install choice could not be saved. You can continue safely.',
      );
    }
  }

  Future<void> markKnownAccountAttached() async {
    await initialize();
    if (!mounted || state.knownAccountAttached) return;
    state = AppPreferencesState(
      status: AppPreferencesStatus.ready,
      appearance: state.appearance,
      introductionCompleted: state.introductionCompleted,
      knownAccountAttached: true,
    );
    try {
      await _store.markKnownAccountAttached();
    } catch (_) {
      _setWarning('This device could not remember the attached-account hint.');
    }
  }

  Future<void> clearKnownAccountAttached() async {
    await initialize();
    if (!mounted) return;
    state = AppPreferencesState(
      status: AppPreferencesStatus.ready,
      appearance: state.appearance,
      introductionCompleted: state.introductionCompleted,
    );
    try {
      await _store.clearKnownAccountAttached();
    } catch (_) {
      _setWarning(
        'The attached-account hint could not be cleared on this device.',
      );
    }
  }

  void clearWarning() {
    if (!mounted || state.warning == null) return;
    state = AppPreferencesState(
      status: state.status,
      appearance: state.appearance,
      introductionCompleted: state.introductionCompleted,
      knownAccountAttached: state.knownAccountAttached,
    );
  }

  void _setWarning(String warning) {
    if (!mounted) return;
    state = AppPreferencesState(
      status: AppPreferencesStatus.ready,
      appearance: state.appearance,
      introductionCompleted: state.introductionCompleted,
      knownAccountAttached: state.knownAccountAttached,
      warning: warning,
    );
  }
}

final appPreferencesControllerProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferencesState>((ref) {
      return AppPreferencesController(ref.watch(appPreferencesStoreProvider));
    });

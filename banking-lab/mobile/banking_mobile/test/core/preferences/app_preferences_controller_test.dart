import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_app_preferences_store.dart';

void main() {
  test('loads saved appearance and experience flags', () async {
    final store = MemoryAppPreferencesStore(
      appearance: AppAppearance.dark,
      introductionCompleted: true,
      knownAccountAttached: true,
    );
    final controller = AppPreferencesController(store);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.state.isReady, isTrue);
    expect(controller.state.appearance, AppAppearance.dark);
    expect(controller.state.introductionCompleted, isTrue);
    expect(controller.state.knownAccountAttached, isTrue);
  });

  test('read failure becomes a usable light signed-out default', () async {
    final store = MemoryAppPreferencesStore()
      ..readError = StateError('storage unavailable');
    final controller = AppPreferencesController(store);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.state.isReady, isTrue);
    expect(controller.state.appearance, AppAppearance.light);
    expect(controller.state.introductionCompleted, isFalse);
    expect(controller.state.knownAccountAttached, isFalse);
    expect(controller.state.warning, isNotNull);
  });

  test('updates appearance and both experience markers', () async {
    final store = MemoryAppPreferencesStore();
    final controller = AppPreferencesController(store);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.setAppearance(AppAppearance.system);
    await controller.markIntroductionCompleted();
    await controller.markKnownAccountAttached();
    expect(controller.state.appearance, AppAppearance.system);
    expect(controller.state.introductionCompleted, isTrue);
    expect(controller.state.knownAccountAttached, isTrue);

    await controller.clearKnownAccountAttached();
    expect(controller.state.knownAccountAttached, isFalse);
    expect(store.snapshot.knownAccountAttached, isFalse);
  });
}

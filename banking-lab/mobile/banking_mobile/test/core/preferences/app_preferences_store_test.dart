import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing and malformed values fall back to safe defaults', () async {
    final backend = _MemoryBackend({
      SecureAppPreferencesStore.appearanceKey: 'neon',
      SecureAppPreferencesStore.introductionCompletedKey: 'maybe',
      SecureAppPreferencesStore.knownAccountAttachedKey: '1',
    });
    final store = SecureAppPreferencesStore(backend);

    final snapshot = await store.read();

    expect(snapshot.appearance, AppAppearance.light);
    expect(snapshot.introductionCompleted, isFalse);
    expect(snapshot.knownAccountAttached, isFalse);
  });

  test('round trips only versioned non-sensitive experience values', () async {
    final backend = _MemoryBackend();
    final store = SecureAppPreferencesStore(backend);

    await store.saveAppearance(AppAppearance.system);
    await store.markIntroductionCompleted();
    await store.markKnownAccountAttached();

    var snapshot = await store.read();
    expect(snapshot.appearance, AppAppearance.system);
    expect(snapshot.introductionCompleted, isTrue);
    expect(snapshot.knownAccountAttached, isTrue);
    expect(backend.values.keys, {
      SecureAppPreferencesStore.appearanceKey,
      SecureAppPreferencesStore.introductionCompletedKey,
      SecureAppPreferencesStore.knownAccountAttachedKey,
    });

    await store.clearKnownAccountAttached();
    snapshot = await store.read();
    expect(snapshot.knownAccountAttached, isFalse);
  });
}

final class _MemoryBackend implements AppPreferencesBackend {
  _MemoryBackend([Map<String, String>? values])
    : values = Map<String, String>.of(values ?? const {});

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

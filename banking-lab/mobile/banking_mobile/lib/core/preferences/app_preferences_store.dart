import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppAppearance { light, dark, system }

class AppPreferencesSnapshot {
  const AppPreferencesSnapshot({
    this.appearance = AppAppearance.light,
    this.introductionCompleted = false,
    this.knownAccountAttached = false,
  });

  final AppAppearance appearance;
  final bool introductionCompleted;
  final bool knownAccountAttached;
}

abstract interface class AppPreferencesStore {
  Future<AppPreferencesSnapshot> read();

  Future<void> saveAppearance(AppAppearance appearance);

  Future<void> markIntroductionCompleted();

  Future<void> markKnownAccountAttached();

  Future<void> clearKnownAccountAttached();
}

abstract interface class AppPreferencesBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecurePreferencesBackend implements AppPreferencesBackend {
  FlutterSecurePreferencesBackend(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class SecureAppPreferencesStore implements AppPreferencesStore {
  SecureAppPreferencesStore(this._backend);

  static const appearanceKey = 'experience.v1.appearance';
  static const introductionCompletedKey =
      'experience.v1.introduction_completed';
  static const knownAccountAttachedKey = 'experience.v1.known_account_attached';

  final AppPreferencesBackend _backend;

  @override
  Future<AppPreferencesSnapshot> read() async {
    final values = await Future.wait([
      _backend.read(appearanceKey),
      _backend.read(introductionCompletedKey),
      _backend.read(knownAccountAttachedKey),
    ]);

    return AppPreferencesSnapshot(
      appearance: _parseAppearance(values[0]),
      introductionCompleted: values[1] == 'true',
      knownAccountAttached: values[2] == 'true',
    );
  }

  @override
  Future<void> saveAppearance(AppAppearance appearance) {
    return _backend.write(appearanceKey, appearance.name);
  }

  @override
  Future<void> markIntroductionCompleted() {
    return _backend.write(introductionCompletedKey, 'true');
  }

  @override
  Future<void> markKnownAccountAttached() {
    return _backend.write(knownAccountAttachedKey, 'true');
  }

  @override
  Future<void> clearKnownAccountAttached() {
    return _backend.delete(knownAccountAttachedKey);
  }

  static AppAppearance _parseAppearance(String? value) {
    return AppAppearance.values.firstWhere(
      (appearance) => appearance.name == value,
      orElse: () => AppAppearance.light,
    );
  }
}

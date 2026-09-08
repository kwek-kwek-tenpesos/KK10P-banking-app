import 'package:banking_mobile/core/preferences/app_preferences_store.dart';

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore({
    AppAppearance appearance = AppAppearance.light,
    bool introductionCompleted = false,
    bool knownAccountAttached = false,
  }) : snapshot = AppPreferencesSnapshot(
         appearance: appearance,
         introductionCompleted: introductionCompleted,
         knownAccountAttached: knownAccountAttached,
       );

  AppPreferencesSnapshot snapshot;
  Object? readError;
  Object? writeError;

  @override
  Future<AppPreferencesSnapshot> read() async {
    if (readError case final error?) throw error;
    return snapshot;
  }

  @override
  Future<void> saveAppearance(AppAppearance appearance) async {
    _throwIfWritingFails();
    snapshot = AppPreferencesSnapshot(
      appearance: appearance,
      introductionCompleted: snapshot.introductionCompleted,
      knownAccountAttached: snapshot.knownAccountAttached,
    );
  }

  @override
  Future<void> markIntroductionCompleted() async {
    _throwIfWritingFails();
    snapshot = AppPreferencesSnapshot(
      appearance: snapshot.appearance,
      introductionCompleted: true,
      knownAccountAttached: snapshot.knownAccountAttached,
    );
  }

  @override
  Future<void> markKnownAccountAttached() async {
    _throwIfWritingFails();
    snapshot = AppPreferencesSnapshot(
      appearance: snapshot.appearance,
      introductionCompleted: snapshot.introductionCompleted,
      knownAccountAttached: true,
    );
  }

  @override
  Future<void> clearKnownAccountAttached() async {
    _throwIfWritingFails();
    snapshot = AppPreferencesSnapshot(
      appearance: snapshot.appearance,
      introductionCompleted: snapshot.introductionCompleted,
    );
  }

  void _throwIfWritingFails() {
    if (writeError case final error?) throw error;
  }
}

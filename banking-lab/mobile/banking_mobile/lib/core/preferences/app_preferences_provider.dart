import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final appPreferencesStoreProvider = Provider<AppPreferencesStore>((ref) {
  const storage = FlutterSecureStorage();
  return SecureAppPreferencesStore(FlutterSecurePreferencesBackend(storage));
});

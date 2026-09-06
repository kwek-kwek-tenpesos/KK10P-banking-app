import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureSessionStoreProvider = Provider<SecureSessionStore>((ref) {
  const secureStorage = FlutterSecureStorage();

  return FlutterSecureSessionStore(secureStorage);
});

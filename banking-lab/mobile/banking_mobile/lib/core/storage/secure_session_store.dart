import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureSessionStore {
  Future<void> saveRefreshToken(String refreshToken);

  Future<String?> readRefreshToken();

  Future<void> clearRefreshToken();
}

final class FlutterSecureSessionStore implements SecureSessionStore {
  FlutterSecureSessionStore(this._storage);

  static const String _refreshTokenKey = 'auth.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveRefreshToken(String refreshToken) {
    return _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> clearRefreshToken() {
    return _storage.delete(key: _refreshTokenKey);
  }
}

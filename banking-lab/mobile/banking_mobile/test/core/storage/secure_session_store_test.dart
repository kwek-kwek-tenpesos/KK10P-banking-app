import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureSessionStore sessionStore;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});

    sessionStore = FlutterSecureSessionStore(const FlutterSecureStorage());
  });

  group('FlutterSecureSessionStore', () {
    test('returns null when no refresh token is stored', () async {
      final refreshToken = await sessionStore.readRefreshToken();

      expect(refreshToken, isNull);
    });

    test('saves and reads the refresh token', () async {
      await sessionStore.saveRefreshToken('fake-refresh-token');

      final refreshToken = await sessionStore.readRefreshToken();

      expect(refreshToken, 'fake-refresh-token');
    });

    test('replaces an existing refresh token', () async {
      await sessionStore.saveRefreshToken('old-fake-token');
      await sessionStore.saveRefreshToken('new-fake-token');

      final refreshToken = await sessionStore.readRefreshToken();

      expect(refreshToken, 'new-fake-token');
    });

    test('clears the refresh token', () async {
      await sessionStore.saveRefreshToken('fake-refresh-token');

      await sessionStore.clearRefreshToken();

      final refreshToken = await sessionStore.readRefreshToken();

      expect(refreshToken, isNull);
    });
  });
}

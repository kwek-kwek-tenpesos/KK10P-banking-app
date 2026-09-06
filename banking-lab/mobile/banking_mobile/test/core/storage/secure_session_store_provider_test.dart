import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/core/storage/secure_session_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides a FlutterSecureSessionStore', () {
    final container = ProviderContainer();

    addTearDown(container.dispose);

    final sessionStore = container.read(secureSessionStoreProvider);

    expect(sessionStore, isA<FlutterSecureSessionStore>());
  });

  test('can be replaced with a fake store', () {
    final fakeSessionStore = _FakeSecureSessionStore();

    final container = ProviderContainer(
      overrides: [
        secureSessionStoreProvider.overrideWithValue(fakeSessionStore),
      ],
    );

    addTearDown(container.dispose);

    final sessionStore = container.read(secureSessionStoreProvider);

    expect(identical(sessionStore, fakeSessionStore), isTrue);
  });
}

final class _FakeSecureSessionStore implements SecureSessionStore {
  @override
  Future<void> saveRefreshToken(String refreshToken) async {}

  @override
  Future<String?> readRefreshToken() async {
    return null;
  }

  @override
  Future<void> clearRefreshToken() async {}
}

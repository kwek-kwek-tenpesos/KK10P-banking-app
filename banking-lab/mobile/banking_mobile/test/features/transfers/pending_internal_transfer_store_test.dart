import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/transfers/data/storage/pending_internal_transfer_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transfer_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('secure store round-trips and clears one customer envelope', () async {
    final store = FlutterPendingInternalTransferStore(
      const FlutterSecureStorage(),
    );
    final pending = samplePending();
    await store.save(pending);
    final restored = await store.read(customerId);
    expect(restored?.idempotencyKey, idempotencyKey);
    expect(restored?.amountMinor, BigInt.from(1050));
    expect(await store.read('another-customer'), isNull);
    await store.clear(customerId);
    expect(await store.read(customerId), isNull);
  });

  test('corrupt pending data is blocked instead of silently deleted', () async {
    FlutterSecureStorage.setMockInitialValues({
      FlutterPendingInternalTransferStore.storageKey(customerId): '{bad-json',
    });
    final store = FlutterPendingInternalTransferStore(
      const FlutterSecureStorage(),
    );
    await expectLater(
      store.read(customerId),
      throwsA(
        isA<PendingTransferStorageFailure>().having(
          (failure) => failure.corrupt,
          'corrupt',
          isTrue,
        ),
      ),
    );
  });
}

import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/transfers/presentation/controllers/internal_transfer_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transfer_test_support.dart';

void main() {
  test('rapid confirmations store and send one logical request', () async {
    final repository = StubInternalTransferRepository();
    final store = MemoryPendingTransferStore();
    final gate = Completer<void>();
    repository.onTransfer = (pending) async {
      await gate.future;
      return sampleTransferReceipt;
    };
    var refreshes = 0;
    final controller = _controller(
      repository,
      store,
      refresh: () => refreshes++,
    );
    await _settleRestore();
    _fillValidDraft(controller);

    final first = controller.submit(
      sourceAccountReference: sourceReference,
      availableMinor: BigInt.from(100000),
    );
    final ignored = controller.submit(
      sourceAccountReference: sourceReference,
      availableMinor: BigInt.from(100000),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.requests, hasLength(1));
    expect(store.saves, 1);
    gate.complete();
    await Future.wait([first, ignored]);

    expect(controller.state.status, InternalTransferStatus.success);
    expect(store.values, isEmpty);
    expect(refreshes, 1);
    controller.dispose();
  });

  test(
    'uncertain request survives recreation and retries the same key',
    () async {
      final store = MemoryPendingTransferStore();
      final firstRepository = StubInternalTransferRepository()
        ..onTransfer = (_) async => throw const TimeoutFailure();
      final first = _controller(firstRepository, store);
      await _settleRestore();
      _fillValidDraft(first);
      await first.submit(
        sourceAccountReference: sourceReference,
        availableMinor: BigInt.from(100000),
      );
      expect(first.state.status, InternalTransferStatus.uncertain);
      final originalKey = firstRepository.requests.single.idempotencyKey;
      expect(store.values[customerId]?.idempotencyKey, originalKey);
      first.dispose();

      final secondRepository = StubInternalTransferRepository();
      final second = _controller(secondRepository, store);
      await _settleRestore();
      expect(second.state.status, InternalTransferStatus.uncertain);
      await second.retryPending();
      expect(secondRepository.requests.single.idempotencyKey, originalKey);
      expect(second.state.status, InternalTransferStatus.success);
      expect(store.values, isEmpty);
      second.dispose();
    },
  );

  test(
    'secure save failure sends nothing and retries the same envelope',
    () async {
      final repository = StubInternalTransferRepository();
      final store = MemoryPendingTransferStore()
        ..saveError = const PendingTransferStorageFailure();
      final controller = _controller(repository, store);
      await _settleRestore();
      _fillValidDraft(controller);
      await controller.submit(
        sourceAccountReference: sourceReference,
        availableMinor: BigInt.from(100000),
      );
      expect(repository.requests, isEmpty);
      expect(
        controller.state.storageAction,
        InternalTransferStorageAction.retrySave,
      );
      final key = controller.state.pending!.idempotencyKey;

      store.saveError = null;
      await controller.retryStorageAction();
      expect(repository.requests.single.idempotencyKey, key);
      expect(controller.state.status, InternalTransferStatus.success);
      controller.dispose();
    },
  );

  test(
    'recipient failure clears recovery and returns to recipient field',
    () async {
      final repository = StubInternalTransferRepository()
        ..onTransfer = (_) async =>
            throw const TransferRecipientNotFoundFailure(
              requestId: 'request-7',
            );
      final store = MemoryPendingTransferStore();
      final controller = _controller(repository, store);
      await _settleRestore();
      _fillValidDraft(controller);
      await controller.submit(
        sourceAccountReference: sourceReference,
        availableMinor: BigInt.from(100000),
      );
      expect(controller.state.status, InternalTransferStatus.definitiveFailure);
      expect(controller.state.step, InternalTransferStep.recipient);
      expect(controller.state.recipientError, contains('cannot receive'));
      expect(controller.state.requestId, 'request-7');
      expect(store.values, isEmpty);
      controller.dispose();
    },
  );

  test(
    'rate limit retains key for retry but can be safely cancelled',
    () async {
      final repository = StubInternalTransferRepository()
        ..onTransfer = (_) async =>
            throw const RateLimitedFailure(retryAfterSeconds: 12);
      final store = MemoryPendingTransferStore();
      final controller = _controller(repository, store);
      await _settleRestore();
      _fillValidDraft(controller);
      await controller.submit(
        sourceAccountReference: sourceReference,
        availableMinor: BigInt.from(100000),
      );
      expect(controller.state.status, InternalTransferStatus.retryableRejected);
      expect(controller.state.retryAfterSeconds, 12);
      expect(store.values, isNotEmpty);
      await controller.cancelRateLimited();
      expect(controller.state.status, InternalTransferStatus.editing);
      expect(controller.state.step, InternalTransferStep.review);
      expect(store.values, isEmpty);
      controller.dispose();
    },
  );

  test('restored pending request is isolated by customer id', () async {
    final store = MemoryPendingTransferStore();
    store.values[customerId] = samplePending();
    final other = _controller(
      StubInternalTransferRepository(),
      store,
      owner: 'another-customer',
    );
    await _settleRestore();
    expect(other.state.status, InternalTransferStatus.editing);
    expect(other.state.pending, isNull);
    other.dispose();
  });
}

InternalTransferController _controller(
  StubInternalTransferRepository repository,
  MemoryPendingTransferStore store, {
  String owner = customerId,
  void Function()? refresh,
}) => InternalTransferController(
  repository,
  store,
  owner,
  () => true,
  () async {},
  refresh ?? () {},
  newId: () => idempotencyKey,
  now: () => DateTime.utc(2026, 9, 9),
);

void _fillValidDraft(InternalTransferController controller) {
  controller.updateRecipient(destinationReference);
  controller.updateAmount('10.50');
}

Future<void> _settleRestore() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

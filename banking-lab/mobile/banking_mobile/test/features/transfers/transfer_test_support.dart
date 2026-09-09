import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/transfers/data/models/internal_transfer_receipt.dart';
import 'package:banking_mobile/features/transfers/data/models/pending_internal_transfer.dart';
import 'package:banking_mobile/features/transfers/data/repositories/internal_transfer_repository.dart';
import 'package:banking_mobile/features/transfers/data/storage/pending_internal_transfer_store.dart';

const sourceReference = '11111111-1111-4111-8111-111111111111';
const destinationReference = '22222222-2222-4222-8222-222222222222';
const customerId = '33333333-3333-4333-8333-333333333333';
const idempotencyKey = '44444444-4444-4444-8444-444444444444';

final sampleTransferReceipt = InternalTransferReceipt(
  transactionId: '55555555-5555-4555-8555-555555555555',
  sourceAccountReference: sourceReference,
  destinationAccountReference: destinationReference,
  currency: 'PHP',
  amountMinor: BigInt.from(1050),
  sourceBalanceAfterMinor: BigInt.from(98950),
  status: 'COMPLETED',
  createdAtUtc: DateTime.utc(2026, 9, 9, 1, 2, 3),
  replayed: false,
);

PendingInternalTransfer samplePending({String owner = customerId}) =>
    PendingInternalTransfer(
      customerId: owner,
      idempotencyKey: idempotencyKey,
      destinationAccountReference: destinationReference,
      amountMinor: BigInt.from(1050),
      createdAtUtc: DateTime.utc(2026, 9, 9),
    );

class MemoryPendingTransferStore implements PendingInternalTransferStore {
  final Map<String, PendingInternalTransfer> values = {};
  Object? readError;
  Object? saveError;
  Object? clearError;
  int saves = 0;
  int clears = 0;

  @override
  Future<PendingInternalTransfer?> read(String owner) async {
    if (readError != null) throw readError!;
    return values[owner];
  }

  @override
  Future<void> save(PendingInternalTransfer transfer) async {
    saves++;
    if (saveError != null) throw saveError!;
    values[transfer.customerId] = transfer;
  }

  @override
  Future<void> clear(String owner) async {
    clears++;
    if (clearError != null) throw clearError!;
    values.remove(owner);
  }
}

class StubInternalTransferRepository implements InternalTransferRepository {
  Future<InternalTransferReceipt> Function(PendingInternalTransfer)? onTransfer;
  final requests = <PendingInternalTransfer>[];

  @override
  Future<InternalTransferReceipt> transfer(
    PendingInternalTransfer pending,
  ) async {
    requests.add(pending);
    return onTransfer == null
        ? sampleTransferReceipt
        : await onTransfer!(pending);
  }
}

PendingTransferStorageFailure unavailableStorage() =>
    const PendingTransferStorageFailure();

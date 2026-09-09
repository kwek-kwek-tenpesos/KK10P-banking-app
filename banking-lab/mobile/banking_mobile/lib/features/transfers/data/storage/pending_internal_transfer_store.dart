import 'dart:convert';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/transfers/data/models/pending_internal_transfer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PendingInternalTransferStore {
  Future<PendingInternalTransfer?> read(String customerId);
  Future<void> save(PendingInternalTransfer transfer);
  Future<void> clear(String customerId);
}

final class FlutterPendingInternalTransferStore
    implements PendingInternalTransferStore {
  FlutterPendingInternalTransferStore(this._storage);

  final FlutterSecureStorage _storage;

  static String storageKey(String customerId) =>
      'transfer.pending.v1.${base64Url.encode(utf8.encode(customerId))}';

  @override
  Future<PendingInternalTransfer?> read(String customerId) async {
    try {
      final value = await _storage.read(key: storageKey(customerId));
      if (value == null) return null;
      final transfer = PendingInternalTransfer.decode(value);
      if (transfer.customerId != customerId) {
        throw const FormatException('Pending transfer customer mismatch.');
      }
      return transfer;
    } on FormatException {
      throw const PendingTransferStorageFailure(corrupt: true);
    } on PendingTransferStorageFailure {
      rethrow;
    } catch (_) {
      throw const PendingTransferStorageFailure();
    }
  }

  @override
  Future<void> save(PendingInternalTransfer transfer) async {
    try {
      await _storage.write(
        key: storageKey(transfer.customerId),
        value: transfer.encode(),
      );
    } catch (_) {
      throw const PendingTransferStorageFailure();
    }
  }

  @override
  Future<void> clear(String customerId) async {
    try {
      await _storage.delete(key: storageKey(customerId));
    } catch (_) {
      throw const PendingTransferStorageFailure();
    }
  }
}

final pendingInternalTransferStoreProvider =
    Provider<PendingInternalTransferStore>((ref) {
      const storage = FlutterSecureStorage();
      return FlutterPendingInternalTransferStore(storage);
    });

import 'dart:convert';

import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';
import 'package:banking_mobile/features/transfers/domain/internal_transfer_amount.dart';

class PendingInternalTransfer {
  const PendingInternalTransfer({
    required this.customerId,
    required this.idempotencyKey,
    required this.destinationAccountReference,
    required this.amountMinor,
    required this.createdAtUtc,
  });

  factory PendingInternalTransfer.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    final customerId = json['customerId'];
    final key = json['idempotencyKey'];
    final destination = json['destinationAccountReference'];
    final amountText = json['amountMinor'];
    final createdText = json['createdAtUtc'];
    final amount =
        amountText is String && _canonicalPositive.hasMatch(amountText)
        ? BigInt.tryParse(amountText)
        : null;
    final created = createdText is String && createdText.endsWith('Z')
        ? DateTime.tryParse(createdText)
        : null;
    if (json.length != 6 ||
        version != 1 ||
        customerId is! String ||
        customerId.trim().isEmpty ||
        customerId.length > 200 ||
        key is! String ||
        !canonicalUuidPattern.hasMatch(key) ||
        destination is! String ||
        !canonicalUuidPattern.hasMatch(destination) ||
        destination == zeroUuid ||
        amount == null ||
        amount < InternalTransferAmount.minimumMinor ||
        amount > InternalTransferAmount.maximumMinor ||
        created == null ||
        !created.isUtc) {
      throw const FormatException('Invalid pending internal transfer.');
    }
    return PendingInternalTransfer(
      customerId: customerId,
      idempotencyKey: key,
      destinationAccountReference: destination,
      amountMinor: amount,
      createdAtUtc: created,
    );
  }

  factory PendingInternalTransfer.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid pending internal transfer.');
    }
    return PendingInternalTransfer.fromJson(decoded);
  }

  static final RegExp _canonicalPositive = RegExp(r'^[1-9][0-9]*$');

  final String customerId;
  final String idempotencyKey;
  final String destinationAccountReference;
  final BigInt amountMinor;
  final DateTime createdAtUtc;

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'customerId': customerId,
    'idempotencyKey': idempotencyKey,
    'destinationAccountReference': destinationAccountReference,
    'amountMinor': amountMinor.toString(),
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
  });
}

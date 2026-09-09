import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';
import 'package:banking_mobile/features/transfers/domain/internal_transfer_amount.dart';

class InternalTransferReceipt {
  const InternalTransferReceipt({
    required this.transactionId,
    required this.sourceAccountReference,
    required this.destinationAccountReference,
    required this.currency,
    required this.amountMinor,
    required this.sourceBalanceAfterMinor,
    required this.status,
    required this.createdAtUtc,
    required this.replayed,
  });

  factory InternalTransferReceipt.fromJson(Map<String, dynamic> json) {
    final transactionId = json['transactionId'];
    final source = json['sourceAccountReference'];
    final destination = json['destinationAccountReference'];
    final currency = json['currency'];
    final amountText = json['amountMinor'];
    final balanceText = json['sourceBalanceAfterMinor'];
    final status = json['status'];
    final createdText = json['createdAtUtc'];
    final replayed = json['replayed'];
    final amount =
        amountText is String && _canonicalUnsigned.hasMatch(amountText)
        ? BigInt.tryParse(amountText)
        : null;
    final balance =
        balanceText is String && _canonicalUnsigned.hasMatch(balanceText)
        ? BigInt.tryParse(balanceText)
        : null;
    final created = createdText is String && createdText.endsWith('Z')
        ? DateTime.tryParse(createdText)
        : null;

    if (transactionId is! String ||
        !canonicalUuidPattern.hasMatch(transactionId) ||
        transactionId == zeroUuid ||
        source is! String ||
        !canonicalUuidPattern.hasMatch(source) ||
        source == zeroUuid ||
        destination is! String ||
        !canonicalUuidPattern.hasMatch(destination) ||
        destination == zeroUuid ||
        currency != 'PHP' ||
        amount == null ||
        amount < InternalTransferAmount.minimumMinor ||
        amount > InternalTransferAmount.maximumMinor ||
        balance == null ||
        balance.isNegative ||
        status != 'COMPLETED' ||
        created == null ||
        !created.isUtc ||
        replayed is! bool) {
      throw const FormatException('Invalid internal transfer receipt.');
    }

    return InternalTransferReceipt(
      transactionId: transactionId,
      sourceAccountReference: source,
      destinationAccountReference: destination,
      currency: 'PHP',
      amountMinor: amount,
      sourceBalanceAfterMinor: balance,
      status: 'COMPLETED',
      createdAtUtc: created,
      replayed: replayed,
    );
  }

  static final RegExp _canonicalUnsigned = RegExp(r'^(?:0|[1-9][0-9]*)$');

  final String transactionId;
  final String sourceAccountReference;
  final String destinationAccountReference;
  final String currency;
  final BigInt amountMinor;
  final BigInt sourceBalanceAfterMinor;
  final String status;
  final DateTime createdAtUtc;
  final bool replayed;

  String get formattedAmount => InternalTransferAmount.formatMinor(amountMinor);
  String get formattedSourceBalanceAfter =>
      InternalTransferAmount.formatMinor(sourceBalanceAfterMinor);
}

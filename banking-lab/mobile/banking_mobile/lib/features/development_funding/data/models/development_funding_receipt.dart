class DevelopmentFundingReceipt {
  const DevelopmentFundingReceipt({
    required this.transactionId,
    required this.accountId,
    required this.currency,
    required this.creditedAmountMinor,
    required this.balanceAfterMinor,
    required this.createdAtUtc,
    required this.replayed,
  });

  final String transactionId;
  final String accountId;
  final String currency;
  final int creditedAmountMinor;
  final int balanceAfterMinor;
  final DateTime createdAtUtc;
  final bool replayed;

  factory DevelopmentFundingReceipt.fromJson(Map<String, dynamic> json) {
    final transactionId = json['transactionId'];
    final accountId = json['accountId'];
    final currency = json['currency'];
    final creditedRaw = json['creditedAmountMinor'];
    final balanceRaw = json['balanceAfterMinor'];
    final credited = creditedRaw is String ? int.tryParse(creditedRaw) : null;
    final balance = balanceRaw is String ? int.tryParse(balanceRaw) : null;
    final createdAt = DateTime.tryParse(json['createdAtUtc']?.toString() ?? '');
    final replayed = json['replayed'];
    if (transactionId is! String ||
        accountId is! String ||
        currency != 'PHP' ||
        credited == null ||
        credited <= 0 ||
        balance == null ||
        balance < 0 ||
        createdAt == null ||
        !createdAt.isUtc ||
        replayed is! bool) {
      throw const FormatException('Invalid Development funding receipt.');
    }
    return DevelopmentFundingReceipt(
      transactionId: transactionId,
      accountId: accountId,
      currency: currency as String,
      creditedAmountMinor: credited,
      balanceAfterMinor: balance,
      createdAtUtc: createdAt,
      replayed: replayed,
    );
  }
}

class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.currency,
    required this.balanceMinor,
    required this.openedAtUtc,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final currency = json['currency'];
    final amount = json['balanceMinor'];
    final opened = json['openedAtUtc'];
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
            .hasMatch(id) ||
        currency != 'PHP' ||
        amount is! String ||
        amount != '0' ||
        opened is! String ||
        !opened.endsWith('Z')) {
      throw const FormatException('Invalid simulator account.');
    }
    final timestamp = DateTime.tryParse(opened);
    if (timestamp == null || !timestamp.isUtc) {
      throw const FormatException('Invalid account timestamp.');
    }
    return AccountSummary(
      id: id,
      currency: 'PHP',
      balanceMinor: BigInt.parse(amount),
      openedAtUtc: timestamp,
    );
  }

  final String id;
  final String currency;
  final BigInt balanceMinor;
  final DateTime openedAtUtc;

  String get formattedBalance {
    final hundred = BigInt.from(100);
    final units = balanceMinor ~/ hundred;
    final cents = (balanceMinor % hundred).toString().padLeft(2, '0');
    return '$currency $units.$cents';
  }
}

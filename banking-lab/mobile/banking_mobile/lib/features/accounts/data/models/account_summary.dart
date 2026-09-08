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
    final canonicalAmount =
        amount is String && RegExp(r'^(?:0|[1-9][0-9]*)$').hasMatch(amount)
        ? BigInt.tryParse(amount)
        : null;
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
            .hasMatch(id) ||
        currency != 'PHP' ||
        canonicalAmount == null ||
        canonicalAmount > BigInt.from(9223372036854775807) ||
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
      balanceMinor: canonicalAmount,
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
    final grouped = units.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$currency $grouped.$cents';
  }
}

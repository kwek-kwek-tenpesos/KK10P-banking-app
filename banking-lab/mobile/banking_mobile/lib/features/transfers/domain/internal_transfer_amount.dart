class InternalTransferAmount {
  const InternalTransferAmount._(this.minor);

  static final BigInt minimumMinor = BigInt.one;
  static final BigInt maximumMinor = BigInt.from(5000000);

  final BigInt minor;

  static InternalTransferAmount? tryParse(String input) {
    final value = input.trim();
    if (value.isEmpty ||
        !RegExp(
          r'^(?:0|[1-9][0-9]*|[1-9][0-9]{0,2}(?:,[0-9]{3})+)(?:\.[0-9]{0,2})?$',
        ).hasMatch(value)) {
      return null;
    }
    final pieces = value.replaceAll(',', '').split('.');
    final whole = BigInt.tryParse(pieces[0]);
    if (whole == null) return null;
    final fractionText = pieces.length == 1 ? '00' : pieces[1].padRight(2, '0');
    final fraction = BigInt.tryParse(
      fractionText.isEmpty ? '00' : fractionText,
    );
    if (fraction == null) return null;
    return InternalTransferAmount._(whole * BigInt.from(100) + fraction);
  }

  static String? validate(String input, {BigInt? availableMinor}) {
    final parsed = tryParse(input);
    if (parsed == null) {
      return 'Enter a valid PHP amount with no more than two decimal places.';
    }
    if (parsed.minor < minimumMinor) return 'Enter at least PHP 0.01.';
    if (parsed.minor > maximumMinor) {
      return 'The maximum per transfer is PHP 50,000.00.';
    }
    if (availableMinor != null && parsed.minor > availableMinor) {
      return 'Your current simulator balance is too low for this amount.';
    }
    return null;
  }

  String get formatted => formatMinor(minor);

  static String formatMinor(BigInt amountMinor) {
    final negative = amountMinor.isNegative;
    final absolute = amountMinor.abs();
    final whole = absolute ~/ BigInt.from(100);
    final cents = (absolute % BigInt.from(100)).toString().padLeft(2, '0');
    final grouped = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'PHP ${negative ? '-' : ''}$grouped.$cents';
  }
}

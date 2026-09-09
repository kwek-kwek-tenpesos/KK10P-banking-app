import 'package:banking_mobile/features/transfers/domain/internal_transfer_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses supported PHP input directly to integer centavos', () {
    final cases = <String, BigInt>{
      '0.01': BigInt.one,
      '1': BigInt.from(100),
      '1.2': BigInt.from(120),
      '1.23': BigInt.from(123),
      '1000': BigInt.from(100000),
      '50,000.00': BigInt.from(5000000),
    };
    for (final entry in cases.entries) {
      expect(InternalTransferAmount.tryParse(entry.key)?.minor, entry.value);
    }
  });

  test('rejects malformed and floating-point-like representations', () {
    for (final value in [
      '',
      '-1',
      '.50',
      '00.10',
      '1.234',
      '1e2',
      '1,00.00',
      '50,000.01',
    ]) {
      if (value == '50,000.01') {
        expect(InternalTransferAmount.validate(value), contains('maximum'));
      } else {
        expect(InternalTransferAmount.tryParse(value), isNull, reason: value);
      }
    }
  });

  test('validates minimum, maximum and currently available balance', () {
    expect(InternalTransferAmount.validate('0'), contains('0.01'));
    expect(InternalTransferAmount.validate('50,000.01'), contains('maximum'));
    expect(
      InternalTransferAmount.validate(
        '10.01',
        availableMinor: BigInt.from(1000),
      ),
      contains('balance'),
    );
    expect(
      InternalTransferAmount.validate(
        '10.00',
        availableMinor: BigInt.from(1000),
      ),
      isNull,
    );
  });

  test('formats minor units without floating point', () {
    expect(InternalTransferAmount.formatMinor(BigInt.one), 'PHP 0.01');
    expect(
      InternalTransferAmount.formatMinor(BigInt.from(1234567)),
      'PHP 12,345.67',
    );
  });
}

import 'dart:math';

import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates canonical UUID v4 values', () {
    final value = newSecureUuidV4(Random(7));
    expect(
      value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('normalizes valid UUID text but rejects zero and malformed values', () {
    expect(
      normalizeCanonicalUuid('  AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA  '),
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    expect(normalizeCanonicalUuid(zeroUuid), isNull);
    expect(normalizeCanonicalUuid('not-an-account'), isNull);
  });
}

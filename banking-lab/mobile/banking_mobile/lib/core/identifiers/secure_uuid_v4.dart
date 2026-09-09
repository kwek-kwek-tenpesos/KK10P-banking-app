import 'dart:math';

final RegExp canonicalUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

const zeroUuid = '00000000-0000-0000-0000-000000000000';

String? normalizeCanonicalUuid(String input) {
  final normalized = input.trim().toLowerCase();
  if (!canonicalUuidPattern.hasMatch(normalized) || normalized == zeroUuid) {
    return null;
  }
  return normalized;
}

String newSecureUuidV4([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

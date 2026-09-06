import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the existing backend token and customer contracts', () {
    final tokens = AuthenticationTokens.fromJson(const {
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'tokenType': 'Bearer',
      'expiresInSeconds': 600,
    });
    final customer = AuthenticatedCustomer.fromJson(const {
      'id': 'customer-id',
      'displayName': 'Chris',
    });

    expect(tokens.accessToken, 'access-token');
    expect(tokens.refreshToken, 'refresh-token');
    expect(tokens.expiresInSeconds, 600);
    expect(customer.id, 'customer-id');
    expect(customer.displayName, 'Chris');
  });

  test('rejects malformed or unexpectedly long-lived token responses', () {
    expect(
      () => AuthenticationTokens.fromJson(const {
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'tokenType': 'bearer',
        'expiresInSeconds': 601,
      }),
      throwsFormatException,
    );
  });

  test('rejects malformed current-customer responses', () {
    expect(
      () => AuthenticatedCustomer.fromJson(const {
        'id': 42,
        'displayName': 'Chris',
      }),
      throwsFormatException,
    );
  });
}

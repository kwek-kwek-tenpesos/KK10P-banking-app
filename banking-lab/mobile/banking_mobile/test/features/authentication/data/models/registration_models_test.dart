import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationRequest', () {
    test('serializes to JSON with all fields', () {
      const request = RegistrationRequest(
        email: 'user@example.test',
        password: 'Password12345!',
        displayName: 'Test User',
      );

      final json = request.toJson();

      expect(json, {
        'email': 'user@example.test',
        'password': 'Password12345!',
        'displayName': 'Test User',
      });
    });

    test('omits empty or null displayName', () {
      const request = RegistrationRequest(
        email: 'user@example.test',
        password: 'Password12345!',
      );

      final json = request.toJson();

      expect(json, {
        'email': 'user@example.test',
        'password': 'Password12345!',
      });
      expect(json.containsKey('displayName'), isFalse);
    });
  });

  group('RegistrationResponse', () {
    test('parses from valid JSON', () {
      final json = {
        'outcome': 0,
        'message':
            'If registration can proceed, check your email for the next step.',
      };

      final response = RegistrationResponse.fromJson(json);

      expect(response.outcome, 0);
      expect(
        response.message,
        'If registration can proceed, check your email for the next step.',
      );
    });

    test('throws FormatException on invalid data', () {
      expect(
        () => RegistrationResponse.fromJson({'outcome': 'not an int'}),
        throwsFormatException,
      );
    });
  });
}

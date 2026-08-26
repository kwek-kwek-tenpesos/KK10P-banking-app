import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemInfo', () {
    test('creates a model from API JSON', () {
      final json = <String, dynamic>{
        'name': 'Banking API',
        'version': 'v1.0.0',
        'environment': 'Development',
      };

      final systemInfo = SystemInfo.fromJson(json);

      expect(systemInfo.name, 'Banking API');
      expect(systemInfo.version, 'v1.0.0');
      expect(systemInfo.environment, 'Development');
    });

    test('throws when a required field is missing', () {
      final incompleteJson = <String, dynamic>{
        'name': 'Banking API',
        'version': 'v1.0.0',
      };

      expect(
        () => SystemInfo.fromJson(incompleteJson),
        throwsA(isA<TypeError>()),
      );
    });
  });
}

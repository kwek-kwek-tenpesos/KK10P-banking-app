import 'package:banking_mobile/features/system_info/data/services/system_info_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemInfoApiService', () {
    test('requests system info and converts the JSON response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));

      addTearDown(() {
        dio.close(force: true);
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(
              options.uri.toString(),
              'http://example.test/api/v1/system/info',
            );

            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'name': 'Banking API',
                  'version': 'v1.0.0',
                  'environment': 'Development',
                },
              ),
            );
          },
        ),
      );

      final service = SystemInfoApiService(dio);

      final systemInfo = await service.fetchSystemInfo();

      expect(systemInfo.name, 'Banking API');
      expect(systemInfo.version, 'v1.0.0');
      expect(systemInfo.environment, 'Development');
    });

    test('throws a FormatException when the response is empty', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));

      addTearDown(() {
        dio.close(force: true);
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: null,
              ),
            );
          },
        ),
      );

      final service = SystemInfoApiService(dio);

      await expectLater(
        service.fetchSystemInfo(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

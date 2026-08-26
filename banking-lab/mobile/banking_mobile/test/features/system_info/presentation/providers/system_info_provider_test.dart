import 'package:banking_mobile/core/network/dio_provider.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('systemInfoProvider', () {
    test('loads system info through the repository', () async {
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

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );

      addTearDown(container.dispose);

      final systemInfo = await container.read(systemInfoProvider.future);

      expect(systemInfo.name, 'Banking API');
      expect(systemInfo.version, 'v1.0.0');
      expect(systemInfo.environment, 'Development');
    });

    test('forwards a network failure as an error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));

      addTearDown(() {
        dio.close(force: true);
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'Test network failure',
              ),
            );
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );

      addTearDown(container.dispose);

      await expectLater(
        container.read(systemInfoProvider.future),
        throwsA(isA<DioException>()),
      );
    });
  });
}

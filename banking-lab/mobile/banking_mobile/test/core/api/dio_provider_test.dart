import 'dart:convert';
import 'dart:typed_data';

import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/errors/client_upgrade_signal.dart';
import 'package:dio/dio.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configures Dio using AppConfig', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://example.test'),
        ),
        clientBuildMetadataProvider.overrideWithValue(
          const ValidClientBuildMetadata(
            ClientBuildInfo(platform: 'ANDROID', build: 27, version: '1.2.3'),
          ),
        ),
      ],
    );

    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio.options.baseUrl, 'http://example.test');
    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 10));
    expect(dio.options.sendTimeout, const Duration(seconds: 10));
    expect(dio.options.headers['Accept'], 'application/json');
    expect(dio.options.headers['X-KK10P-Client-Platform'], 'ANDROID');
    expect(dio.options.headers['X-KK10P-Client-Build'], '27');
  });

  test('a strict late 426 publishes the global update signal', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'https://example.test'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final dio = container.read(dioProvider);
    dio.httpClientAdapter = _UpgradeAdapter();

    await expectLater(
      dio.get<Object>('/late-check'),
      throwsA(isA<DioException>()),
    );

    expect(
      container.read(clientUpgradeSignalProvider),
      isA<ClientUpgradeRequiredFailure>(),
    );
  });
}

class _UpgradeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'code': 'client_upgrade_required',
        'platform': 'ANDROID',
        'currentBuild': 2,
        'minimumBuild': 3,
        'updateUri': 'https://downloads.example.test/kk10p',
      }),
      426,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

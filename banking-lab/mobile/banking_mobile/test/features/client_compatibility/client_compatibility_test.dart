import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/storage/secure_session_store.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_compatibility_result.dart';
import 'package:banking_mobile/features/client_compatibility/data/services/client_compatibility_api_service.dart';
import 'package:banking_mobile/features/client_compatibility/presentation/controllers/client_compatibility_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_app_preferences_store.dart';

const _build = ClientBuildInfo(platform: 'ANDROID', build: 2, version: '1.0.1');

void main() {
  test(
    'local build parsing accepts only canonical positive Android builds',
    () {
      expect(
        ClientBuildInfo.tryParse(
          platform: 'ANDROID',
          build: '2',
          version: '1.0.1',
        )?.build,
        2,
      );
      for (final build in ['0', '+2', '02', '2.0', '1000000000']) {
        expect(
          ClientBuildInfo.tryParse(
            platform: 'ANDROID',
            build: build,
            version: '1.0.1',
          ),
          isNull,
        );
      }
      expect(
        ClientBuildInfo.tryParse(
          platform: 'android',
          build: '2',
          version: '1.0.1',
        ),
        isNull,
      );
    },
  );

  test(
    'compatibility service sends GET and accepts the exact contract',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      late RequestOptions seen;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'platform': 'ANDROID',
                  'currentBuild': 2,
                  'minimumBuild': 2,
                  'updateRequired': false,
                  'updateUri': null,
                },
              ),
            );
          },
        ),
      );

      final result = await DioClientCompatibilityApiService(dio).check(_build);

      expect(seen.method, 'GET');
      expect(seen.path, '/api/v1/client/compatibility');
      expect(result.currentBuild, 2);
      dio.close();
    },
  );

  test('compatibility service rejects HTTP before a request is sent', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5255'));
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (_, handler) => requests++),
    );

    await expectLater(
      DioClientCompatibilityApiService(dio).check(_build),
      throwsA(isA<SecureConnectionRequiredFailure>()),
    );
    expect(requests, 0);
    dio.close();
  });

  test('successful response rejects an oversized update URI', () {
    final result = ClientCompatibilityResult.tryParse({
      'platform': 'ANDROID',
      'currentBuild': 2,
      'minimumBuild': 2,
      'updateRequired': false,
      'updateUri': 'https://downloads.example.test/${'a' * 2050}',
    }, _build);

    expect(result, isNull);
  });

  test(
    'compatibility check completes before session restoration begins',
    () async {
      final gate = Completer<ClientCompatibilityResult>();
      final service = _CompatibilityApi(() => gate.future);
      final repository = _AuthenticationRepository();
      final preferences = AppPreferencesController(MemoryAppPreferencesStore());
      final authentication = AuthenticationController(
        repository,
        preferences,
        restoreAutomatically: false,
      );
      final controller = ClientCompatibilityController(
        const ValidClientBuildMetadata(_build),
        service,
        authentication,
      );
      addTearDown(controller.dispose);
      addTearDown(authentication.dispose);
      addTearDown(preferences.dispose);

      await Future<void>.delayed(Duration.zero);
      expect(service.checks, 1);
      expect(repository.restores, 0);

      gate.complete(
        const ClientCompatibilityResult(currentBuild: 2, minimumBuild: 2),
      );
      await controller.check();

      expect(repository.restores, 1);
      expect(controller.state.status, ClientCompatibilityStatus.supported);
    },
  );

  test(
    'upgrade response blocks restoration and keeps the update URI',
    () async {
      final failure = ClientUpgradeRequiredFailure(
        platform: 'ANDROID',
        currentBuild: 1,
        minimumBuild: 2,
        updateUri: Uri.parse('https://downloads.example.test/kk10p'),
      );
      final service = _CompatibilityApi(() async => throw failure);
      final repository = _AuthenticationRepository();
      final preferences = AppPreferencesController(MemoryAppPreferencesStore());
      final authentication = AuthenticationController(
        repository,
        preferences,
        restoreAutomatically: false,
      );
      final controller = ClientCompatibilityController(
        const ValidClientBuildMetadata(_build),
        service,
        authentication,
      );
      addTearDown(controller.dispose);
      addTearDown(authentication.dispose);
      addTearDown(preferences.dispose);

      await controller.check();

      expect(repository.restores, 0);
      expect(controller.state.status, ClientCompatibilityStatus.updateRequired);
      expect(controller.state.failure, same(failure));
    },
  );
}

class _CompatibilityApi implements ClientCompatibilityApiService {
  _CompatibilityApi(this._check);

  final Future<ClientCompatibilityResult> Function() _check;
  int checks = 0;

  @override
  Future<ClientCompatibilityResult> check(ClientBuildInfo build) {
    checks++;
    return _check();
  }
}

class _AuthenticationRepository extends AuthenticationRepository {
  _AuthenticationRepository() : super(_SessionStore());

  int restores = 0;

  @override
  Future<AuthenticationSession?> restoreSession() async {
    restores++;
    return null;
  }
}

class _SessionStore implements SecureSessionStore {
  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}
}

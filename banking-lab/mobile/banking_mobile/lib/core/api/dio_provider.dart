import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/client_upgrade_signal.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  final metadata = ref.watch(clientBuildMetadataProvider);

  final headers = <String, dynamic>{'Accept': 'application/json'};
  if (metadata case ValidClientBuildMetadata(:final info)) {
    headers['X-KK10P-Client-Platform'] = info.platform;
    headers['X-KK10P-Client-Build'] = info.build.toString();
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: appConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: headers,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        final upgrade = mapClientUpgradeResponse(error.response);
        if (upgrade != null) {
          ref.read(clientUpgradeSignalProvider.notifier).report(upgrade);
        }
        handler.next(error);
      },
    ),
  );

  ref.onDispose(() {
    dio.close(force: true);
  });

  return dio;
});

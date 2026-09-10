import 'package:banking_mobile/app/app.dart';
import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';
import 'package:banking_mobile/features/client_compatibility/presentation/controllers/client_compatibility_controller.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appConfig = AppConfig.fromEnvironment();
  final clientBuildMetadata = await loadClientBuildMetadata();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
        clientBuildMetadataProvider.overrideWithValue(clientBuildMetadata),
        authenticationAutomaticRestoreProvider.overrideWithValue(false),
        clientCompatibilityChecksEnabledProvider.overrideWithValue(true),
      ],
      child: const BankingLabApp(),
    ),
  );
}

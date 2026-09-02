import 'package:banking_mobile/app/app.dart';
import 'package:banking_mobile/core/config/app_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void bootstrap() {
  final appConfig = AppConfig.fromEnvironment();

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(appConfig)],
      child: const BankingLabApp(),
    ),
  );
}

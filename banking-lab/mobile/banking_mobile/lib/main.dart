import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/features/system_info/presentation/screens/system_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  final appConfig = AppConfig.fromEnvironment();

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(appConfig)],
      child: const BankingLabApp(),
    ),
  );
}

class BankingLabApp extends StatelessWidget {
  const BankingLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banking Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SystemInfoScreen(),
    );
  }
}

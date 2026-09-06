import 'package:banking_mobile/app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BankingLabApp extends ConsumerWidget {
  const BankingLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'KK10P Bank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315B7D),
          secondary: const Color(0xFFFF8A4C),
          surface: const Color(0xFFF4F8FC),
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF1F8),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

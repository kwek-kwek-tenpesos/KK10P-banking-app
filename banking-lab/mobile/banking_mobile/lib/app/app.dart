import 'package:banking_mobile/app/app_router.dart';
import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BankingLabApp extends ConsumerWidget {
  const BankingLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesControllerProvider);
    return MaterialApp.router(
      title: 'KK10P Bank',
      debugShowCheckedModeBanner: false,
      theme: KkTheme.light(),
      darkTheme: KkTheme.dark(),
      themeMode: switch (preferences.appearance) {
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
      },
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

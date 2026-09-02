import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widget_previews.dart';

@Preview(name: 'Banking Lab - Phone', size: Size(390, 844))
Widget bankingLabPreview() {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(apiBaseUrl: 'http://preview.invalid'),
      ),
    ],
    child: const BankingLabApp(),
  );
}

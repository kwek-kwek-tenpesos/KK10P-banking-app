import 'package:banking_mobile/core/preferences/app_preferences_provider.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_app_preferences_store.dart';

void main() {
  for (final width in [320.0, 360.0, 412.0, 768.0]) {
    testWidgets('welcome remains scrollable at $width and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesStoreProvider.overrideWithValue(
              MemoryAppPreferencesStore(),
            ),
          ],
          child: MaterialApp(
            theme: KkTheme.light(),
            darkTheme: KkTheme.dark(),
            home: const WelcomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account'));

      expect(find.text('Welcome to KK10P'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/accounts/presentation/widgets/account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  for (final width in [320.0, 360.0, 412.0, 768.0]) {
    for (final scenario in ['unopened', 'loaded', 'error']) {
      testWidgets(
        '$scenario account at width $width and 200% text has no overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = StubAccountsRepository();
          if (scenario == 'loaded') repo.onRead = () async => sampleAccount;
          if (scenario == 'error') {
            repo.onRead = () async => throw const NetworkFailure();
          }
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                accountControllerProvider.overrideWith(
                  (ref) => AccountController(repo, () => true, () async {}),
                ),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1200),
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [AccountCard()],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Simulator funds'), findsOneWidget);
          if (scenario == 'loaded') {
            expect(find.text('PHP 0.00'), findsOneWidget);
          }
          if (scenario == 'unopened') {
            final button = find.widgetWithText(FilledButton, 'Open account');
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            expect(
              tester.getSemantics(button),
              matchesSemantics(
                label: 'Open account',
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                isFocusable: true,
                hasTapAction: true,
                hasFocusAction: true,
              ),
            );
          }
          if (scenario == 'error') expect(find.text('Retry'), findsOneWidget);
          semantics.dispose();
        },
      );
    }
  }
}

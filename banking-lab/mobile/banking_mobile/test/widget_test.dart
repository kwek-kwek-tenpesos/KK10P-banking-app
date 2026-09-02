import 'package:banking_mobile/core/config/app_config.dart';
import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:banking_mobile/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displays system information returned by the provider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://example.test'),
          ),
          systemInfoProvider.overrideWith(
            (ref) async => const SystemInfo(
              name: 'Banking API',
              version: 'v1.0.0',
              environment: 'Test',
            ),
          ),
        ],
        child: const BankingLabApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Banking Lab'), findsOneWidget);
    expect(find.text('Banking API'), findsOneWidget);
    expect(find.text('Version: v1.0.0'), findsOneWidget);
    expect(find.text('Environment: Test'), findsOneWidget);
  });
}

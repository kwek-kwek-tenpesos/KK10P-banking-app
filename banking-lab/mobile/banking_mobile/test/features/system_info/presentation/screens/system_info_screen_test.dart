import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:banking_mobile/features/system_info/presentation/screens/system_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading state while the request is pending', (
    WidgetTester tester,
  ) async {
    final completer = Completer<SystemInfo>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [systemInfoProvider.overrideWith((ref) => completer.future)],
        child: const MaterialApp(home: SystemInfoScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Connecting to the Banking API...'), findsOneWidget);

    completer.complete(
      const SystemInfo(
        name: 'Test API',
        version: 'v1.0.0',
        environment: 'Test',
      ),
    );

    await tester.pumpAndSettle();
  });

  testWidgets('shows an error and retries the request', (
    WidgetTester tester,
  ) async {
    var requestCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemInfoProvider.overrideWith((ref) async {
            requestCount++;
            throw const NetworkFailure();
          }),
        ],
        child: const MaterialApp(home: SystemInfoScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Could not connect to the Banking API.'), findsOneWidget);
    expect(
      find.text(
        'Unable to reach the server. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(requestCount, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
  });
}

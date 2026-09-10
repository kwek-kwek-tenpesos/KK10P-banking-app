import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_controller.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_detail_controller.dart';
import 'package:banking_mobile/features/activity/presentation/activity_time.dart';
import 'package:banking_mobile/features/activity/presentation/screens/activity_detail_screen.dart';
import 'package:banking_mobile/features/activity/presentation/screens/activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'activity_test_support.dart';

void main() {
  testWidgets('Activity list stays reachable at 320px and 200% text', (
    tester,
  ) async {
    final repository = StubActivityRepository();
    final controller = ActivityController(repository, () => true, () async {});
    await _pump(
      tester,
      ProviderScope(
        overrides: [
          activityControllerProvider.overrideWith((_) => controller),
          activityTimeProvider.overrideWithValue(const _FixedActivityTime()),
        ],
        child: const ActivityScreen(),
      ),
      width: 320,
      textScale: 2,
      dark: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Account activity'), findsOneWidget);
    expect(find.text('Transfer sent'), findsOneWidget);
    expect(find.text('-PHP 10.50'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.ensureVisible(find.text('-PHP 10.50'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter sheet exposes only the approved compact filters', (
    tester,
  ) async {
    final controller = ActivityController(
      StubActivityRepository(),
      () => true,
      () async {},
    );
    await _pump(
      tester,
      ProviderScope(
        overrides: [activityControllerProvider.overrideWith((_) => controller)],
        child: const ActivityScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter activity'));
    await tester.pumpAndSettle();
    for (final label in [
      'Direction',
      'Incoming',
      'Outgoing',
      'Type',
      'Funding',
      'Transfers',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Search'), findsNothing);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('historical receipt exposes truthful immutable detail', (
    tester,
  ) async {
    final repository = StubActivityRepository();
    final controller = ActivityDetailController(
      repository,
      transactionId,
      () => true,
      () async {},
    );
    await _pump(
      tester,
      ProviderScope(
        overrides: [
          activityDetailControllerProvider.overrideWith((_, _) => controller),
          activityTimeProvider.overrideWithValue(const _FixedActivityTime()),
        ],
        child: const ActivityDetailScreen(transactionId: transactionId),
      ),
      width: 320,
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('-PHP 10.50'), findsOneWidget);
    expect(find.text(counterpartyReference), findsOneWidget);
    expect(find.text('Balance after'), findsNothing);
    await tester.ensureVisible(
      find.text('Fake-money simulator receipt. No real funds moved.'),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FixedActivityTime extends ActivityTime {
  const _FixedActivityTime();

  @override
  DateTime nowLocal() => DateTime(2026, 9, 10, 12);

  @override
  DateTime toLocal(DateTime utc) => DateTime(2026, 9, 9, 9, 2, 3);
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  double width = 412,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 1000),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: dark ? KkTheme.dark() : KkTheme.light(),
        home: home,
      ),
    ),
  );
}

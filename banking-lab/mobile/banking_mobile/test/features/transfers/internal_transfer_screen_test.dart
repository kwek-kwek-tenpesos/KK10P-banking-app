import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/transfers/presentation/controllers/internal_transfer_controller.dart';
import 'package:banking_mobile/features/transfers/presentation/screens/internal_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/account_test_support.dart';
import 'transfer_test_support.dart';

void main() {
  testWidgets('customer completes the truthful three-step transfer journey', (
    tester,
  ) async {
    final harness = await _pumpTransfer(tester);

    expect(find.text('Step 1 of 3 · Recipient'), findsOneWidget);
    expect(find.text('Other Bank'), findsNothing);
    expect(find.text('Biometrics'), findsNothing);
    expect(find.text('Add note'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('transfer-recipient-field')),
      destinationReference.toUpperCase(),
    );
    await tester.tap(find.text('Continue to amount'));
    await tester.pump();
    expect(find.text('Step 2 of 3 · Amount'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('transfer-amount-field')),
      '10.50',
    );
    await tester.tap(find.text('Review transfer'));
    await tester.pump();
    expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
    expect(find.text('PHP 10.50'), findsOneWidget);
    expect(find.text('Fee'), findsNothing);
    expect(find.text('Settlement'), findsNothing);

    await tester.tap(find.byKey(const Key('confirm-transfer-button')));
    await tester.pumpAndSettle();
    expect(find.text('Transfer complete'), findsOneWidget);
    expect(find.byKey(const Key('transfer-receipt-amount')), findsOneWidget);
    expect(harness.repository.requests, hasLength(1));
    expect(harness.store.values, isEmpty);
  });

  testWidgets('invalid self recipient focuses a clear inline error', (
    tester,
  ) async {
    await _pumpTransfer(tester);
    await tester.enterText(
      find.byKey(const Key('transfer-recipient-field')),
      sourceReference,
    );
    await tester.tap(find.text('Continue to amount'));
    await tester.pump();
    expect(find.text('Choose another simulator account.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('transfer-recipient-field')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('restored uncertainty offers same-request reconciliation', (
    tester,
  ) async {
    final store = MemoryPendingTransferStore();
    store.values[customerId] = samplePending();
    final harness = await _pumpTransfer(tester, store: store);
    expect(find.text('Transfer status unconfirmed'), findsOneWidget);
    expect(find.text('Check transfer status'), findsOneWidget);
    await tester.tap(find.text('Check transfer status'));
    await tester.pumpAndSettle();
    expect(find.text('Transfer complete'), findsOneWidget);
    expect(harness.repository.requests.single.idempotencyKey, idempotencyKey);
  });

  for (final theme in [('light', KkTheme.light()), ('dark', KkTheme.dark())]) {
    testWidgets(
      '${theme.$1} journey remains reachable at 320px and 200% text',
      (tester) async {
        await _pumpTransfer(
          tester,
          width: 320,
          height: 1600,
          textScale: 2,
          theme: theme.$2,
        );
        expect(tester.takeException(), isNull);
        final action = find.text('Continue to amount');
        await tester.ensureVisible(action);
        await tester.pump();
        expect(action, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<_TransferHarness> _pumpTransfer(
  WidgetTester tester, {
  MemoryPendingTransferStore? store,
  double width = 412,
  double height = 1200,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = StubInternalTransferRepository();
  final recoveryStore = store ?? MemoryPendingTransferStore();
  final transferController = InternalTransferController(
    repository,
    recoveryStore,
    customerId,
    () => true,
    () async {},
    () {},
    newId: () => idempotencyKey,
    now: () => DateTime.utc(2026, 9, 9),
  );
  final accountRepository = StubAccountsRepository()
    ..onRead = () async => fundedAccount;
  final accountController = AccountController(
    accountRepository,
    () => true,
    () async {},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        internalTransferControllerProvider.overrideWith(
          (ref) => transferController,
        ),
        accountControllerProvider.overrideWith((ref) => accountController),
      ],
      child: MaterialApp(
        theme: theme ?? KkTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const InternalTransferScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _TransferHarness(repository, recoveryStore);
}

final fundedAccount = AccountSummary(
  id: sourceReference,
  currency: 'PHP',
  balanceMinor: BigInt.from(100000),
  openedAtUtc: DateTime.utc(2026, 9, 6),
);

class _TransferHarness {
  const _TransferHarness(this.repository, this.store);
  final StubInternalTransferRepository repository;
  final MemoryPendingTransferStore store;
}

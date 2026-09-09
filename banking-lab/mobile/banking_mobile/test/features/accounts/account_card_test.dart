import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/accounts/presentation/widgets/account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  for (final theme in [('light', KkTheme.light()), ('dark', KkTheme.dark())]) {
    for (final width in [320.0, 360.0, 412.0, 768.0]) {
      for (final scenario in ['unopened', 'loaded', 'error']) {
        testWidgets(
          '${theme.$1} $scenario account at width $width and 200% text has no overflow',
          (tester) async {
            final repo = StubAccountsRepository();
            if (scenario == 'loaded') repo.onRead = () async => sampleAccount;
            if (scenario == 'error') {
              repo.onRead = () async => throw const NetworkFailure();
            }
            await _pumpAccountCard(
              tester,
              repo: repo,
              width: width,
              textScale: 2,
              theme: theme.$2,
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Simulator funds'), findsOneWidget);
            if (scenario == 'loaded') {
              expect(find.text('PHP 0.00'), findsOneWidget);
              expect(
                find.byKey(const Key('simulator-account-reference')),
                findsOneWidget,
              );
            }
            if (scenario == 'unopened') {
              final button = find.widgetWithText(
                FilledButton,
                'Open simulator account',
              );
              await tester.ensureVisible(button);
              await tester.pump();
              expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
              expect(
                tester.getSemantics(button),
                matchesSemantics(
                  label: 'Open simulator account',
                  isButton: true,
                  hasEnabledState: true,
                  isEnabled: true,
                  isFocusable: true,
                  hasTapAction: true,
                  hasFocusAction: true,
                ),
              );
            }
            if (scenario == 'error') {
              expect(find.text('Couldn’t load account'), findsOneWidget);
              expect(find.text('Retry loading account'), findsOneWidget);
            }
          },
        );
      }
    }
  }

  testWidgets('loaded balance can be hidden and revealed accessibly', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repo = StubAccountsRepository()..onRead = () async => sampleAccount;
    await _pumpAccountCard(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('PHP 0.00'), findsOneWidget);
    final hide = find.byTooltip('Hide simulator balance, balance visible');
    expect(hide, findsOneWidget);
    await tester.tap(hide);
    await tester.pump();

    expect(find.text('PHP 0.00'), findsNothing);
    expect(find.text('PHP ••••••'), findsOneWidget);
    final show = find.byTooltip('Show simulator balance, balance hidden');
    expect(show, findsOneWidget);
    expect(
      tester.getSemantics(show),
      matchesSemantics(
        tooltip: 'Show simulator balance, balance hidden',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(show);
    await tester.pump();
    expect(find.text('PHP 0.00'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('opening and reconciliation have distinct stable progress', (
    tester,
  ) async {
    final openGate = Completer<AccountSummary>();
    final repo = StubAccountsRepository()..onOpen = () => openGate.future;
    await _pumpAccountCard(tester, repo: repo);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open simulator account'));
    await tester.pump();
    expect(find.text('Opening simulator account…'), findsWidgets);
    expect(repo.opens, 1);

    openGate.completeError(const TimeoutFailure());
    await tester.pumpAndSettle();
    expect(find.text('Account opening unconfirmed'), findsOneWidget);
    expect(find.text('Check account status'), findsOneWidget);

    final readGate = Completer<AccountSummary?>();
    repo.onRead = () => readGate.future;
    await tester.tap(find.text('Check account status'));
    await tester.pump();
    expect(find.text('Checking account status…'), findsWidgets);
    expect(repo.opens, 1);

    readGate.complete(sampleAccount);
    await tester.pumpAndSettle();
    expect(find.text('PHP 0.00'), findsOneWidget);
    expect(repo.opens, 1);
  });

  testWidgets('account card never exposes unsupported prototype actions', (
    tester,
  ) async {
    final repo = StubAccountsRepository()..onRead = () async => sampleAccount;
    await _pumpAccountCard(tester, repo: repo);
    await tester.pumpAndSettle();

    for (final unsupported in [
      'Quick Send',
      'Transfer',
      'Pay Bills',
      'Recent transactions',
      'View All (6)',
    ]) {
      expect(find.text(unsupported), findsNothing);
    }
  });

  testWidgets('loaded account exposes working transfer and copy actions', (
    tester,
  ) async {
    final repo = StubAccountsRepository()..onRead = () async => sampleAccount;
    var transfers = 0;
    Object? clipboardArguments;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardArguments = call.arguments;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpAccountCard(tester, repo: repo, onTransfer: () => transfers++);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer funds'));
    expect(transfers, 1);
    await tester.tap(find.text('Copy account reference'));
    await tester.pumpAndSettle();
    expect(clipboardArguments, {'text': sampleAccount.id});
    expect(find.text('Simulator account reference copied.'), findsOneWidget);
  });
}

Future<void> _pumpAccountCard(
  WidgetTester tester, {
  required StubAccountsRepository repo,
  double width = 412,
  double textScale = 1,
  ThemeData? theme,
  VoidCallback? onTransfer,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountControllerProvider.overrideWith(
          (ref) => AccountController(repo, () => true, () async {}),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? KkTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1200),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(KkSpacing.lg),
              child: AccountCard(onTransfer: onTransfer),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  test('loading then explicit opening ignores duplicate taps', () async {
    final repo = StubAccountsRepository();
    final controller = AccountController(repo, () => true, () async {});
    addTearDown(controller.dispose);
    expect(controller.state.status, AccountStatus.loading);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AccountStatus.unopened);
    final gate = Completer<AccountSummary>();
    repo.onOpen = () => gate.future;
    final opening = controller.open();
    await controller.open();
    expect(controller.state.status, AccountStatus.opening);
    expect(repo.opens, 1);
    gate.complete(sampleAccount);
    await opening;
    expect(controller.state.account, sampleAccount);
  });

  test('rapid balance refreshes share the active read', () async {
    final repo = StubAccountsRepository()..onRead = () async => sampleAccount;
    final controller = AccountController(repo, () => true, () async {});
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AccountStatus.loaded);

    final gate = Completer<AccountSummary?>();
    repo.onRead = () => gate.future;
    final first = controller.load();
    await controller.load();
    expect(controller.state.status, AccountStatus.loading);
    expect(repo.reads, 2);

    gate.complete(sampleAccount);
    await first;
    expect(controller.state.status, AccountStatus.loaded);
    expect(repo.reads, 2);
  });

  test('uncertain opening is distinct and reconciles GET before PUT', () async {
    final repo = StubAccountsRepository()
      ..onOpen = () async => throw const TimeoutFailure();
    final controller = AccountController(repo, () => true, () async {});
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    await controller.open();
    expect(controller.state.status, AccountStatus.openingUnconfirmed);
    expect(controller.state.message, isNotEmpty);

    final gate = Completer<AccountSummary?>();
    repo.onRead = () => gate.future;
    final retry = controller.retry();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AccountStatus.reconcilingOpen);
    expect(repo.opens, 1);
    expect(repo.reads, 2);

    gate.complete(sampleAccount);
    await retry;
    expect(controller.state.status, AccountStatus.loaded);
    expect(repo.opens, 1);
    expect(repo.reads, 2);
  });

  test(
    'reconciliation repeats idempotent PUT only after GET finds none',
    () async {
      final repo = StubAccountsRepository()
        ..onOpen = () async => throw const TimeoutFailure();
      final controller = AccountController(repo, () => true, () async {});
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      await controller.open();

      repo.onRead = () async => null;
      repo.onOpen = () async => sampleAccount;
      await controller.retry();

      expect(controller.state.status, AccountStatus.loaded);
      expect(repo.reads, 2);
      expect(repo.opens, 2);
    },
  );

  test(
    'outages preserve retry state; definitive 401 invalidates session',
    () async {
      var invalidated = 0;
      final repo = StubAccountsRepository()
        ..onRead = () async => throw const NetworkFailure();
      final controller = AccountController(repo, () => true, () async {
        invalidated++;
      });
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, AccountStatus.error);
      expect(invalidated, 0);
      repo.onRead = () async => throw const UnauthenticatedFailure();
      await controller.retry();
      expect(invalidated, 1);
    },
  );

  test('disposed controller ignores late results', () async {
    final gate = Completer<AccountSummary?>();
    final repo = StubAccountsRepository()..onRead = () => gate.future;
    final controller = AccountController(repo, () => true, () async {});
    controller.dispose();
    gate.complete(sampleAccount);
    await Future<void>.delayed(Duration.zero);
    expect(repo.opens, 0);
  });
}

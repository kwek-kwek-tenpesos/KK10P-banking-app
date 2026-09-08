import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/development_funding/data/models/development_funding_receipt.dart';
import 'package:banking_mobile/features/development_funding/data/repositories/development_funding_repository.dart';
import 'package:banking_mobile/features/development_funding/presentation/controllers/development_funding_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncertain retry reuses its key and refreshes account once', () async {
    final repository = StubFundingRepository();
    var refreshes = 0;
    final controller = DevelopmentFundingController(
      repository,
      () => true,
      () async {},
      () => refreshes++,
    );
    repository.onFund = (_) async => throw const NetworkFailure();
    await controller.fund();
    expect(controller.state.canRetrySameRequest, isTrue);
    final firstKey = repository.keys.single;
    expect(
      firstKey,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    repository.onFund = (_) async => sampleReceipt;
    await controller.fund();
    expect(repository.keys, [firstKey, firstKey]);
    expect(controller.state.status, DevelopmentFundingStatus.success);
    expect(refreshes, 1);
    controller.dispose();
  });

  test(
    'rapid taps stay single-flight and a definitive failure gets a new key',
    () async {
      final repository = StubFundingRepository();
      final gate = Completer<DevelopmentFundingReceipt>();
      repository.onFund = (_) => gate.future;
      final controller = DevelopmentFundingController(
        repository,
        () => true,
        () async {},
        () {},
      );
      final first = controller.fund();
      final ignored = controller.fund();
      await Future<void>.delayed(Duration.zero);
      expect(repository.keys, hasLength(1));
      gate.complete(sampleReceipt);
      await Future.wait([first, ignored]);

      repository.onFund = (_) async =>
          throw const DevelopmentFundingLimitFailure();
      await controller.fund();
      final rejectedKey = repository.keys.last;
      expect(controller.state.canRetrySameRequest, isFalse);
      repository.onFund = (_) async => sampleReceipt;
      await controller.fund();
      expect(repository.keys.last, isNot(rejectedKey));
      controller.dispose();
    },
  );
}

final sampleReceipt = DevelopmentFundingReceipt(
  transactionId: '11111111-1111-4111-8111-111111111111',
  accountId: '22222222-2222-4222-8222-222222222222',
  currency: 'PHP',
  creditedAmountMinor: 5000000,
  balanceAfterMinor: 5000000,
  createdAtUtc: DateTime.utc(2026, 9, 8),
  replayed: false,
);

class StubFundingRepository implements DevelopmentFundingRepository {
  Future<DevelopmentFundingReceipt> Function(String)? onFund;
  final keys = <String>[];

  @override
  Future<DevelopmentFundingReceipt> fund(String idempotencyKey) async {
    keys.add(idempotencyKey);
    return onFund == null ? sampleReceipt : await onFund!(idempotencyKey);
  }
}

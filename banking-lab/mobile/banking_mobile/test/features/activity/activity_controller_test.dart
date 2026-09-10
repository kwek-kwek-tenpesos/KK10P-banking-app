import 'dart:async';

import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_controller.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'activity_test_support.dart';

void main() {
  test('rapid refreshes remain single-flight', () async {
    final gate = Completer<ActivityPage>();
    final repository = StubActivityRepository()
      ..onReadPage = (_, _) => gate.future;
    final controller = ActivityController(repository, () => true, () async {});
    await Future<void>.delayed(Duration.zero);
    final ignored = controller.refresh();
    expect(repository.pageRequests, hasLength(1));
    gate.complete(ActivityPage(items: [sampleActivityItem]));
    await ignored;
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, ActivityStatus.loaded);
    controller.dispose();
  });

  test('filters replace old results and pagination appends uniquely', () async {
    final second = ActivityItem.fromJson({
      ...activityItemJson,
      'transactionId': secondTransactionId,
    });
    final repository = StubActivityRepository()
      ..onReadPage = (filters, cursor) async => cursor == null
          ? ActivityPage(items: [sampleActivityItem], nextCursor: 'next')
          : ActivityPage(items: [second]);
    final controller = ActivityController(repository, () => true, () async {});
    await _settle();
    await controller.loadMore();
    expect(controller.state.items, hasLength(2));
    await controller.applyFilters(
      const ActivityFilters(direction: ActivityDirection.incoming),
    );
    expect(controller.state.items, hasLength(1));
    expect(
      repository.pageRequests.last.$1.direction,
      ActivityDirection.incoming,
    );
    controller.dispose();
  });

  test(
    'load-more failure preserves visible history and offers retry',
    () async {
      var first = true;
      final repository = StubActivityRepository()
        ..onReadPage = (_, cursor) async {
          if (first) {
            first = false;
            return ActivityPage(
              items: [sampleActivityItem],
              nextCursor: 'next',
            );
          }
          throw const NetworkFailure();
        };
      final controller = ActivityController(
        repository,
        () => true,
        () async {},
      );
      await _settle();
      await controller.loadMore();
      expect(controller.state.status, ActivityStatus.loaded);
      expect(controller.state.items, [sampleActivityItem]);
      expect(controller.state.nextCursor, 'next');
      expect(controller.state.message, contains('connection'));
      controller.dispose();
    },
  );

  test(
    'detail validates and canonicalizes the route reference locally',
    () async {
      final repository = StubActivityRepository();
      final invalid = ActivityDetailController(
        repository,
        'not-a-transaction',
        () => true,
        () async {},
      );
      await _settle();
      expect(invalid.state.status, ActivityDetailStatus.notFound);
      expect(repository.detailRequests, isEmpty);
      invalid.dispose();

      final uppercase = ActivityDetailController(
        repository,
        transactionId.toUpperCase(),
        () => true,
        () async {},
      );
      await _settle();
      expect(uppercase.state.status, ActivityDetailStatus.loaded);
      expect(repository.detailRequests, [transactionId]);
      uppercase.dispose();
    },
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

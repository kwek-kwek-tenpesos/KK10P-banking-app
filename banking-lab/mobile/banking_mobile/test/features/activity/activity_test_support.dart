import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/data/repositories/activity_repository.dart';

const transactionId = '11111111-1111-4111-8111-111111111111';
const secondTransactionId = '22222222-2222-4222-8222-222222222222';
const accountReference = '33333333-3333-4333-8333-333333333333';
const counterpartyReference = '44444444-4444-4444-8444-444444444444';

const activityItemJson = <String, dynamic>{
  'transactionId': transactionId,
  'type': 'INTERNAL_TRANSFER',
  'direction': 'OUTGOING',
  'currency': 'PHP',
  'amountMinor': '1050',
  'status': 'COMPLETED',
  'occurredAtUtc': '2026-09-09T01:02:03Z',
  'counterpartyType': 'KK10P_ACCOUNT',
  'counterpartyReferenceSuffix': '12344444',
};

const activityDetailJson = <String, dynamic>{
  'transactionId': transactionId,
  'type': 'INTERNAL_TRANSFER',
  'direction': 'OUTGOING',
  'currency': 'PHP',
  'amountMinor': '1050',
  'status': 'COMPLETED',
  'occurredAtUtc': '2026-09-09T01:02:03Z',
  'accountReference': accountReference,
  'counterpartyType': 'KK10P_ACCOUNT',
  'counterpartyAccountReference': counterpartyReference,
};

final sampleActivityItem = ActivityItem.fromJson(activityItemJson);
final sampleActivityDetail = ActivityDetail.fromJson(activityDetailJson);

class StubActivityRepository implements ActivityRepository {
  Future<ActivityPage> Function(ActivityFilters, String?)? onReadPage;
  Future<ActivityDetail> Function(String)? onReadDetail;
  final pageRequests = <(ActivityFilters, String?)>[];
  final detailRequests = <String>[];

  @override
  Future<ActivityPage> readPage({
    ActivityFilters filters = const ActivityFilters(),
    String? cursor,
  }) async {
    pageRequests.add((filters, cursor));
    return onReadPage == null
        ? ActivityPage(items: [sampleActivityItem])
        : await onReadPage!(filters, cursor);
  }

  @override
  Future<ActivityDetail> readDetail(String id) async {
    detailRequests.add(id);
    return onReadDetail == null
        ? sampleActivityDetail
        : await onReadDetail!(id);
  }
}

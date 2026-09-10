import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityTime {
  const ActivityTime();

  DateTime nowLocal() => DateTime.now();

  DateTime toLocal(DateTime utc) => utc.toLocal();
}

final activityTimeProvider = Provider<ActivityTime>(
  (_) => const ActivityTime(),
);

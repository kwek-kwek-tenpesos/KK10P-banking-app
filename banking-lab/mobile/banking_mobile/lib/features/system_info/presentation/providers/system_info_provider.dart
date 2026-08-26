import 'package:banking_mobile/features/system_info/data/models/system_info.dart';
import 'package:banking_mobile/features/system_info/data/repositories/system_info_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final systemInfoProvider = FutureProvider<SystemInfo>((ref) async {
  final repository = ref.watch(systemInfoRepositoryProvider);

  return repository.getSystemInfo();
});

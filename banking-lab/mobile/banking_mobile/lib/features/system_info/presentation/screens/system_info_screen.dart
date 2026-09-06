import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/registration_screen.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemInfoScreen extends ConsumerWidget {
  const SystemInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemInfoAsync = ref.watch(systemInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('KK10P Bank')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: systemInfoAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to the Banking API...'),
                ],
              ),
            ),
            data: (systemInfo) => Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 56),
                      SizedBox(height: 16),
                      Text(
                        systemInfo.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Text('Version: ${systemInfo.version}'),
                      SizedBox(height: 8),
                      Text('Environment: ${systemInfo.environment}'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RegistrationScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Create Account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            error: (error, stackTrace) {
              late final AppFailure failure;

              if (error is AppFailure) {
                failure = error;
              } else {
                failure = const UnexpectedFailure();
              }

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color: Theme.of(context).colorScheme.error,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not connect to the Banking API.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(failure.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        ref.invalidate(systemInfoProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

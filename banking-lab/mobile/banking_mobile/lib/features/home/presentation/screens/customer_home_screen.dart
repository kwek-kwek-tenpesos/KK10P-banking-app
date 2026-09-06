import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/accounts/presentation/widgets/account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authenticationControllerProvider);
    final customer = state.customer;
    final displayName = customer?.displayName?.trim();
    final greetingName = displayName == null || displayName.isEmpty
        ? 'Customer'
        : displayName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KK10P Bank'),
        actions: [
          IconButton(
            tooltip: 'API diagnostics',
            onPressed: () => context.push('/diagnostics'),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Hello, $greetingName',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Your authenticated simulator session is active.'),
            const SizedBox(height: 24),
            if (state.isAuthenticated) const AccountCard(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: state.isSubmitting
                  ? null
                  : () => ref
                        .read(authenticationControllerProvider.notifier)
                        .logout(),
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

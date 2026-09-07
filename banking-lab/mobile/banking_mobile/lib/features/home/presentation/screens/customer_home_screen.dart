import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
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
      body: KkPageBody(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hello, $greetingName',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: KkSpacing.xs),
            Text(
              'Your authenticated simulator session is active.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: KkSpacing.lg),
            if (state.isAuthenticated) const AccountCard(),
            const SizedBox(height: KkSpacing.lg),
            KkEmbossedButton(
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

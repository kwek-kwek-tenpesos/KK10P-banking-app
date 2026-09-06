import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountControllerProvider);
    final controller = ref.read(accountControllerProvider.notifier);
    final account = state.account;
    return Card(
      elevation: 0,
      color: const Color(0xFFF0F5FA),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: Color(0xFF172B4D),
            ),
            const SizedBox(height: 12),
            Text(
              'Simulator funds',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: const Color(0xFF172B4D)),
            ),
            const SizedBox(height: 12),
            if (state.busy) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Loading simulator account',
              ),
              const SizedBox(height: 12),
              Text(
                state.status == AccountStatus.opening
                    ? 'Opening your account…'
                    : 'Loading your account…',
              ),
            ] else if (state.status == AccountStatus.unopened) ...[
              const Text(
                'Open your PHP simulator account with PHP 0.00. Funding and transfers will arrive in a later feature.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA8430A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: controller.open,
                child: const Text('Open account'),
              ),
            ] else if (account != null) ...[
              Text(
                account.formattedBalance,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: const Color(0xFF172B4D)),
              ),
              const SizedBox(height: 12),
              const Text('Simulator account reference'),
              SelectableText(account.id),
              const SizedBox(height: 12),
              const Text(
                'Fake money only. Funding and transfers will arrive in a later feature.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh balance'),
              ),
            ] else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  state.message ?? 'Account information is unavailable.',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: controller.retry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

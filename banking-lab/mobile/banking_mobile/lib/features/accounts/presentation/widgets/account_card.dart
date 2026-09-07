import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
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
    return KkSoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KkIconTile(
            icon: Icons.account_balance_wallet_outlined,
            size: 32,
          ),
          const SizedBox(height: KkSpacing.lg),
          Text(
            'Simulator funds',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: KkColors.navy, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: KkSpacing.sm),
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
            KkEmbossedButton(
              variant: KkEmbossedButtonVariant.primary,
              onPressed: controller.open,
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Open account'),
            ),
          ] else if (account != null) ...[
            Text(
              account.formattedBalance,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: KkColors.navy, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('Simulator account reference'),
            SelectableText(account.id),
            const SizedBox(height: 12),
            const Text(
              'Fake money only. Funding and transfers will arrive in a later feature.',
            ),
            const SizedBox(height: 12),
            KkEmbossedButton(
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
            KkEmbossedButton(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

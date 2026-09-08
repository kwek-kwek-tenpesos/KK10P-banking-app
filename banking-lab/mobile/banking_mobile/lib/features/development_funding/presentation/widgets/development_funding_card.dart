import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/development_funding/presentation/controllers/development_funding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevelopmentFundingCard extends ConsumerWidget {
  const DevelopmentFundingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(developmentFundingControllerProvider);
    final receipt = state.receipt;
    return KkSoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Development simulator funds',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Add PHP 50,000 of test money to your opened account. '
            'The Development allowance is PHP 100,000 per Philippine calendar day.',
          ),
          const SizedBox(height: 8),
          Text(
            'Simulator only — this is not real money and cannot leave KK10P.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (receipt != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: KkSoftSurface(
                style: KkSurfaceStyle.flat,
                padding: const EdgeInsets.all(14),
                child: Text(
                  receipt.replayed
                      ? 'Request reconciled. Balance remains ${_formatMinor(receipt.balanceAfterMinor)}.'
                      : 'Added ${_formatMinor(receipt.creditedAmountMinor)}. '
                            'Balance: ${_formatMinor(receipt.balanceAfterMinor)}.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (state.message case final message?) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 18),
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.primary,
            onPressed: state.busy ? null : () => _confirmAndFund(context, ref),
            icon: state.busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_card_outlined),
            label: Text(
              state.canRetrySameRequest
                  ? 'Retry same request'
                  : 'Add PHP 50,000 test funds',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndFund(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add simulator funds?'),
        content: const Text(
          'This adds PHP 50,000 in test money. A maximum of PHP 100,000 '
          'can be added to this account per Philippine calendar day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add test funds'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(developmentFundingControllerProvider.notifier).fund();
    }
  }

  static String _formatMinor(int minor) {
    final whole = (minor ~/ 100).toString();
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'PHP $grouped.${(minor % 100).toString().padLeft(2, '0')}';
  }
}

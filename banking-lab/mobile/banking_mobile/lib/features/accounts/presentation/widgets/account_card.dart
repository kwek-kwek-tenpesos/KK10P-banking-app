import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key, this.onTransfer});

  final VoidCallback? onTransfer;

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountControllerProvider);
    final controller = ref.read(accountControllerProvider.notifier);
    final account = state.account;

    return KkSoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AccountHeader(
            balanceVisible: _balanceVisible,
            showPrivacyControl:
                state.status == AccountStatus.loaded && account != null,
            onToggleBalance: () {
              setState(() => _balanceVisible = !_balanceVisible);
            },
          ),
          const SizedBox(height: KkSpacing.lg),
          switch (state.status) {
            AccountStatus.loading => const _AccountProgress(
              semanticsLabel: 'Loading simulator account',
              message: 'Loading your account…',
            ),
            AccountStatus.unopened => _UnopenedAccount(onOpen: controller.open),
            AccountStatus.opening => const _AccountProgress(
              semanticsLabel: 'Opening simulator account',
              message: 'Opening simulator account…',
              actionLabel: 'Opening simulator account…',
            ),
            AccountStatus.reconcilingOpen => const _AccountProgress(
              semanticsLabel: 'Checking simulator account status',
              message: 'Checking account status…',
              actionLabel: 'Checking account status…',
            ),
            AccountStatus.openingUnconfirmed => _AccountFailure(
              title: 'Account opening unconfirmed',
              message: state.message,
              explanation: 'The request may have reached the server. Check account status before trying to open it again.',
              actionLabel: 'Check account status',
              onRetry: controller.retry,
            ),
            AccountStatus.loaded when account != null => _LoadedAccount(
              account: account,
              balanceVisible: _balanceVisible,
              onRefresh: controller.load,
              onTransfer: widget.onTransfer,
              onCopyReference: () => _copyReference(account.id),
            ),
            AccountStatus.loaded || AccountStatus.error => _AccountFailure(
              title: 'Couldn’t load account',
              message: state.message,
              explanation: 'Your simulator account information is temporarily unavailable.',
              actionLabel: 'Retry loading account',
              onRetry: controller.retry,
            ),
          },
        ],
      ),
    );
  }

  Future<void> _copyReference(String reference) async {
    try {
      await Clipboard.setData(ClipboardData(text: reference));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Simulator account reference copied.')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn\u2019t copy the simulator account reference.',
            ),
          ),
        );
    }
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.balanceVisible,
    required this.showPrivacyControl,
    required this.onToggleBalance,
  });

  final bool balanceVisible;
  final bool showPrivacyControl;
  final VoidCallback onToggleBalance;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: KkIconTile(
            icon: Icons.account_balance_wallet_outlined,
            size: 32,
          ),
        ),
        const SizedBox(width: KkSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulator funds',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: KkSpacing.xs),
              Text(
                'PHP simulator account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showPrivacyControl) ...[
          const SizedBox(width: KkSpacing.xs),
          IconButton(
            key: const Key('balance-privacy-button'),
            tooltip: balanceVisible
                ? 'Hide simulator balance, balance visible'
                : 'Show simulator balance, balance hidden',
            onPressed: onToggleBalance,
            icon: Icon(
              balanceVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountProgress extends StatelessWidget {
  const _AccountProgress({
    required this.semanticsLabel,
    required this.message,
    this.actionLabel,
  });

  final String semanticsLabel;
  final String message;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(semanticsLabel: semanticsLabel),
          const SizedBox(height: KkSpacing.sm),
          Text(message),
          if (actionLabel case final label?) ...[
            const SizedBox(height: KkSpacing.md),
            KkEmbossedButton(
              variant: KkEmbossedButtonVariant.primary,
              onPressed: null,
              icon: const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnopenedAccount extends StatelessWidget {
  const _UnopenedAccount({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No simulator account yet',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: KkSpacing.xs),
        Text(
          'Open one PHP simulator account. It starts at PHP 0.00 and never contains real money.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: KkSpacing.md),
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.primary,
          onPressed: onOpen,
          icon: const Icon(Icons.add_card_outlined),
          label: const Text('Open simulator account'),
        ),
      ],
    );
  }
}

class _LoadedAccount extends StatelessWidget {
  const _LoadedAccount({
    required this.account,
    required this.balanceVisible,
    required this.onRefresh,
    required this.onTransfer,
    required this.onCopyReference,
  });

  final AccountSummary account;
  final bool balanceVisible;
  final VoidCallback onRefresh;
  final VoidCallback? onTransfer;
  final VoidCallback onCopyReference;

  @override
  Widget build(BuildContext context) {
    final amount = balanceVisible
        ? account.formattedBalance
        : '${account.currency} ••••••';
    final amountLabel = balanceVisible
        ? 'Simulator balance ${account.formattedBalance}'
        : 'Simulator balance hidden';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: amountLabel,
          child: ExcludeSemantics(
            child: Text(
              amount,
              key: const Key('simulator-balance'),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: KkSpacing.lg),
        Text(
          'Simulator account reference',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: KkSpacing.xs),
        SelectableText(
          account.id,
          key: const Key('simulator-account-reference'),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: KkSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onCopyReference,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy account reference'),
          ),
        ),
        const SizedBox(height: KkSpacing.lg),
        if (onTransfer != null) ...[
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.primary,
            onPressed: onTransfer,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Transfer funds'),
          ),
          const SizedBox(height: KkSpacing.sm),
        ],
        KkEmbossedButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh balance'),
        ),
      ],
    );
  }
}

class _AccountFailure extends StatelessWidget {
  const _AccountFailure({
    required this.title,
    required this.message,
    required this.explanation,
    required this.actionLabel,
    required this.onRetry,
  });

  final String title;
  final String? message;
  final String explanation;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: KkSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KkSpacing.sm),
          Text(message ?? 'Account information is unavailable.'),
          const SizedBox(height: KkSpacing.xs),
          Text(
            explanation,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: KkSpacing.md),
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.primary,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:banking_mobile/features/accounts/presentation/controllers/account_controller.dart';
import 'package:banking_mobile/features/transfers/domain/internal_transfer_amount.dart';
import 'package:banking_mobile/features/transfers/presentation/controllers/internal_transfer_controller.dart';
import 'package:banking_mobile/features/transfers/presentation/widgets/internal_transfer_receipt_card.dart';
import 'package:banking_mobile/features/transfers/presentation/widgets/internal_transfer_step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class InternalTransferScreen extends ConsumerStatefulWidget {
  const InternalTransferScreen({super.key});

  @override
  ConsumerState<InternalTransferScreen> createState() =>
      _InternalTransferScreenState();
}

class _InternalTransferScreenState
    extends ConsumerState<InternalTransferScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _recipientFocus = FocusNode();
  final _amountFocus = FocusNode();

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _recipientFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transfer = ref.watch(internalTransferControllerProvider);
    final accountState = ref.watch(accountControllerProvider);
    ref.listen<InternalTransferState>(internalTransferControllerProvider, (
      previous,
      next,
    ) {
      _synchronize(_recipientController, next.recipientInput);
      _synchronize(_amountController, next.amountInput);
      if (next.recipientError != null &&
          next.recipientError != previous?.recipientError) {
        _focusAfterBuild(_recipientFocus);
      } else if (next.amountError != null &&
          next.amountError != previous?.amountError) {
        _focusAfterBuild(_amountFocus);
      }
    });

    final account = accountState.account;
    return PopScope(
      canPop: !transfer.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transfer simulator funds')),
        body: KkPageBody(
          maxWidth: 560,
          child: account == null
              ? _AccountUnavailable(state: accountState)
              : _TransferBody(
                  state: transfer,
                  account: account,
                  recipientController: _recipientController,
                  amountController: _amountController,
                  recipientFocus: _recipientFocus,
                  amountFocus: _amountFocus,
                ),
        ),
      ),
    );
  }

  static void _synchronize(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  static void _focusAfterBuild(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (node.canRequestFocus) node.requestFocus();
    });
  }
}

class _TransferBody extends ConsumerWidget {
  const _TransferBody({
    required this.state,
    required this.account,
    required this.recipientController,
    required this.amountController,
    required this.recipientFocus,
    required this.amountFocus,
  });

  final InternalTransferState state;
  final AccountSummary account;
  final TextEditingController recipientController;
  final TextEditingController amountController;
  final FocusNode recipientFocus;
  final FocusNode amountFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(internalTransferControllerProvider.notifier);
    if (state.status == InternalTransferStatus.restoring) {
      return const _ProgressPanel(message: 'Checking transfer recovery…');
    }
    if (state.status == InternalTransferStatus.persisting) {
      return const _ProgressPanel(message: 'Securing this transfer request…');
    }
    if (state.status == InternalTransferStatus.submitting) {
      return const _ProgressPanel(message: 'Confirming your transfer…');
    }
    if (state.status == InternalTransferStatus.success &&
        state.receipt != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InternalTransferReceiptCard(receipt: state.receipt!),
          const SizedBox(height: KkSpacing.lg),
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.primary,
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.done),
            label: const Text('Done'),
          ),
        ],
      );
    }
    if (state.status == InternalTransferStatus.uncertain ||
        state.status == InternalTransferStatus.retryableRejected) {
      return _RecoveryPanel(state: state, controller: controller);
    }
    if (state.status == InternalTransferStatus.storageFailure) {
      return _StorageFailurePanel(state: state, controller: controller);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Send fake PHP safely',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KkSpacing.xs),
        Text(
          'Internal KK10P simulator transfer only. No real money or external payment rail.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: KkSpacing.lg),
        InternalTransferStepIndicator(step: state.step),
        if (state.message != null) ...[
          const SizedBox(height: KkSpacing.md),
          _FailureBanner(message: state.message!, requestId: state.requestId),
        ],
        const SizedBox(height: KkSpacing.lg),
        switch (state.step) {
          InternalTransferStep.recipient => _RecipientStep(
            state: state,
            sourceReference: account.id,
            textController: recipientController,
            focusNode: recipientFocus,
            controller: controller,
          ),
          InternalTransferStep.amount => _AmountStep(
            state: state,
            account: account,
            textController: amountController,
            focusNode: amountFocus,
            controller: controller,
          ),
          InternalTransferStep.review => _ReviewStep(
            state: state,
            account: account,
            controller: controller,
          ),
        },
      ],
    );
  }
}

class _RecipientStep extends StatelessWidget {
  const _RecipientStep({
    required this.state,
    required this.sourceReference,
    required this.textController,
    required this.focusNode,
    required this.controller,
  });

  final InternalTransferState state;
  final String sourceReference;
  final TextEditingController textController;
  final FocusNode focusNode;
  final InternalTransferController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Who are you sending to?',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: KkSpacing.sm),
      KkFieldSurface(
        errorText: state.recipientError,
        helperText: 'Ask the other KK10P tester to copy this reference from their Home account card.',
        child: TextField(
          key: const Key('transfer-recipient-field'),
          controller: textController,
          focusNode: focusNode,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(64)],
          onChanged: controller.updateRecipient,
          onSubmitted: (_) => controller.continueFromRecipient(sourceReference),
          decoration: InputDecoration(
            labelText: 'Recipient account reference',
            prefixIcon: const Icon(Icons.account_balance_outlined),
            suffixIcon: textController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear recipient account reference',
                    onPressed: () {
                      textController.clear();
                      controller.updateRecipient('');
                      focusNode.requestFocus();
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
      ),
      const SizedBox(height: KkSpacing.lg),
      KkEmbossedButton(
        variant: KkEmbossedButtonVariant.primary,
        onPressed: () => controller.continueFromRecipient(sourceReference),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Continue to amount'),
      ),
    ],
  );
}

class _AmountStep extends StatelessWidget {
  const _AmountStep({
    required this.state,
    required this.account,
    required this.textController,
    required this.focusNode,
    required this.controller,
  });

  final InternalTransferState state;
  final AccountSummary account;
  final TextEditingController textController;
  final FocusNode focusNode;
  final InternalTransferController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Enter an amount',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: KkSpacing.xs),
      Text('Available: ${account.formattedBalance}'),
      const SizedBox(height: KkSpacing.md),
      KkFieldSurface(
        errorText: state.amountError,
        helperText: 'PHP 0.01–50,000.00 per transfer. The server also enforces PHP 100,000 total outgoing per Philippine day.',
        child: TextField(
          key: const Key('transfer-amount-field'),
          controller: textController,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            LengthLimitingTextInputFormatter(24),
          ],
          onChanged: controller.updateAmount,
          onSubmitted: (_) =>
              controller.continueFromAmount(account.balanceMinor),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: 'PHP ',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
      ),
      const SizedBox(height: KkSpacing.lg),
      KkEmbossedButton(
        variant: KkEmbossedButtonVariant.primary,
        onPressed: () => controller.continueFromAmount(account.balanceMinor),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Review transfer'),
      ),
      const SizedBox(height: KkSpacing.sm),
      KkEmbossedButton(
        variant: KkEmbossedButtonVariant.insetAccent,
        onPressed: controller.goBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to recipient'),
      ),
    ],
  );
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.state,
    required this.account,
    required this.controller,
  });

  final InternalTransferState state;
  final AccountSummary account;
  final InternalTransferController controller;

  @override
  Widget build(BuildContext context) {
    final amount = InternalTransferAmount.tryParse(state.amountInput);
    if (amount == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review carefully',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KkSpacing.md),
        KkSoftSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryLine(label: 'Amount', value: amount.formatted),
              _SummaryReference(label: 'From', value: account.id),
              _SummaryReference(label: 'To', value: state.recipientInput),
              const SizedBox(height: KkSpacing.sm),
              Text(
                'Available before transfer: ${account.formattedBalance}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: KkSpacing.md),
        Semantics(
          label: 'Warning. This moves fake simulator money immediately and cannot be reversed in this version.',
          child: Text(
            'This moves fake simulator money immediately and cannot be reversed in this version.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: KkSpacing.lg),
        KkEmbossedButton(
          key: const Key('confirm-transfer-button'),
          variant: KkEmbossedButtonVariant.primary,
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            controller.submit(
              sourceAccountReference: account.id,
              availableMinor: account.balanceMinor,
            );
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Confirm transfer'),
        ),
        const SizedBox(height: KkSpacing.sm),
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.insetAccent,
          onPressed: controller.goBack,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit amount'),
        ),
      ],
    );
  }
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({required this.state, required this.controller});
  final InternalTransferState state;
  final InternalTransferController controller;

  @override
  Widget build(BuildContext context) {
    final pending = state.pending!;
    final rateLimited =
        state.status == InternalTransferStatus.retryableRejected;
    final wait = state.retryAfterSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KkSoftSurface(
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  rateLimited ? Icons.schedule : Icons.help_outline,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: KkSpacing.md),
                Text(
                  rateLimited
                      ? 'Transfer not sent yet'
                      : 'Transfer status unconfirmed',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: KkSpacing.sm),
                Text(state.message ?? '', textAlign: TextAlign.center),
                if (rateLimited && wait != null) ...[
                  const SizedBox(height: KkSpacing.xs),
                  Text(
                    'Wait about $wait seconds before retrying.',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: KkSpacing.lg),
                _SummaryLine(
                  label: 'Amount',
                  value: InternalTransferAmount.formatMinor(
                    pending.amountMinor,
                  ),
                ),
                _SummaryReference(
                  label: 'To',
                  value: pending.destinationAccountReference,
                ),
                if (state.requestId case final requestId?) ...[
                  const SizedBox(height: KkSpacing.sm),
                  _SummaryReference(
                    label: 'Support reference',
                    value: requestId,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: KkSpacing.lg),
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.primary,
          onPressed: controller.retryPending,
          icon: const Icon(Icons.refresh),
          label: Text(rateLimited ? 'Retry transfer' : 'Check transfer status'),
        ),
        if (rateLimited) ...[
          const SizedBox(height: KkSpacing.sm),
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.insetAccent,
            onPressed: controller.cancelRateLimited,
            icon: const Icon(Icons.close),
            label: const Text('Cancel this unsent request'),
          ),
        ],
      ],
    );
  }
}

class _StorageFailurePanel extends StatelessWidget {
  const _StorageFailurePanel({required this.state, required this.controller});
  final InternalTransferState state;
  final InternalTransferController controller;

  @override
  Widget build(BuildContext context) {
    final blocked =
        state.storageAction == InternalTransferStorageAction.blockedCorrupt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FailureBanner(
          message: state.message ?? 'Secure storage is unavailable.',
        ),
        if (state.receipt != null) ...[
          const SizedBox(height: KkSpacing.lg),
          InternalTransferReceiptCard(receipt: state.receipt!),
        ],
        const SizedBox(height: KkSpacing.lg),
        if (!blocked)
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.primary,
            onPressed: controller.retryStorageAction,
            icon: const Icon(Icons.refresh),
            label: Text(
              state.storageAction == InternalTransferStorageAction.retryClear
                  ? 'Retry secure cleanup'
                  : state.storageAction ==
                        InternalTransferStorageAction.retrySave
                  ? 'Retry secure save'
                  : 'Check recovery storage',
            ),
          ),
        const SizedBox(height: KkSpacing.sm),
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.insetAccent,
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Return home'),
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => KkSoftSurface(
    child: Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: KkSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: KkSpacing.xs),
          Text(
            'Do not close the app while the server result is being checked.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _AccountUnavailable extends StatelessWidget {
  const _AccountUnavailable({required this.state});
  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final loading = state.busy;
    return KkSoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) const LinearProgressIndicator(),
          Text(
            loading ? 'Loading your simulator account…' : 'Account unavailable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KkSpacing.sm),
          Text(
            state.message ?? 'Return Home to open or recover your simulator account before transferring funds.',
          ),
          const SizedBox(height: KkSpacing.lg),
          KkEmbossedButton(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Return home'),
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message, this.requestId});
  final String message;
  final String? requestId;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(KkSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(KkRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          if (requestId case final value?) ...[
            const SizedBox(height: KkSpacing.xs),
            SelectableText('Support reference: $value'),
          ],
        ],
      ),
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KkSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: KkSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _SummaryReference extends StatelessWidget {
  const _SummaryReference({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KkSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: KkSpacing.xs),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

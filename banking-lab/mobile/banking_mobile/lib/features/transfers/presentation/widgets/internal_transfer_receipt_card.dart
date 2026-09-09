import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/transfers/data/models/internal_transfer_receipt.dart';
import 'package:flutter/material.dart';

class InternalTransferReceiptCard extends StatelessWidget {
  const InternalTransferReceiptCard({required this.receipt, super.key});

  final InternalTransferReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Transfer complete. ${receipt.formattedAmount}. Status completed.',
      child: KkSoftSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: KkSpacing.md),
            Text(
              'Transfer complete',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: KkSpacing.xs),
            Text(
              receipt.formattedAmount,
              key: const Key('transfer-receipt-amount'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (receipt.replayed) ...[
              const SizedBox(height: KkSpacing.md),
              _Notice(
                text: 'This earlier request was safely confirmed. It was not sent twice.',
              ),
            ],
            const SizedBox(height: KkSpacing.lg),
            _ReceiptRow(label: 'Status', value: receipt.status),
            _ReceiptRow(
              label: 'Balance after',
              value: receipt.formattedSourceBalanceAfter,
            ),
            _ReceiptRow(
              label: 'Server time',
              value: _formatUtc(receipt.createdAtUtc),
            ),
            const SizedBox(height: KkSpacing.md),
            _Reference(
              label: 'From account',
              value: receipt.sourceAccountReference,
            ),
            const SizedBox(height: KkSpacing.sm),
            _Reference(
              label: 'To account',
              value: receipt.destinationAccountReference,
            ),
            const SizedBox(height: KkSpacing.sm),
            _Reference(label: 'Transaction ID', value: receipt.transactionId),
            const SizedBox(height: KkSpacing.md),
            Text(
              'Educational simulator receipt · No real money or payment rail.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
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

class _Reference extends StatelessWidget {
  const _Reference({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
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
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(KkSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withAlpha(20),
      borderRadius: BorderRadius.circular(KkRadius.small),
    ),
    child: Text(text, textAlign: TextAlign.center),
  );
}

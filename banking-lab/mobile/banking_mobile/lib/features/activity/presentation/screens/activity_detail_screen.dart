import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/presentation/activity_time.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_detail_controller.dart';
import 'package:banking_mobile/features/activity/presentation/widgets/activity_transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityDetailControllerProvider(transactionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction receipt')),
      body: KkPageBody(
        maxWidth: 560,
        child: switch (state.status) {
          ActivityDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading transaction receipt',
            ),
          ),
          ActivityDetailStatus.loaded => _Receipt(
            detail: state.detail!,
            localOccurredAt: ref
                .watch(activityTimeProvider)
                .toLocal(state.detail!.occurredAtUtc),
          ),
          ActivityDetailStatus.notFound ||
          ActivityDetailStatus.error => _DetailError(
            message: state.message ?? 'This transaction is unavailable.',
            requestId: state.requestId,
            onRetry: state.status == ActivityDetailStatus.error
                ? ref
                      .read(
                        activityDetailControllerProvider(transactionId)
                            .notifier,
                      )
                      .load
                : null,
          ),
        },
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.detail, required this.localOccurredAt});
  final ActivityDetail detail;
  final DateTime localOccurredAt;

  @override
  Widget build(BuildContext context) {
    final tokens = KkMaterialTokens.of(context);
    final incoming = detail.direction == ActivityDirection.incoming;
    final typeLabel = detail.type == ActivityType.developmentFunding
        ? 'Development funding'
        : incoming
        ? 'Transfer received'
        : 'Transfer sent';
    return Semantics(
      container: true,
      label: 'Completed transaction receipt for $typeLabel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KkSoftSurface(
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: KkSpacing.sm),
                Text(
                  'Completed',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: KkSpacing.xs),
                Text(typeLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: KkSpacing.lg),
                Text(
                  detail.formattedAmount,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: incoming
                        ? Colors.green.shade700
                        : tokens.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KkSpacing.lg),
          KkSoftSurface(
            style: KkSurfaceStyle.flat,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReceiptRow(
                  label: 'Date and time',
                  value: formatActivityDateTime(context, localOccurredAt),
                ),
                _ReceiptRow(
                  label: 'Server time (UTC)',
                  value: detail.occurredAtUtc.toIso8601String(),
                  selectable: true,
                ),
                _ReceiptRow(label: 'Status', value: detail.status),
                _ReceiptRow(
                  label: 'Direction',
                  value: incoming ? 'Incoming' : 'Outgoing',
                ),
                _ReceiptRow(
                  label: 'Your account reference',
                  value: detail.accountReference,
                  selectable: true,
                ),
                _ReceiptRow(
                  label: 'Counterparty',
                  value:
                      detail.counterpartyType ==
                          ActivityCounterpartyType.simulatorIssuer
                      ? 'Simulator issuer'
                      : detail.counterpartyAccountReference!,
                  selectable: true,
                ),
                _ReceiptRow(
                  label: 'Transaction reference',
                  value: detail.transactionId,
                  selectable: true,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: KkSpacing.md),
          Text(
            'Fake-money simulator receipt. No real funds moved.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.selectable = false,
    this.last = false,
  });
  final String label;
  final String value;
  final bool selectable;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : KkSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (selectable)
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          )
        else
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, this.requestId, this.onRetry});
  final String message;
  final String? requestId;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.receipt_long_outlined, size: 56),
      const SizedBox(height: KkSpacing.md),
      Semantics(
        liveRegion: true,
        child: Text(message, textAlign: TextAlign.center),
      ),
      if (requestId != null) ...[
        const SizedBox(height: KkSpacing.xs),
        SelectableText('Request: $requestId'),
      ],
      if (onRetry != null) ...[
        const SizedBox(height: KkSpacing.lg),
        KkEmbossedButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ],
  );
}

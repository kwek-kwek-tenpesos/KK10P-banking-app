import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:banking_mobile/features/activity/presentation/activity_time.dart';
import 'package:banking_mobile/features/activity/presentation/controllers/activity_controller.dart';
import 'package:banking_mobile/features/activity/presentation/widgets/activity_filter_sheet.dart';
import 'package:banking_mobile/features/activity/presentation/widgets/activity_transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityControllerProvider);
    final controller = ref.read(activityControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Filter activity',
            onPressed: () async {
              final filters = await showActivityFilterSheet(
                context,
                state.filters,
              );
              if (filters != null) await controller.applyFilters(filters);
            },
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: state.isRefreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: KkPageBody(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Account activity',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: KkSpacing.xs),
            Text(
              'Completed fake-money funding and transfers.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!state.filters.isEmpty) ...[
              const SizedBox(height: KkSpacing.md),
              _FilterSummary(filters: state.filters),
            ],
            if (state.message != null) ...[
              const SizedBox(height: KkSpacing.md),
              _ActivityNotice(
                message: state.message!,
                requestId: state.requestId,
                onDismiss: controller.clearNotice,
              ),
            ],
            const SizedBox(height: KkSpacing.lg),
            switch (state.status) {
              ActivityStatus.loading => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading account activity',
                ),
              ),
              ActivityStatus.error => _ErrorState(
                message: state.message ?? 'Activity could not be loaded.',
                onRetry: controller.refresh,
              ),
              ActivityStatus.empty => _EmptyState(
                filtered: !state.filters.isEmpty,
                onAction: !state.filters.isEmpty
                    ? () => controller.applyFilters(const ActivityFilters())
                    : controller.refresh,
              ),
              ActivityStatus.loaded => _ActivityItems(state: state),
            },
          ],
        ),
      ),
    );
  }
}

class _ActivityItems extends ConsumerWidget {
  const _ActivityItems({required this.state});

  final ActivityState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, List<ActivityItem>>{};
    final time = ref.watch(activityTimeProvider);
    final now = time.nowLocal();
    for (final item in state.items) {
      final group = activityDateGroup(time.toLocal(item.occurredAtUtc), now);
      groups.putIfAbsent(group, () => []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          Text(
            entry.key,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: KkSpacing.sm),
          for (final item in entry.value) ...[
            ActivityTransactionCard(
              key: ValueKey(item.transactionId),
              item: item,
              localOccurredAt: time.toLocal(item.occurredAtUtc),
              onPressed: () => context.push('/activity/${item.transactionId}'),
            ),
            const SizedBox(height: KkSpacing.md),
          ],
        ],
        if (state.nextCursor != null)
          KkEmbossedButton(
            onPressed: state.isLoadingMore
                ? null
                : ref.read(activityControllerProvider.notifier).loadMore,
            icon: state.isLoadingMore
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(
              state.isLoadingMore
                  ? 'Loading'
                  : state.message != null
                  ? 'Try loading more'
                  : 'Load more',
            ),
          ),
      ],
    );
  }
}

class _FilterSummary extends ConsumerWidget {
  const _FilterSummary({required this.filters});
  final ActivityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = [
      if (filters.direction case final value?)
        value == ActivityDirection.incoming ? 'Incoming' : 'Outgoing',
      if (filters.type case final value?)
        value == ActivityType.developmentFunding ? 'Funding' : 'Transfers',
    ];
    return Row(
      children: [
        Expanded(child: Text('Showing: ${labels.join(' • ')}')),
        TextButton(
          onPressed: () => ref
              .read(activityControllerProvider.notifier)
              .applyFilters(const ActivityFilters()),
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

class _ActivityNotice extends StatelessWidget {
  const _ActivityNotice({
    required this.message,
    required this.onDismiss,
    this.requestId,
  });
  final String message;
  final String? requestId;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => KkSoftSurface(
    style: KkSurfaceStyle.flat,
    padding: const EdgeInsets.all(KkSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline),
        const SizedBox(width: KkSpacing.sm),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              requestId == null ? message : '$message\nRequest: $requestId',
            ),
          ),
        ),
        IconButton(
          tooltip: 'Dismiss message',
          onPressed: onDismiss,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.cloud_off_outlined, size: 48),
      const SizedBox(height: KkSpacing.sm),
      Semantics(
        liveRegion: true,
        child: Text(message, textAlign: TextAlign.center),
      ),
      const SizedBox(height: KkSpacing.md),
      KkEmbossedButton(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onAction});
  final bool filtered;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.receipt_long_outlined, size: 48),
      const SizedBox(height: KkSpacing.sm),
      Text(
        filtered
            ? 'No completed activity matches these filters.'
            : 'No completed activity yet.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: KkSpacing.md),
      KkEmbossedButton(
        onPressed: onAction,
        icon: Icon(
          filtered ? Icons.filter_alt_off_outlined : Icons.refresh_rounded,
        ),
        label: Text(filtered ? 'Clear filters' : 'Refresh'),
      ),
    ],
  );
}

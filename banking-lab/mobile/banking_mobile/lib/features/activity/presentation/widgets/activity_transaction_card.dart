import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:flutter/material.dart';

class ActivityTransactionCard extends StatelessWidget {
  const ActivityTransactionCard({
    required this.item,
    required this.localOccurredAt,
    required this.onPressed,
    super.key,
  });

  final ActivityItem item;
  final DateTime localOccurredAt;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = KkMaterialTokens.of(context);
    final incoming = item.direction == ActivityDirection.incoming;
    final amountColor = incoming ? Colors.green.shade700 : tokens.textPrimary;
    final semantics =
        '${item.title}, ${item.formattedAmount}, ${item.counterpartyLabel}, '
        '${formatActivityDateTime(context, localOccurredAt)}, completed. Open receipt.';

    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: KkSoftSurface(
          padding: EdgeInsets.zero,
          borderRadius: KkRadius.medium,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: tokens.textPrimary,
              padding: const EdgeInsets.all(KkSpacing.md),
              minimumSize: const Size.fromHeight(80),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KkRadius.medium),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KkIconTile(icon: _icon),
                    const SizedBox(width: KkSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.counterpartyLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KkSpacing.xs),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: KkSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: KkSpacing.sm,
                  runSpacing: KkSpacing.xs,
                  children: [
                    Text(
                      formatActivityDateTime(context, localOccurredAt),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                    Text(
                      item.formattedAmount,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (item.type) {
    ActivityType.developmentFunding => Icons.savings_outlined,
    ActivityType.internalTransfer =>
      item.direction == ActivityDirection.incoming
          ? Icons.south_west_rounded
          : Icons.north_east_rounded,
  };
}

String activityDateGroup(DateTime local, DateTime now) {
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatActivityDateTime(BuildContext context, DateTime local) {
  final date =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date • $time';
}

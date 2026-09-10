import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/features/activity/data/models/activity_models.dart';
import 'package:flutter/material.dart';

Future<ActivityFilters?> showActivityFilterSheet(
  BuildContext context,
  ActivityFilters current,
) => showModalBottomSheet<ActivityFilters>(
  context: context,
  isScrollControlled: true,
  backgroundColor: KkMaterialTokens.of(context).canvas,
  builder: (context) => _ActivityFilterSheet(current: current),
);

class _ActivityFilterSheet extends StatefulWidget {
  const _ActivityFilterSheet({required this.current});

  final ActivityFilters current;

  @override
  State<_ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<_ActivityFilterSheet> {
  ActivityDirection? _direction;
  ActivityType? _type;

  @override
  void initState() {
    super.initState();
    _direction = widget.current.direction;
    _type = widget.current.type;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(KkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter activity',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: KkSpacing.lg),
          Text('Direction', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: KkSpacing.sm),
          Wrap(
            spacing: KkSpacing.sm,
            runSpacing: KkSpacing.sm,
            children: [
              _choice('All', _direction == null, () => _setDirection(null)),
              _choice(
                'Incoming',
                _direction == ActivityDirection.incoming,
                () => _setDirection(ActivityDirection.incoming),
              ),
              _choice(
                'Outgoing',
                _direction == ActivityDirection.outgoing,
                () => _setDirection(ActivityDirection.outgoing),
              ),
            ],
          ),
          const SizedBox(height: KkSpacing.lg),
          Text('Type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: KkSpacing.sm),
          Wrap(
            spacing: KkSpacing.sm,
            runSpacing: KkSpacing.sm,
            children: [
              _choice('All', _type == null, () => _setType(null)),
              _choice(
                'Funding',
                _type == ActivityType.developmentFunding,
                () => _setType(ActivityType.developmentFunding),
              ),
              _choice(
                'Transfers',
                _type == ActivityType.internalTransfer,
                () => _setType(ActivityType.internalTransfer),
              ),
            ],
          ),
          const SizedBox(height: KkSpacing.xl),
          KkEmbossedButton(
            variant: KkEmbossedButtonVariant.primary,
            onPressed: () =>
                Navigator.of(context)
                    .pop(ActivityFilters(direction: _direction, type: _type)),
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Apply filters'),
          ),
        ],
      ),
    ),
  );

  Widget _choice(String label, bool selected, VoidCallback onPressed) =>
      SizedBox(
        width: 132,
        child: KkEmbossedButton(
          variant: selected
              ? KkEmbossedButtonVariant.insetAccent
              : KkEmbossedButtonVariant.secondary,
          onPressed: onPressed,
          label: Text(label),
        ),
      );

  void _setDirection(ActivityDirection? value) =>
      setState(() => _direction = value);
  void _setType(ActivityType? value) => setState(() => _type = value);
}

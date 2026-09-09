import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/transfers/presentation/controllers/internal_transfer_controller.dart';
import 'package:flutter/material.dart';

class InternalTransferStepIndicator extends StatelessWidget {
  const InternalTransferStepIndicator({required this.step, super.key});

  final InternalTransferStep step;

  @override
  Widget build(BuildContext context) {
    final current = step.index + 1;
    final label = switch (step) {
      InternalTransferStep.recipient => 'Recipient',
      InternalTransferStep.amount => 'Amount',
      InternalTransferStep.review => 'Review',
    };
    final tokens = KkMaterialTokens.of(context);
    return Semantics(
      container: true,
      label: 'Transfer step $current of 3, $label',
      child: ExcludeSemantics(
        child: KkSoftSurface(
          style: KkSurfaceStyle.inset,
          padding: const EdgeInsets.all(KkSpacing.md),
          borderRadius: KkRadius.small,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: List.generate(3, (index) {
                  final reached = index <= step.index;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: reached
                            ? tokens.primary
                            : tokens.textSecondary.withAlpha(45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: KkSpacing.sm),
              Text(
                'Step $current of 3 · $label',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

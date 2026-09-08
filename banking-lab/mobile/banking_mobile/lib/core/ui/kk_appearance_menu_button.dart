import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/preferences/app_preferences_store.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KkAppearanceMenuButton extends ConsumerWidget {
  const KkAppearanceMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesControllerProvider);
    final tokens = KkMaterialTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: tokens.raisedGradient,
        borderRadius: BorderRadius.circular(KkRadius.small),
        boxShadow: tokens.tileDepth,
      ),
      child: PopupMenuButton<AppAppearance>(
        enabled: state.isReady,
        tooltip: 'Appearance: ${_label(state.appearance)}',
        initialValue: state.appearance,
        constraints: const BoxConstraints(minWidth: 180),
        onSelected: (appearance) => ref
            .read(appPreferencesControllerProvider.notifier)
            .setAppearance(appearance),
        icon: Icon(_icon(state.appearance), color: tokens.primary),
        itemBuilder: (context) => AppAppearance.values
            .map(
              (appearance) => PopupMenuItem(
                value: appearance,
                child: Row(
                  children: [
                    Icon(_icon(appearance)),
                    const SizedBox(width: KkSpacing.sm),
                    Text(_label(appearance)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class KkAppearanceSelector extends ConsumerWidget {
  const KkAppearanceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesControllerProvider);
    final useColumns = MediaQuery.textScalerOf(context).scale(16) > 22;
    final buttons = AppAppearance.values
        .map(
          (appearance) => KkEmbossedButton(
            variant: state.appearance == appearance
                ? KkEmbossedButtonVariant.insetAccent
                : KkEmbossedButtonVariant.secondary,
            onPressed: state.isReady
                ? () => ref
                      .read(appPreferencesControllerProvider.notifier)
                      .setAppearance(appearance)
                : null,
            icon: Icon(_icon(appearance)),
            label: Text(_label(appearance)),
          ),
        )
        .toList();

    if (useColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < buttons.length; index++) ...[
            buttons[index],
            if (index != buttons.length - 1)
              const SizedBox(height: KkSpacing.xs),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var index = 0; index < buttons.length; index++) ...[
          Expanded(child: buttons[index]),
          if (index != buttons.length - 1) const SizedBox(width: KkSpacing.xs),
        ],
      ],
    );
  }
}

class KkPreferencesWarning extends ConsumerWidget {
  const KkPreferencesWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warning = ref.watch(appPreferencesControllerProvider).warning;
    if (warning == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(KkSpacing.sm),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(KkRadius.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colors.onErrorContainer),
            const SizedBox(width: KkSpacing.xs),
            Expanded(
              child: Text(
                warning,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss preference warning',
              onPressed: () => ref
                  .read(appPreferencesControllerProvider.notifier)
                  .clearWarning(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(AppAppearance appearance) => switch (appearance) {
  AppAppearance.light => 'Light',
  AppAppearance.dark => 'Dark',
  AppAppearance.system => 'System',
};

IconData _icon(AppAppearance appearance) => switch (appearance) {
  AppAppearance.light => Icons.light_mode_outlined,
  AppAppearance.dark => Icons.dark_mode_outlined,
  AppAppearance.system => Icons.brightness_auto_outlined,
};

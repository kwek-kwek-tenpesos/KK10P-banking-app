import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:flutter/material.dart';

class MaterialProofScreen extends StatefulWidget {
  const MaterialProofScreen({super.key});

  @override
  State<MaterialProofScreen> createState() => _MaterialProofScreenState();
}

class _MaterialProofScreenState extends State<MaterialProofScreen> {
  Brightness _brightness = Brightness.light;

  void _toggleBrightness() {
    setState(() {
      _brightness = _brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _brightness == Brightness.dark;
    return Theme(
      data: isDark ? KkTheme.dark() : KkTheme.light(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            key: const ValueKey('material-proof-scaffold'),
            appBar: AppBar(
              title: const Text('Material proof'),
              actions: [
                IconButton(
                  onPressed: _toggleBrightness,
                  tooltip: isDark
                      ? 'Switch to light theme'
                      : 'Switch to dark theme',
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
            body: KkPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pure neumorphism',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: KkSpacing.xs),
                  Text(
                    'One material, blue accents, and light from the top-left.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: KkSpacing.xl),
                  KkSoftSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const KkIconTile(
                              icon: Icons.account_balance_rounded,
                              size: 30,
                            ),
                            const SizedBox(width: KkSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KK10P material',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    isDark ? 'Dark proof' : 'Light proof',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KkSpacing.lg),
                        KkSoftSurface(
                          style: KkSurfaceStyle.inset,
                          padding: const EdgeInsets.all(KkSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inset balance sample',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: KkSpacing.xs),
                              Text(
                                'PHP 18,345.67',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: KkSpacing.lg),
                        KkEmbossedButton(
                          variant: KkEmbossedButtonVariant.primary,
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Primary action'),
                        ),
                        const SizedBox(height: KkSpacing.md),
                        KkEmbossedButton(
                          onPressed: () {},
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Raised action'),
                        ),
                        const SizedBox(height: KkSpacing.md),
                        KkEmbossedButton(
                          variant: KkEmbossedButtonVariant.insetAccent,
                          onPressed: () {},
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Inset accent action'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KkSpacing.xl),
                  Text(
                    'Press and hold each action to compare its raised and '
                    'sunken states.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

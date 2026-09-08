import 'dart:async';

import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_appearance_menu_button.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.aboutMode = false});

  final bool aboutMode;

  Future<void> _choosePath(
    BuildContext context,
    WidgetRef ref,
    String route,
  ) async {
    await ref
        .read(appPreferencesControllerProvider.notifier)
        .markIntroductionCompleted();
    if (context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = KkMaterialTokens.of(context);

    return Scaffold(
      appBar: aboutMode
          ? AppBar(
              title: const Text('About KK10P'),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: KkSpacing.md),
                  child: KkAppearanceMenuButton(),
                ),
              ],
            )
          : null,
      body: KkPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!aboutMode)
              const Align(
                alignment: Alignment.centerRight,
                child: KkAppearanceMenuButton(),
              ),
            if (!aboutMode) const SizedBox(height: KkSpacing.lg),
            const Align(
              child: KkIconTile(icon: Icons.account_balance_rounded, size: 52),
            ),
            const SizedBox(height: KkSpacing.lg),
            Text(
              aboutMode ? 'KK10P Bank' : 'Welcome to KK10P',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: KkSpacing.xs),
            Text(
              'A tactile educational banking simulator.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: KkSpacing.lg),
            const KkPreferencesWarning(),
            const SizedBox(height: KkSpacing.md),
            KkSoftSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _InformationRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Fake money only',
                    body:
                        'Balances and transfers are for learning and testing.',
                  ),
                  SizedBox(height: KkSpacing.md),
                  _InformationRow(
                    icon: Icons.lock_outline,
                    title: 'Protected sign-in traffic',
                    body: 'Credential requests require HTTPS and rotating refresh tokens use platform secure storage.',
                  ),
                  SizedBox(height: KkSpacing.md),
                  _InformationRow(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Verified, revocable sessions',
                    body: 'Email verification and server-side session revocation are part of the simulator.',
                  ),
                  SizedBox(height: KkSpacing.md),
                  _InformationRow(
                    icon: Icons.info_outline,
                    title: 'Not a financial institution',
                    body:
                        'KK10P is not a bank or a real-money payment service.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: KkSpacing.lg),
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: KkSpacing.sm),
            const KkAppearanceSelector(),
            const SizedBox(height: KkSpacing.xl),
            if (aboutMode)
              KkEmbossedButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              )
            else ...[
              KkEmbossedButton(
                variant: KkEmbossedButtonVariant.primary,
                onPressed: () => unawaited(_choosePath(context, ref, '/login')),
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
              const SizedBox(height: KkSpacing.md),
              KkEmbossedButton(
                onPressed: () =>
                    unawaited(_choosePath(context, ref, '/register')),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Create account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = KkMaterialTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tokens.primary),
        const SizedBox(width: KkSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

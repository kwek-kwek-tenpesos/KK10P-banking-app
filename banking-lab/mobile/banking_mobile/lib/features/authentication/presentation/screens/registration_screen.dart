import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_appearance_menu_button.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/registration_controller.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/registration_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _submit() {
    ref
        .read(registrationControllerProvider.notifier)
        .register(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _displayNameController.text.isNotEmpty
              ? _displayNameController.text
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: KkSpacing.md),
            child: KkAppearanceMenuButton(),
          ),
        ],
      ),
      body: KkPageBody(
        padding: const EdgeInsets.fromLTRB(
          KkSpacing.lg,
          KkSpacing.md,
          KkSpacing.lg,
          KkSpacing.lg,
        ),
        child: state.isSuccess
            ? _buildSuccessView(context, state)
            : _buildFormView(context, state, theme),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, RegistrationState state) {
    final theme = Theme.of(context);

    return KkSoftSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KkPreferencesWarning(),
          const SizedBox(height: KkSpacing.lg),
          Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: KkSpacing.lg),
          Text(
            'Registration submitted',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KkSpacing.sm),
          Text(
            state.successMessage ?? 'If registration can proceed, check your email for the next step.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KkSpacing.md),
          KkSoftSurface(
            style: KkSurfaceStyle.inset,
            padding: const EdgeInsets.all(KkSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: KkSpacing.sm),
                Expanded(
                  child: Text(
                    'To protect account privacy, we do not disclose whether an email is already registered.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KkSpacing.xl),
          KkEmbossedButton(
            onPressed: () {
              ref.read(registrationControllerProvider.notifier).reset();
              context.go('/login');
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Return to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(
    BuildContext context,
    RegistrationState state,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(
          child: KkIconTile(icon: Icons.account_balance_rounded, size: 44),
        ),
        const SizedBox(height: KkSpacing.lg),
        Text(
          'Create your KK10P account',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: KkSpacing.xs),
        Text(
          'Register for the educational fake-money simulator.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: KkSpacing.md),
        const KkPreferencesWarning(),
        const SizedBox(height: KkSpacing.lg),
        if (state.generalErrorMessage != null) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(KkSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(KkRadius.small),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: KkSpacing.sm),
                  Expanded(
                    child: Text(
                      state.generalErrorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KkSpacing.md),
        ],
        KkFieldSurface(
          errorText: state.fieldErrors['email'],
          child: TextField(
            controller: _emailController,
            enabled: !state.isSubmitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email address',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
        ),
        const SizedBox(height: KkSpacing.md),
        KkFieldSurface(
          helperText:
              'Use 15–128 characters. Unicode length is checked by the server.',
          errorText: state.fieldErrors['password'],
          child: TextField(
            controller: _passwordController,
            enabled: !state.isSubmitting,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: KkSpacing.md),
        KkFieldSurface(
          helperText: 'Max 60 characters',
          errorText: state.fieldErrors['displayName'],
          child: TextField(
            controller: _displayNameController,
            enabled: !state.isSubmitting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Display name (optional)',
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
        ),
        const SizedBox(height: KkSpacing.lg),
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.primary,
          onPressed: state.isSubmitting ? null : _submit,
          icon: state.isSubmitting
              ? null
              : const Icon(Icons.person_add_outlined),
          label: state.isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create account'),
        ),
      ],
    );
  }
}

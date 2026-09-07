import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    ref
        .read(authenticationControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationControllerProvider);
    final theme = Theme.of(context);

    if (state.status == AuthenticationStatus.initializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Restoring your secure session',
          ),
        ),
      );
    }

    return Scaffold(
      body: KkPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              child: KkIconTile(icon: Icons.account_balance_rounded, size: 48),
            ),
            const SizedBox(height: KkSpacing.md),
            Text(
              'KK10P Bank',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: KkSpacing.xl),
            Text(
              'Welcome back',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: KkSpacing.xs),
            Text(
              'Sign in to your fake-money simulator account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: KkSpacing.lg),
              _ErrorBanner(message: state.errorMessage!),
            ],
            const SizedBox(height: KkSpacing.lg),
            KkFieldSurface(
              child: TextField(
                controller: _emailController,
                enabled: !state.isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ),
            const SizedBox(height: KkSpacing.md),
            KkFieldSurface(
              child: TextField(
                controller: _passwordController,
                enabled: !state.isSubmitting,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KkSpacing.lg),
            KkEmbossedButton(
              variant: KkEmbossedButtonVariant.primary,
              onPressed: state.isSubmitting ? null : _submit,
              icon: state.isSubmitting ? null : const Icon(Icons.login),
              label: state.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
            if (state.canRetryRestore) ...[
              const SizedBox(height: KkSpacing.md),
              KkEmbossedButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => ref
                          .read(authenticationControllerProvider.notifier)
                          .initialize(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry saved session'),
              ),
            ],
            const SizedBox(height: KkSpacing.md),
            KkEmbossedButton(
              variant: KkEmbossedButtonVariant.insetAccent,
              onPressed: state.isSubmitting
                  ? null
                  : () => context.push('/register'),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Create a customer account'),
            ),
            const SizedBox(height: KkSpacing.sm),
            KkEmbossedButton(
              variant: KkEmbossedButtonVariant.insetAccent,
              onPressed: state.isSubmitting
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (context) => const _ResendVerificationDialog(),
                    ),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Resend verification email'),
            ),
            const SizedBox(height: KkSpacing.xs),
            const Divider(),
            const SizedBox(height: KkSpacing.md),
            KkEmbossedButton(
              onPressed: () => context.push('/diagnostics'),
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('Open API diagnostics'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}

class _ResendVerificationDialog extends ConsumerStatefulWidget {
  const _ResendVerificationDialog();

  @override
  ConsumerState<_ResendVerificationDialog> createState() =>
      _ResendVerificationDialogState();
}

class _ResendVerificationDialogState
    extends ConsumerState<_ResendVerificationDialog> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Enter your email address.');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final message = await ref
          .read(authenticationRepositoryProvider)
          .resendVerification(email);
      if (mounted) setState(() => _message = message);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'The request could not be completed.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resend verification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}

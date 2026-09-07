import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/authentication/data/repositories/authentication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({
    required this.userId,
    required this.token,
    super.key,
  });

  final String? userId;
  final String? token;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _submitting = false;
  bool _confirmed = false;
  String? _errorMessage;

  bool get _hasLinkData =>
      widget.userId?.isNotEmpty == true && widget.token?.isNotEmpty == true;

  Future<void> _confirm() async {
    if (!_hasLinkData || _submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authenticationRepositoryProvider)
          .confirmEmail(userId: widget.userId!, token: widget.token!);
      if (mounted) setState(() => _confirmed = true);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _errorMessage = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Email verification could not be completed.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invalidLink = !_hasLinkData;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: KkPageBody(
        child: KkSoftSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _confirmed
                    ? Icons.verified_outlined
                    : Icons.mark_email_unread_outlined,
                size: 64,
                color: _confirmed
                    ? const Color(0xFF2E7D32)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: KkSpacing.lg),
              Text(
                _confirmed
                    ? 'Email verified'
                    : invalidLink
                    ? 'Invalid verification link'
                    : 'Confirm your email address',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KkSpacing.sm),
              Text(
                _confirmed
                    ? 'Your account can now sign in.'
                    : invalidLink
                    ? 'Request a new verification message from the sign-in screen.'
                    : 'Tap confirm to submit this one-use verification token securely.',
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: KkSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: KkSpacing.lg),
              if (!_confirmed && !invalidLink)
                KkEmbossedButton(
                  variant: KkEmbossedButtonVariant.primary,
                  onPressed: _submitting ? null : _confirm,
                  icon: _submitting
                      ? null
                      : const Icon(Icons.verified_outlined),
                  label: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm email'),
                ),
              if (_confirmed || invalidLink)
                KkEmbossedButton(
                  variant: KkEmbossedButtonVariant.primary,
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Go to sign in'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

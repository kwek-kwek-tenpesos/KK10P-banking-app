import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/errors/client_upgrade_signal.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/client_compatibility/presentation/controllers/client_compatibility_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class AppUpdateLauncher {
  Future<bool> open(Uri uri);
}

class ExternalAppUpdateLauncher implements AppUpdateLauncher {
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

final appUpdateLauncherProvider = Provider<AppUpdateLauncher>(
  (ref) => ExternalAppUpdateLauncher(),
);

class UpdateRequiredScreen extends ConsumerStatefulWidget {
  const UpdateRequiredScreen({super.key});

  @override
  ConsumerState<UpdateRequiredScreen> createState() =>
      _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<UpdateRequiredScreen> {
  bool _opening = false;

  Future<void> _openUpdate(ClientUpgradeRequiredFailure failure) async {
    if (_opening) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await ref
          .read(appUpdateLauncherProvider)
          .open(failure.updateUri);
    } catch (_) {
      // The platform launcher can fail even after a URI passed validation.
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The secure update link could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientCompatibilityControllerProvider);
    final tokens = KkMaterialTokens.of(context);
    final failure = state.failure;
    final required = failure is ClientUpgradeRequiredFailure ? failure : null;
    final invalidLocal =
        state.status == ClientCompatibilityStatus.invalidLocalBuild;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KkSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: KkSoftSurface(
                  padding: const EdgeInsets.all(KkSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.system_update_alt_rounded,
                        size: 58,
                        color: tokens.primary,
                      ),
                      const SizedBox(height: KkSpacing.lg),
                      Text(
                        invalidLocal
                            ? 'App version unavailable'
                            : 'Update required',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: KkSpacing.md),
                      Text(
                        invalidLocal
                            ? 'KK10P Bank could not verify this installation. Reinstall the official app before continuing.'
                            : 'Install the current KK10P Bank app to continue securely. Your saved session and pending transfer recovery data remain on this device.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                      if (required != null) ...[
                        const SizedBox(height: KkSpacing.md),
                        Semantics(
                          label:
                              'Installed build ${required.currentBuild ?? 'legacy'}, minimum required build ${required.minimumBuild}',
                          child: Text(
                            'Installed build ${required.currentBuild ?? 'Legacy'}  •  Required build ${required.minimumBuild}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(height: KkSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _opening
                                ? null
                                : () => _openUpdate(required),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(_opening ? 'Opening…' : 'Update app'),
                          ),
                        ),
                      ],
                      const SizedBox(height: KkSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              state.status == ClientCompatibilityStatus.checking
                              ? null
                              : () {
                                  ref
                                      .read(
                                        clientUpgradeSignalProvider.notifier,
                                      )
                                      .clear();
                                  ref
                                      .read(
                                        clientCompatibilityControllerProvider
                                            .notifier,
                                      )
                                      .check();
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Check again'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

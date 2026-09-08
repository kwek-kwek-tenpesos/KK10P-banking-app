import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/core/ui/kk_appearance_menu_button.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/development_funding/presentation/widgets/development_funding_card.dart';
import 'package:banking_mobile/features/system_info/presentation/providers/system_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SystemInfoScreen extends ConsumerWidget {
  const SystemInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemInfoAsync = ref.watch(systemInfoProvider);
    final authenticated = ref.watch(
      authenticationControllerProvider.select((state) => state.isAuthenticated),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('KK10P Bank'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: KkAppearanceMenuButton(),
          ),
          IconButton(
            onPressed: () => context.push('/material-proof'),
            tooltip: 'Open material proof',
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: KkPageBody(
        child: systemInfoAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to the Banking API...'),
              ],
            ),
          ),
          data: (systemInfo) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KkSoftSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      systemInfo.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text('Version: ${systemInfo.version}'),
                    const SizedBox(height: 8),
                    Text('Environment: ${systemInfo.environment}'),
                    const SizedBox(height: 24),
                    KkEmbossedButton(
                      onPressed: () => context.push('/about'),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('About KK10P'),
                    ),
                  ],
                ),
              ),
              if (authenticated && systemInfo.environment == 'Development') ...[
                const SizedBox(height: 20),
                const DevelopmentFundingCard(),
              ],
            ],
          ),
          error: (error, stackTrace) {
            late final AppFailure failure;

            if (error is AppFailure) {
              failure = error;
            } else {
              failure = const UnexpectedFailure();
            }

            return KkSoftSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: Theme.of(context).colorScheme.error,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not connect to the Banking API.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(failure.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  KkEmbossedButton(
                    variant: KkEmbossedButtonVariant.primary,
                    onPressed: () {
                      ref.invalidate(systemInfoProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

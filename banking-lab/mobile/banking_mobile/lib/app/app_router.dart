import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/activity/presentation/screens/activity_detail_screen.dart';
import 'package:banking_mobile/features/activity/presentation/screens/activity_screen.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/email_verification_screen.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/registration_screen.dart';
import 'package:banking_mobile/features/client_compatibility/presentation/controllers/client_compatibility_controller.dart';
import 'package:banking_mobile/features/client_compatibility/presentation/screens/update_required_screen.dart';
import 'package:banking_mobile/features/home/presentation/screens/customer_home_screen.dart';
import 'package:banking_mobile/features/material_proof/presentation/screens/material_proof_screen.dart';
import 'package:banking_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:banking_mobile/features/system_info/presentation/screens/system_info_screen.dart';
import 'package:banking_mobile/features/transfers/presentation/screens/internal_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier(ref.read(authenticationControllerProvider));
  final compatibilityState = ValueNotifier(
    ref.read(clientCompatibilityControllerProvider),
  );
  final preferencesState = ValueNotifier(
    ref.read(appPreferencesControllerProvider),
  );
  ref.listen(authenticationControllerProvider, (_, next) {
    authState.value = next;
  });
  ref.listen(clientCompatibilityControllerProvider, (_, next) {
    compatibilityState.value = next;
  });
  ref.listen(appPreferencesControllerProvider, (_, next) {
    preferencesState.value = next;
  });
  ref.onDispose(() {
    authState.dispose();
    compatibilityState.dispose();
    preferencesState.dispose();
  });

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      authState,
      compatibilityState,
      preferencesState,
    ]),
    redirect: (context, state) {
      final auth = authState.value;
      final compatibility = compatibilityState.value;
      final preferences = preferencesState.value;
      final location = state.matchedLocation;

      if (compatibility.status == ClientCompatibilityStatus.updateRequired ||
          compatibility.status == ClientCompatibilityStatus.invalidLocalBuild) {
        return location == '/update-required' ? null : '/update-required';
      }
      if (compatibility.status == ClientCompatibilityStatus.checking ||
          compatibility.status == ClientCompatibilityStatus.unavailable) {
        return location == '/' ? null : '/';
      }
      if (location == '/update-required') return '/';
      final isAuthEntry =
          location == '/welcome' ||
          location == '/login' ||
          location == '/register';
      final isProtected =
          location == '/home' ||
          location == '/transfer' ||
          location == '/activity' ||
          location.startsWith('/activity/');

      if (auth.status == AuthenticationStatus.initializing ||
          !preferences.isReady) {
        final mayOpenDuringRestore =
            location == '/' ||
            location == '/verify-email' ||
            location == '/diagnostics' ||
            location == '/material-proof' ||
            location == '/about';
        return mayOpenDuringRestore ? null : '/';
      }
      if (location == '/') {
        if (auth.isAuthenticated) return '/home';
        return preferences.introductionCompleted ? '/login' : '/welcome';
      }
      if (isProtected && !auth.isAuthenticated) return '/login';
      if (isAuthEntry && auth.isAuthenticated) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _StartupScreen()),
      GoRoute(
        path: '/update-required',
        builder: (context, state) => const UpdateRequiredScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const WelcomeScreen(aboutMode: true),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => EmailVerificationScreen(
          userId: state.uri.queryParameters['userId'],
          token: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const SystemInfoScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) => const InternalTransferScreen(),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/activity/:transactionId',
        builder: (context, state) => ActivityDetailScreen(
          transactionId: state.pathParameters['transactionId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/material-proof',
        builder: (context, state) => const MaterialProofScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _StartupScreen extends ConsumerWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = KkMaterialTokens.of(context);
    final compatibility = ref.watch(clientCompatibilityControllerProvider);
    final unavailable =
        compatibility.status == ClientCompatibilityStatus.unavailable;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: KkSoftSurface(
            padding: const EdgeInsets.all(KkSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  size: 52,
                  color: tokens.primary,
                ),
                const SizedBox(height: KkSpacing.md),
                Text(
                  'KK10P Bank',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KkSpacing.lg),
                if (unavailable) ...[
                  Text(
                    compatibility.failure?.message ?? 'The app version could not be checked. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: KkSpacing.md),
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(clientCompatibilityControllerProvider.notifier)
                          .check();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ] else
                  const CircularProgressIndicator(
                    semanticsLabel:
                        'Checking app compatibility and restoring your session',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

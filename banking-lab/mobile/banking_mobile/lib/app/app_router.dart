import 'package:banking_mobile/core/preferences/app_preferences_controller.dart';
import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:banking_mobile/features/authentication/presentation/controllers/authentication_controller.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/email_verification_screen.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:banking_mobile/features/authentication/presentation/screens/registration_screen.dart';
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
  final preferencesState = ValueNotifier(
    ref.read(appPreferencesControllerProvider),
  );
  ref.listen(authenticationControllerProvider, (_, next) {
    authState.value = next;
  });
  ref.listen(appPreferencesControllerProvider, (_, next) {
    preferencesState.value = next;
  });
  ref.onDispose(() {
    authState.dispose();
    preferencesState.dispose();
  });

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([authState, preferencesState]),
    redirect: (context, state) {
      final auth = authState.value;
      final preferences = preferencesState.value;
      final location = state.matchedLocation;
      final isAuthEntry =
          location == '/welcome' ||
          location == '/login' ||
          location == '/register';
      final isProtected = location == '/home' || location == '/transfer';

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
        path: '/material-proof',
        builder: (context, state) => const MaterialProofScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    final tokens = KkMaterialTokens.of(context);
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
                const CircularProgressIndicator(
                  semanticsLabel: 'Restoring your session and preferences',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

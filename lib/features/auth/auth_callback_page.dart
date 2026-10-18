import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';
import 'auth_error_banner.dart';
import 'auth_providers.dart';
import 'auth_widgets.dart';

/// Where Google sends the user back to. The auth module finishes the
/// sign-in here (using the saved language), then goes straight to the
/// right dashboard - the landing page is never involved.
class AuthCallbackPage extends ConsumerStatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  ConsumerState<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends ConsumerState<AuthCallbackPage> {
  bool _started = false;
  String? _error;

  Future<void> _finish(LandingModel school) async {
    final fr = ref.read(activeLocaleProvider).languageCode == 'fr';
    final oauthError = Uri.base.queryParameters['error_description'] ?? Uri.base.queryParameters['error'];
    if (oauthError != null) {
      if (mounted) setState(() => _error = fr ? "L'authentification a échoué. Veuillez réessayer." : 'Authentication failed. Please try again.');
      return;
    }
    final profile = await ref.read(authControllerProvider.notifier).completeOAuth(school.schoolId);
    if (!mounted) return;
    if (profile != null) {
      context.go(routeForRole(profile.role));
    } else {
      setState(() => _error = ref.read(authControllerProvider).errorMessage ?? (fr ? "L'authentification a échoué. Veuillez réessayer." : 'Authentication failed. Please try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final fr = ref.watch(activeLocaleProvider).languageCode == 'fr';

    return landing.when(
      loading: () => const AuthLoadingView(),
      error: (e, _) => const AuthLoadFailedView(),
      data: (school) {
        if (!_started) {
          _started = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _finish(school));
        }
        return AuthScaffold(
          school: school,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthBrandingHeader(school: school, subtitle: _error == null ? (fr ? 'Connexion en cours…' : 'Signing you in…') : (fr ? 'Connexion impossible' : "Couldn't sign you in")),
              const SizedBox(height: 28),
              if (_error == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                AuthErrorBanner(message: _error, onDismiss: () {}),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go('/sign-in'), child: Text(fr ? 'Retour à la connexion' : 'Back to sign in')),
              ],
            ],
          ),
        );
      },
    );
  }
}

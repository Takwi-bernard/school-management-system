import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import 'auth_error_banner.dart';
import 'auth_gate.dart';
import 'auth_providers.dart';
import 'auth_widgets.dart';
import 'google_icon.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(String schoolId) async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
          expectedSchoolId: schoolId,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.profile != null) {
      context.go(routeForRole(state.profile!.role));
    } else {
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);
    final authState = ref.watch(authControllerProvider);
    final fr = locale.languageCode == 'fr';

    return landing.when(
      loading: () => const AuthLoadingView(),
      error: (e, _) => const AuthLoadFailedView(),
      data: (school) {
        redirectIfSignedIn(ref, context, school.schoolId, routeForRole);
        final strings = AppStrings(locale);

        // Everything below sits inside AuthScaffold's school Theme, and
        // the buttons take their colour from that theme - no widget here
        // reads Theme.of(context) from above it (that was the stale blue).
        return AuthScaffold(
          school: school,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthBrandingHeader(school: school, subtitle: strings.signInTitle),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: strings.email, prefixIcon: const Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? (fr ? 'Entrez une adresse e-mail valide' : 'Enter a valid email') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => authState.isLoading ? null : _signIn(school.schoolId),
                  decoration: InputDecoration(
                    labelText: strings.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? (fr ? 'Entrez votre mot de passe' : 'Enter your password') : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final e = _email.text.trim();
                      context.push(e.contains('@') ? '/auth/forgot?email=${Uri.encodeQueryComponent(e)}' : '/auth/forgot');
                    },
                    child: Text(strings.forgotPassword),
                  ),
                ),
                AuthErrorBanner(
                  message: authState.errorMessage,
                  onDismiss: () => ref.read(authControllerProvider.notifier).clearError(),
                ),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: authState.isLoading ? null : () => _signIn(school.schoolId),
                  child: authState.isLoading ? const AuthButtonSpinner() : Text(strings.signInTitle),
                ),
                const SizedBox(height: 20),
                AuthOrDivider(label: strings.orDivider),
                const SizedBox(height: 20),
                GoogleSignInButton(
                  onPressed: authState.isLoading ? null : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                  label: strings.continueWithGoogle,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: authState.isLoading ? null : () => context.push('/auth/phone?mode=sign-in'),
                  icon: const Icon(Icons.phone_iphone_rounded),
                  label: Text(fr ? 'Continuer avec le téléphone' : 'Continue with phone'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/sign-up'),
                  child: Text('${strings.noAccount} ${strings.createAccount}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

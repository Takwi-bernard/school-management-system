import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';
import 'auth_providers.dart';
import 'google_icon.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn(String schoolId, String schoolName) async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          expectedSchoolId: schoolId,
        );

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.profile != null) {
      _redirectByRole(state.profile!.role);
    }
  }

  void _redirectByRole(String role) {
    switch (role) {
      case 'parent':
        context.go('/parent');
      case 'teacher':
        context.go('/teacher');
      case 'principal':
        context.go('/principal');
      case 'secretary':
        context.go('/secretary');
      case 'proprietor':
        context.go('/proprietor');
      default:
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);
    final authState = ref.watch(authControllerProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Unable to load school.\n$e'))),
      data: (school) {
        final strings = AppStrings(locale);

        return AuthScaffold(
          school: school,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthBrandingHeader(school: school, subtitle: strings.signInTitle),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: strings.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: strings.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password recovery is coming soon.')),
                    ),
                    child: Text(strings.forgotPassword),
                  ),
                ),
                if (authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(authState.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: HoverLift(
                    liftPixels: 2,
                    onTap: authState.isLoading ? null : () => _signIn(school.schoolId, school.schoolName),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(strings.signInTitle,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(strings.orDivider, style: Theme.of(context).textTheme.labelSmall),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),
                GoogleSignInButton(
                  onPressed: authState.isLoading
                      ? null
                      : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                  label: strings.continueWithGoogle,
                ),
                const SizedBox(height: 20),
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
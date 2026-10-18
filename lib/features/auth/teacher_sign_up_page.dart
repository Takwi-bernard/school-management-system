import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';
import 'auth_error_banner.dart';
import 'auth_providers.dart';
import 'auth_widgets.dart';
import 'google_icon.dart';

class TeacherSignUpPage extends ConsumerStatefulWidget {
  const TeacherSignUpPage({super.key});

  @override
  ConsumerState<TeacherSignUpPage> createState() => _TeacherSignUpPageState();
}

class _TeacherSignUpPageState extends ConsumerState<TeacherSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true, _obscure2 = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(String schoolId, String languageMode) async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).registerTeacher(
          schoolId: schoolId,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          preferredLanguage: languageMode == 'french' ? 'fr' : 'en',
        );

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.errorMessage == null) {
      final fr = ref.read(activeLocaleProvider).languageCode == 'fr';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fr ? 'Compte créé. En attente de l\'approbation du Principal.' : 'Account created. Awaiting Principal approval.')),
      );
      context.go('/sign-in');
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
        final strings = AppStrings(locale);
        String? req(String? v) => (v == null || v.trim().isEmpty) ? (fr ? 'Obligatoire' : 'Required') : null;

        return AuthScaffold(
          school: school,
          maxWidth: 520,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthBrandingHeader(school: school, subtitle: strings.teacher),
                const SizedBox(height: 20),
                GoogleSignInButton(
                  onPressed: authState.isLoading
                      ? null
                      : () => ref.read(authControllerProvider.notifier).signInWithGoogle(signUpRole: 'teacher'),
                  label: strings.continueWithGoogle,
                ),
                const SizedBox(height: 18),
                AuthOrDivider(label: fr ? 'OU AVEC E-MAIL' : 'OR WITH EMAIL'),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: strings.fullName, prefixIcon: const Icon(Icons.person_outline)),
                  validator: req,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: strings.phoneNumber, prefixIcon: const Icon(Icons.phone_outlined)),
                  validator: req,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: strings.email, prefixIcon: const Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? (fr ? 'Entrez une adresse e-mail valide' : 'Enter a valid email') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: strings.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? strings.passwordTooShort : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: strings.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) => v != _password.text ? strings.passwordsDoNotMatch : null,
                ),
                AuthErrorBanner(
                  message: authState.errorMessage,
                  onDismiss: () => ref.read(authControllerProvider.notifier).clearError(),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: authState.isLoading ? null : () => _submit(school.schoolId, school.languageMode),
                  child: authState.isLoading ? const AuthButtonSpinner() : Text(strings.createTeacherAccount),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: Text(strings.alreadyHaveAccount),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

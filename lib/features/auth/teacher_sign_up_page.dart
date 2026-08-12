import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';
import 'auth_providers.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Awaiting Principal approval.')),
      );
      context.go('/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final locale = ref.watch(activeLocaleProvider);
    final authState = ref.watch(authControllerProvider);

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('We couldn\'t reach the server. Please check your connection.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.invalidate(landingProvider),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (school) {
        final strings = AppStrings(locale);

        return AuthScaffold(
          school: school,
          maxWidth: 520,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthBrandingHeader(school: school, subtitle: strings.teacher),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: strings.fullName,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: strings.phoneNumber,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: strings.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: strings.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: strings.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
                if (authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(authState.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _submit(school.schoolId, school.languageMode),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(strings.createTeacherAccount),
                  ),
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
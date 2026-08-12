import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';
import 'auth_providers.dart';

class ParentSignUpPage extends ConsumerStatefulWidget {
  const ParentSignUpPage({super.key});

  @override
  ConsumerState<ParentSignUpPage> createState() => _ParentSignUpPageState();
}

class _ParentSignUpPageState extends ConsumerState<ParentSignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Child fields are intentionally NOT validated/required - a parent
  // can skip this entirely and complete it later during admission.
  final _childName = TextEditingController();
  final _requestedClass = TextEditingController();
  XFile? _childPhoto;

  bool _obscure1 = true, _obscure2 = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm, _childName, _requestedClass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _childPhoto = picked);
  }

  Future<void> _submit(String schoolId, String languageMode) async {
    if (!_formKey.currentState!.validate()) return;

    Uint8List? photoBytes;
    String? photoExt;
    if (_childPhoto != null) {
      photoBytes = await _childPhoto!.readAsBytes();
      photoExt = _childPhoto!.name.contains('.') ? _childPhoto!.name.split('.').last : 'jpg';
    }

    await ref.read(authControllerProvider.notifier).registerParent(
          schoolId: schoolId,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          preferredLanguage: languageMode == 'french' ? 'fr' : 'en',
          childName: _childName.text.trim().isEmpty ? null : _childName.text.trim(),
          childPhotoBytes: photoBytes,
          childPhotoExtension: photoExt,
          requestedClassName:
              _requestedClass.text.trim().isEmpty ? null : _requestedClass.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
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
        final theme = Theme.of(context);

        return AuthScaffold(
          school: school,
          maxWidth: 560,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthBrandingHeader(school: school, subtitle: strings.parent),
                const SizedBox(height: 20),
                _field(_name, strings.fullName, Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),
                _field(_phone, strings.phoneNumber, Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),
                _field(_email, strings.email, Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
                const SizedBox(height: 14),
                _passwordField(_password, strings.password, _obscure1,
                    () => setState(() => _obscure1 = !_obscure1),
                    validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null),
                const SizedBox(height: 14),
                _passwordField(_confirm, strings.confirmPassword, _obscure2,
                    () => setState(() => _obscure2 = !_obscure2),
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null),

                const SizedBox(height: 28),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(strings.childInformation,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 4),
                Text(strings.childInformationOptional,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 16),

                _field(_childName, strings.childFullName, Icons.child_care_outlined),
                const SizedBox(height: 14),
                _field(_requestedClass, strings.requestedClass, Icons.class_outlined),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(_childPhoto == null ? strings.uploadPhoto : _childPhoto!.name),
                ),

                if (authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(authState.errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                  ),

                const SizedBox(height: 24),
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
                        : Text(strings.createParentAccount),
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

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      validator: validator,
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool obscure,
    VoidCallback onToggle, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
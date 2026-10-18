import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../landing/landing_providers.dart';
import 'auth_branding_header.dart';
import 'auth_error_banner.dart';
import 'auth_providers.dart';
import 'auth_widgets.dart';

/// Sign in or sign up with a phone number and a 6-digit SMS code.
/// Route: /auth/phone?mode=sign-in | sign-up  (sign-up creates a parent).
class PhoneAuthPage extends ConsumerStatefulWidget {
  final bool signUp;
  const PhoneAuthPage({super.key, this.signUp = false});

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authControllerProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Cameroon default: 9 local digits (6xx xxx xxx) become +237…; a number
  /// already starting with + is kept as typed.
  String _normalised() {
    final raw = _phone.text.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    if (raw.startsWith('237')) return '+$raw';
    return '+237$raw';
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send(String schoolId, String languageMode) async {
    if (!_codeSent && !_formKey.currentState!.validate()) return;
    final phone = _normalised();
    final ok = await ref.read(authControllerProvider.notifier).sendPhoneCode(
          phone: phone,
          createUser: widget.signUp,
          metadata: widget.signUp
              ? {
                  'account_type': 'parent',
                  'school_id': schoolId,
                  'full_name': _name.text.trim(),
                  'phone': phone,
                  'preferred_language': languageMode == 'french' ? 'fr' : 'en',
                }
              : null,
        );
    if (!mounted || !ok) return;
    setState(() => _codeSent = true);
    _startCooldown();
  }

  Future<void> _verify(String schoolId) async {
    if (_code.text.trim().length != 6) return;
    final profile = await ref.read(authControllerProvider.notifier).verifyPhoneCode(
          phone: _normalised(),
          code: _code.text.trim(),
          expectedSchoolId: schoolId,
        );
    if (!mounted) return;
    if (profile != null) {
      context.go(routeForRole(profile.role));
    } else {
      _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider);
    final fr = ref.watch(activeLocaleProvider).languageCode == 'fr';
    final authState = ref.watch(authControllerProvider);

    return landing.when(
      loading: () => const AuthLoadingView(),
      error: (e, _) => const AuthLoadFailedView(),
      data: (school) {
        final title = _codeSent
            ? (fr ? 'Entrez le code' : 'Enter the code')
            : widget.signUp
                ? (fr ? 'Inscription par téléphone' : 'Sign up with phone')
                : (fr ? 'Connexion par téléphone' : 'Sign in with phone');

        return AuthScaffold(
          school: school,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Column(
              key: ValueKey(_codeSent),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthBrandingHeader(school: school, subtitle: title),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? (fr ? 'Nous avons envoyé un code à 6 chiffres au ${_normalised()}.' : 'We sent a 6-digit code to ${_normalised()}.')
                      : (fr ? 'Nous vous enverrons un code par SMS. Numéro camerounais : 6XX XXX XXX.' : "We'll text you a code. Cameroon number: 6XX XXX XXX."),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 22),
                if (!_codeSent)
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      if (widget.signUp) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(labelText: fr ? 'Nom complet' : 'Full name', prefixIcon: const Icon(Icons.person_outline)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? (fr ? 'Obligatoire' : 'Required') : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
                        decoration: InputDecoration(
                          labelText: fr ? 'Numéro de téléphone' : 'Phone number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefixText: _phone.text.trim().startsWith('+') ? null : '+237 ',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          return d.length < 8 ? (fr ? 'Entrez un numéro valide' : 'Enter a valid phone number') : null;
                        },
                      ),
                    ]),
                  )
                else
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 10),
                    decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                    onChanged: (v) {
                      if (v.length == 6 && !authState.isLoading) _verify(school.schoolId);
                    },
                  ),
                const SizedBox(height: 8),
                AuthErrorBanner(message: authState.errorMessage, onDismiss: () => ref.read(authControllerProvider.notifier).clearError()),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: authState.isLoading ? null : () => _codeSent ? _verify(school.schoolId) : _send(school.schoolId, school.languageMode),
                  child: authState.isLoading
                      ? const AuthButtonSpinner()
                      : Text(_codeSent ? (fr ? 'Vérifier' : 'Verify') : (fr ? 'Envoyer le code' : 'Send code')),
                ),
                const SizedBox(height: 8),
                if (_codeSent) ...[
                  TextButton(
                    onPressed: (_cooldown > 0 || authState.isLoading) ? null : () => _send(school.schoolId, school.languageMode),
                    child: Text(_cooldown > 0 ? (fr ? 'Renvoyer le code dans ${_cooldown}s' : 'Resend code in ${_cooldown}s') : (fr ? 'Renvoyer le code' : 'Resend code')),
                  ),
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      _code.clear();
                      ref.read(authControllerProvider.notifier).clearError();
                      setState(() {
                        _codeSent = false;
                        _cooldown = 0;
                      });
                    },
                    child: Text(fr ? 'Changer de numéro' : 'Change number'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: Text(fr ? 'Utiliser e-mail ou Google' : 'Use email or Google instead'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

enum _Step { email, code, newPassword, done, waitingForLink }

/// Forgot / reset password.
///  /auth/forgot : email -> (code from the email) -> new password -> done
///  /auth/reset  : the email's link lands here -> new password -> done
/// The code route works from any browser or device; the link only works
/// in the browser that requested it.
class PasswordRecoveryPage extends ConsumerStatefulWidget {
  final bool fromLink;
  final String initialEmail;
  const PasswordRecoveryPage({super.key, this.fromLink = false, this.initialEmail = ''});

  @override
  ConsumerState<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends ConsumerState<PasswordRecoveryPage> {
  final _emailForm = GlobalKey<FormState>();
  final _passForm = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true, _obscure2 = true;
  late _Step _step = widget.fromLink ? _Step.waitingForLink : _Step.email;
  int _cooldown = 0;
  Timer? _timer;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).clearError();
      if (widget.fromLink) _handleLink();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _fr => ref.read(activeLocaleProvider).languageCode == 'fr';

  Future<void> _handleLink() async {
    // Errors (expired / already used link) come back in the query or the
    // fragment of the address.
    final params = <String, String>{...Uri.base.queryParameters};
    try {
      if (Uri.base.fragment.contains('=')) params.addAll(Uri(query: Uri.base.fragment).queryParameters);
    } catch (_) {}
    if (params.containsKey('error') || params.containsKey('error_code')) {
      _failLink();
      return;
    }
    final ok = await ref.read(authRepositoryProvider).waitForSession();
    if (!mounted) return;
    if (ok) {
      setState(() => _step = _Step.newPassword);
    } else {
      _failLink();
    }
  }

  void _failLink() {
    if (!mounted) return;
    setState(() {
      _linkError = _fr
          ? 'Ce lien est invalide, expiré ou ouvert dans un autre navigateur. Demandez un nouveau code.'
          : 'This link is invalid, expired, or was opened in a different browser. Request a new code.';
      _step = _Step.email;
    });
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

  Future<void> _sendEmail() async {
    if (_step == _Step.email && !_emailForm.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text.trim());
    if (!mounted || !ok) return;
    setState(() {
      _step = _Step.code;
      _linkError = null;
    });
    _startCooldown();
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (code.length < 6) return;
    final ok = await ref.read(authControllerProvider.notifier).verifyRecoveryCode(email: _email.text.trim(), code: code);
    if (!mounted) return;
    if (ok) {
      setState(() => _step = _Step.newPassword);
    } else {
      _code.clear();
    }
  }

  Future<void> _savePassword() async {
    if (!_passForm.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).updatePassword(_pass.text);
    if (!mounted || !ok) return;
    setState(() => _step = _Step.done);
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
        final (title, hint) = switch (_step) {
          _Step.email => (
              fr ? 'Mot de passe oublié' : 'Forgot password',
              fr ? 'Entrez votre e-mail. Nous vous enverrons un code et un lien pour le réinitialiser.' : "Enter your email. We'll send you a code and a link to reset it.",
            ),
          _Step.code => (
              fr ? 'Vérifiez votre e-mail' : 'Check your email',
              fr ? 'Entrez le code reçu à ${_email.text.trim()}, ou ouvrez le lien dans le même navigateur.' : 'Enter the code we sent to ${_email.text.trim()}, or open the link in this same browser.',
            ),
          _Step.newPassword => (
              fr ? 'Nouveau mot de passe' : 'New password',
              fr ? 'Choisissez un mot de passe d\'au moins 8 caractères.' : 'Choose a password of at least 8 characters.',
            ),
          _Step.done => (
              fr ? 'Mot de passe mis à jour' : 'Password updated',
              fr ? 'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.' : 'You can now sign in with your new password.',
            ),
          _Step.waitingForLink => (fr ? 'Vérification du lien…' : 'Checking your link…', ''),
        };

        return AuthScaffold(
          school: school,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Column(
              key: ValueKey(_step),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthBrandingHeader(school: school, subtitle: title),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final theme = Theme.of(context);
                    return Text(hint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline));
                  }),
                ],
                const SizedBox(height: 22),
                ..._body(school.schoolId, fr, authState),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(String schoolId, bool fr, AuthState authState) {
    final banner = AuthErrorBanner(
      message: authState.errorMessage ?? _linkError,
      onDismiss: () {
        ref.read(authControllerProvider.notifier).clearError();
        if (_linkError != null) setState(() => _linkError = null);
      },
    );
    final loading = authState.isLoading;

    switch (_step) {
      case _Step.waitingForLink:
        return const [Center(child: CircularProgressIndicator())];

      case _Step.email:
        return [
          Form(
            key: _emailForm,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => loading ? null : _sendEmail(),
              decoration: InputDecoration(labelText: fr ? 'Adresse e-mail' : 'Email', prefixIcon: const Icon(Icons.email_outlined)),
              validator: (v) => (v == null || !v.contains('@')) ? (fr ? 'Entrez une adresse e-mail valide' : 'Enter a valid email') : null,
            ),
          ),
          banner,
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : _sendEmail,
            child: loading ? const AuthButtonSpinner() : Text(fr ? 'Envoyer le code' : 'Send code'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.go('/sign-in'), child: Text(fr ? 'Retour à la connexion' : 'Back to sign in')),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              fr ? 'Inscrit avec un numéro de téléphone ? Utilisez « Continuer avec le téléphone » sur la page de connexion.' : 'Signed up with a phone number? Use "Continue with phone" on the sign-in page instead.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ];

      case _Step.code:
        return [
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 8),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => loading ? null : _verifyCode(),
          ),
          banner,
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (loading || _code.text.trim().length < 6) ? null : _verifyCode,
            child: loading ? const AuthButtonSpinner() : Text(fr ? 'Vérifier le code' : 'Verify code'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_cooldown > 0 || loading) ? null : _sendEmail,
            child: Text(_cooldown > 0 ? (fr ? 'Renvoyer dans ${_cooldown}s' : 'Resend in ${_cooldown}s') : (fr ? 'Renvoyer le code' : 'Resend code')),
          ),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              _code.clear();
              ref.read(authControllerProvider.notifier).clearError();
              setState(() {
                _step = _Step.email;
                _cooldown = 0;
              });
            },
            child: Text(fr ? 'Changer d\'e-mail' : 'Change email'),
          ),
        ];

      case _Step.newPassword:
        return [
          Form(
            key: _passForm,
            child: Column(children: [
              TextFormField(
                controller: _pass,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: fr ? 'Nouveau mot de passe' : 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8) ? (fr ? 'Au moins 8 caractères.' : 'At least 8 characters.') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure2,
                onFieldSubmitted: (_) => loading ? null : _savePassword(),
                decoration: InputDecoration(
                  labelText: fr ? 'Confirmer le mot de passe' : 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: (v) => v != _pass.text ? (fr ? 'Les mots de passe ne correspondent pas.' : 'Passwords do not match.') : null,
              ),
            ]),
          ),
          banner,
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : _savePassword,
            child: loading ? const AuthButtonSpinner() : Text(fr ? 'Enregistrer le mot de passe' : 'Save password'),
          ),
        ];

      case _Step.done:
        return [
          Center(
            child: Builder(builder: (context) => Icon(Icons.check_circle_rounded, size: 64, color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: () => context.go('/sign-in'), child: Text(fr ? 'Se connecter' : 'Sign in')),
        ];
    }
  }
}

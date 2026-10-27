import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'super_admin_home.dart';
import 'super_admin_providers.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

class SuperAdminAuthGate extends ConsumerStatefulWidget {
  const SuperAdminAuthGate({super.key});

  @override
  ConsumerState<SuperAdminAuthGate> createState() => _SuperAdminAuthGateState();
}

class _SuperAdminAuthGateState extends ConsumerState<SuperAdminAuthGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      ref.invalidate(superAdminProfileProvider);
      final profile = await ref.read(superAdminProfileProvider.future);
      if (profile == null) {
        await Supabase.instance.client.auth.signOut();
        throw Exception('This account is not registered as a platform administrator.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message.toLowerCase().contains('invalid') ? 'Incorrect email or password.' : e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: superAdminTheme(),
      child: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) return _loginScreen();

          final profileAsync = ref.watch(superAdminProfileProvider);
          return profileAsync.when(
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (e, _) => _loginScreen(error: '$e'.replaceFirst('Exception: ', '')),
            data: (profile) {
              if (profile == null) return _loginScreen(error: 'This account is not registered as a platform administrator.');
              return const SuperAdminHome();
            },
          );
        },
      ),
    );
  }

  Widget _loginScreen({String? error}) {
    final shown = error ?? _error;

    final form = SaReveal(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Sa.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Sa.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 48, offset: const Offset(0, 24))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Sa.primary, Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Sa.primary.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 24),
              const Text('Welcome back', style: TextStyle(color: Sa.text, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              const SizedBox(height: 6),
              const Text('Sign in to the platform administration.', style: TextStyle(color: Sa.muted, fontSize: 14)),
              const SizedBox(height: 28),
              SaField(controller: _email, label: 'Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              SaField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                onSubmitted: (_) => _signIn(),
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: shown == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Sa.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Sa.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(shown, style: const TextStyle(color: Sa.danger, fontSize: 13))),
                          ]),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Sign in', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 18),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_outlined, size: 14, color: Sa.faint),
                SizedBox(width: 6),
                Text('Restricted to platform administrators', style: TextStyle(color: Sa.faint, fontSize: 12)),
              ]),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth <= 900) {
          return Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Sa.bg, Color(0xFF1E1B4B)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: form)),
          );
        }
        return Row(children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF312E81), Sa.bg], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              padding: const EdgeInsets.all(64),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.hub_rounded, color: Colors.white, size: 44),
                const SizedBox(height: 28),
                const Text('One platform.\nEvery school.', style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.4)),
                const SizedBox(height: 18),
                Text('Onboard schools, set up their teams and structure, and keep an eye on everything from one place.', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 16, height: 1.55)),
                const SizedBox(height: 36),
                for (final t in const ['Multi-school management', 'Role-based access for every team', 'A full record of every change'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: Sa.primaryHi, size: 20),
                      const SizedBox(width: 12),
                      Text(t, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            ),
          ),
          Expanded(child: Container(color: Sa.bg, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: form)))),
        ]);
      }),
    );
  }
}
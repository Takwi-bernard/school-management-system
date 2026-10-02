import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'super_admin_home.dart';
import 'super_admin_providers.dart';
import 'super_admin_theme.dart';

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
        throw Exception('This account is not registered as a Super Admin.');
      }
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
            error: (e, _) => _loginScreen(error: '$e'),
            data: (profile) {
              if (profile == null) return _loginScreen(error: 'This account is not registered as a Super Admin.');
              return const SuperAdminHome();
            },
          );
        },
      ),
    );
  }

  Widget _loginScreen({String? error}) {
    final theme = Theme.of(context);
    final displayedError = error ?? _error;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 24),
            const Text('Platform Administration', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Sign in to manage schools on the platform.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            const SizedBox(height: 32),
            _field(
              controller: _email,
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              onSubmit: (_) => _signIn(),
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            if (displayedError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(displayedError, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          if (!isWide) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: form)),
            );
          }
          return Row(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF312E81), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hub_outlined, color: Colors.white, size: 48),
                      const SizedBox(height: 24),
                      const Text('School Management\nPlatform', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Onboard schools, configure their structure, and oversee the platform from one place.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: form)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    void Function(String)? onSubmit,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmit,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
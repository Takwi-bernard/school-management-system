import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'super_admin_home.dart';
import 'super_admin_providers.dart';
import 'super_admin_theme.dart';

/// The ONLY entry point into this whole module. No sign-up, no
/// school-domain resolution, no branding fetch of any kind.
class SuperAdminAuthGate extends ConsumerStatefulWidget {
  const SuperAdminAuthGate({super.key});

  @override
  ConsumerState<SuperAdminAuthGate> createState() => _SuperAdminAuthGateState();
}

class _SuperAdminAuthGateState extends ConsumerState<SuperAdminAuthGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Force a re-check of super_admins immediately after sign-in -
      // identity alone is not enough, membership in super_admins is
      // the real gate.
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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 56, color: Colors.white70),
                const SizedBox(height: 16),
                const Text('Platform Administration', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                if (error != null || _error != null) ...[
                  const SizedBox(height: 14),
                  Text(error ?? _error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
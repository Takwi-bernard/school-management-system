import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'super_admin_providers.dart';
import 'super_admin_theme.dart';
import 'super_admin_ui.dart';

class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key});

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<SettingsSection> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// 0..4 simple strength score.
  int _score(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  Future<void> _change() async {
    final client = Supabase.instance.client;
    final email = client.auth.currentUser?.email;
    if (email == null) return;
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_next.text.length < 10) {
      setState(() => _error = 'Use at least 10 characters for the new password.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'The two new passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Re-check the current password before changing it.
      await client.auth.signInWithPassword(email: email, password: _current.text);
      await client.auth.updateUser(UserAttributes(password: _next.text));
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) saToast(context, 'Password changed.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message.toLowerCase().contains('invalid login') ? 'Your current password is not correct.' : e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(superAdminProfileProvider).valueOrNull;
    final user = Supabase.instance.client.auth.currentUser;
    final score = _score(_next.text);
    final labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [Sa.danger, Sa.danger, Sa.warning, Sa.info, Sa.success];

    return SaPage(
      title: 'Settings',
      subtitle: 'Your account and security.',
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 860;
          final account = SaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SaAvatar(profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Admin', size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(profile?.fullName ?? '', style: const TextStyle(color: Sa.text, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const SaChip('Platform administrator', tone: SaTone.primary, icon: Icons.shield_rounded),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              const Divider(),
              SaKeyValue('Email', user?.email, copyable: true),
              SaKeyValue('Last sign-in', user?.lastSignInAt == null ? null : saDateTime(DateTime.tryParse(user!.lastSignInAt!) ?? DateTime.now())),
              SaKeyValue('Account ID', user?.id, copyable: true),
            ]),
          );
          final security = SaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.lock_outline_rounded, color: Sa.primaryHi, size: 20),
                SizedBox(width: 10),
                Text('Change password', style: TextStyle(color: Sa.text, fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
              const SizedBox(height: 16),
              SaField(controller: _current, label: 'Current password', icon: Icons.key_rounded, obscure: !_show),
              const SizedBox(height: 12),
              SaField(
                controller: _next,
                label: 'New password',
                icon: Icons.lock_outline_rounded,
                obscure: !_show,
                onChanged: (_) => setState(() {}),
                suffix: IconButton(onPressed: () => setState(() => _show = !_show), icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20)),
              ),
              if (_next.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 200), height: 4, decoration: BoxDecoration(color: i < score ? colors[score] : Colors.white12, borderRadius: BorderRadius.circular(4)))),
                    if (i < 3) const SizedBox(width: 5),
                  ],
                  const SizedBox(width: 12),
                  Text(labels[score], style: TextStyle(color: colors[score], fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ],
              const SizedBox(height: 12),
              SaField(controller: _confirm, label: 'Confirm new password', icon: Icons.lock_outline_rounded, obscure: !_show, onSubmitted: (_) => _change()),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Sa.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: const TextStyle(color: Sa.danger, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _change,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update password'),
                ),
              ),
            ]),
          );
          if (!wide) return Column(children: [account, const SizedBox(height: 18), security]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: account), const SizedBox(width: 18), Expanded(child: security)]);
        }),
        const SizedBox(height: 18),
        SaCard(
          child: Row(children: [
            const Icon(Icons.logout_rounded, color: Sa.muted),
            const SizedBox(width: 14),
            const Expanded(child: Text('Sign out of this device', style: TextStyle(color: Sa.text, fontWeight: FontWeight.w700))),
            OutlinedButton(
              onPressed: () async {
                final ok = await saConfirm(context, title: 'Sign out?', message: 'You will need to sign in again to manage the platform.', confirmLabel: 'Sign out', icon: Icons.logout_rounded);
                if (ok) await Supabase.instance.client.auth.signOut();
              },
              child: const Text('Sign out'),
            ),
          ]),
        ),
      ],
    );
  }
}
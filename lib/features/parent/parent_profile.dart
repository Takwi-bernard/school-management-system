import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

class ParentProfilePage extends ConsumerWidget {
  const ParentProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider).value;
    if (landing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final profileAsync = ref.watch(parentProfileProvider);

    return Theme(
      data: buildSchoolTheme(landing.primaryColor, landing.secondaryColor),
      child: Scaffold(
        appBar: AppBar(title: Text(strings.myProfile)),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (profile) {
            if (profile == null) return Center(child: Text(strings.profileNotFound));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                brandedSubpageHeader(context, schoolName: landing.schoolName, logoUrl: landing.logoUrl),
                _ProfileHeader(profile: profile),
                const SizedBox(height: 20),
                _EditableInfoCard(profile: profile, strings: strings),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: Icons.lock_outline_rounded,
                  title: strings.changePassword,
                  subtitle: strings.isFrench
                      ? 'Vous devrez confirmer votre mot de passe actuel.'
                      : 'You will need to confirm your current password.',
                  onTap: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.logout_rounded,
                  title: strings.signOut,
                  subtitle: strings.isFrench
                      ? 'Vous devrez vous reconnecter pour continuer.'
                      : 'You will need to sign in again to continue.',
                  isDestructive: true,
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/');
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ParentProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = profile.fullName.trim().isEmpty
        ? 'P'
        : profile.fullName.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primary,
            child: Text(initials, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(height: 14),
          Text(profile.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(profile.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _EditableInfoCard extends ConsumerStatefulWidget {
  final ParentProfile profile;
  final AppStrings strings;
  const _EditableInfoCard({required this.profile, required this.strings});

  @override
  ConsumerState<_EditableInfoCard> createState() => _EditableInfoCardState();
}

class _EditableInfoCardState extends ConsumerState<_EditableInfoCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _nameController.addListener(() => setState(() => _dirty = true));
    _phoneController.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(parentProfileActionsProvider).updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.profileUpdatedMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.strings.profileSaveError} ($e)')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.strings.personalInformation, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            widget.strings.isFrench
                ? 'Ces informations sont utilisées par l\'école pour vous contacter au sujet de votre enfant.'
                : 'This information is used by the school to contact you about your child.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: widget.strings.fullName,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: widget.strings.phoneNumber,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_dirty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.strings.saveChanges),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(parentProfileActionsProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _newPass.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    return AlertDialog(
      title: Text(strings.changePassword),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.isFrench
                  ? 'Entrez votre mot de passe actuel, puis choisissez-en un nouveau.'
                  : 'Enter your current password, then choose a new one.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(labelText: strings.currentPassword),
              validator: (v) => (v == null || v.isEmpty) ? strings.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPass,
              obscureText: true,
              decoration: InputDecoration(labelText: strings.newPassword),
              validator: (v) => (v == null || v.length < 8) ? strings.passwordTooShort : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(labelText: strings.confirmPassword),
              validator: (v) => v != _newPass.text ? strings.passwordsDoNotMatch : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: Text(strings.cancel)),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(strings.saveChanges),
        ),
      ],
    );
  }
}
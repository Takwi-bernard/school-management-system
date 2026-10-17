import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_management_system/features/landing/landing_providers.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/sign_out_button.dart';
import '../principal/principal_core.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_repository.dart' show WrongPasswordException;
import 'parent_ui.dart';

/// Profile: personal information, password change (sheet) and sign out.
class ParentProfileTab extends ConsumerWidget {
  const ParentProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final fr = strings.isFrench;
    final profileAsync = ref.watch(parentProfileProvider);

    return PrPage(
      maxWidth: 640,
      onRefresh: () async {
        ref.invalidate(parentProfileProvider);
        await ref.read(parentProfileProvider.future).catchError((_) => null);
      },
      children: [
        PrHeader(
          title: strings.myProfile,
          subtitle: fr ? 'Vos informations personnelles et la sécurité de votre compte.' : 'Your personal information and account security.',
        ),
        const SizedBox(height: 16),
        PaAsync<ParentProfile?>(
          value: profileAsync,
          strings: strings,
          onRetry: () => ref.invalidate(parentProfileProvider),
          rows: 3,
          rowHeight: 120,
          isEmpty: (p) => p == null,
          empty: PaEmpty(icon: Icons.person_off_outlined, title: strings.profileNotFound),
          builder: (profile) {
            final p = profile!;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ProfileHeader(profile: p),
              const SizedBox(height: 16),
              PrReveal(index: 1, child: _EditableInfoCard(key: ValueKey(p.fullName + (p.phone ?? '')), profile: p, strings: strings)),
              const SizedBox(height: 14),
              PrReveal(
                index: 2,
                child: PrCard(
                  onTap: () => pnSheet<void>(context, (_) => const _ChangePasswordSheet()),
                  child: Row(children: [
                    const PaIconBadge(icon: Icons.lock_outline_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(strings.changePassword, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          fr ? 'Vous devrez confirmer votre mot de passe actuel.' : 'You will need to confirm your current password.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                        ),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              SignOutButton(strings: strings),
            ]);
          },
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ParentProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrReveal(
      child: PrCard(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            PrAvatar(name: profile.fullName, radius: 40),
            const SizedBox(height: 14),
            Text(profile.fullName, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(profile.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ]),
        ),
      ),
    );
  }
}

class _EditableInfoCard extends ConsumerStatefulWidget {
  final ParentProfile profile;
  final AppStrings strings;
  const _EditableInfoCard({super.key, required this.profile, required this.strings});

  @override
  ConsumerState<_EditableInfoCard> createState() => _EditableInfoCardState();
}

class _EditableInfoCardState extends ConsumerState<_EditableInfoCard> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
    _name.addListener(_changed);
    _phone.addListener(_changed);
  }

  void _changed() => setState(() {});

  bool get _dirty => _name.text.trim() != widget.profile.fullName || _phone.text.trim() != (widget.profile.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(parentProfileActionsProvider).updateProfile(fullName: _name.text.trim(), phone: _phone.text.trim());
      if (mounted) prSnack(context, widget.strings.profileUpdatedMessage);
    } catch (e) {
      if (mounted) prSnack(context, '${widget.strings.profileSaveError} (${paMessage(e)})');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.strings;
    return PrCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.personalInformation, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          s.isFrench
              ? 'Ces informations sont utilisées par l\'école pour vous contacter au sujet de votre enfant.'
              : 'This information is used by the school to contact you about your child.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: pnDeco(s.fullName, icon: Icons.person_outline_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: pnDeco(s.phoneNumber, icon: Icons.phone_outlined)),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _dirty
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.saveChanges),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
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
    final strings = AppStrings(ref.read(activeLocaleProvider));
    try {
      await ref.read(parentProfileActionsProvider).changePassword(currentPassword: _current.text, newPassword: _newPass.text);
      if (mounted) {
        Navigator.pop(context);
        prSnack(context, strings.isFrench ? 'Mot de passe mis à jour.' : 'Password updated.');
      }
    } on WrongPasswordException {
      if (mounted) setState(() => _error = strings.isFrench ? 'Votre mot de passe actuel est incorrect.' : 'Your current password is incorrect.');
    } catch (e) {
      if (mounted) setState(() => _error = paMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final cs = Theme.of(context).colorScheme;
    return PnSheetBody(
      title: strings.changePassword,
      subtitle: strings.isFrench ? 'Entrez votre mot de passe actuel, puis choisissez-en un nouveau.' : 'Enter your current password, then choose a new one.',
      children: [
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: pnDeco(strings.currentPassword, icon: Icons.lock_outline_rounded),
              validator: (v) => (v == null || v.isEmpty) ? strings.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPass,
              obscureText: true,
              decoration: pnDeco(strings.newPassword, icon: Icons.key_rounded),
              validator: (v) => (v == null || v.length < 8) ? strings.passwordTooShort : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: pnDeco(strings.confirmPassword, icon: Icons.key_rounded),
              validator: (v) => v != _newPass.text ? strings.passwordsDoNotMatch : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: cs.error, fontSize: 12.5))),
            ],
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: Text(strings.cancel)),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(strings.saveChanges),
        ),
      ],
    );
  }
}

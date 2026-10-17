import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../principal/principal_core.dart';
import '../principal/principal_kit.dart';
import '../proprietor/proprietor_ui.dart';
import 'secretary_models.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

class SecretaryProfilePage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  const SecretaryProfilePage({super.key, required this.schoolId, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(secretaryProfileProvider);
    return profileAsync.when(
      skipLoadingOnReload: true,
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrPage(maxWidth: 640, children: [SxError(error: e, strings: strings, onRetry: () => ref.invalidate(secretaryProfileProvider))]),
      data: (p) {
        if (p == null) {
          return PrPage(maxWidth: 640, children: [PrCard(child: SxEmpty(icon: Icons.person_off_outlined, title: strings.profileNotFound))]);
        }
        return _ProfileForm(profile: p, strings: strings);
      },
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  final SecretaryProfile profile;
  final AppStrings strings;
  const _ProfileForm({required this.profile, required this.strings});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;
  bool _uploading = false;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (mounted) prSnack(context, message);
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      await ref.read(secretaryRepositoryProvider).uploadProfilePhoto(
            schoolId: widget.profile.schoolId,
            userId: widget.profile.userId,
            bytes: bytes,
            extension: ext,
          );
      ref.invalidate(secretaryProfileProvider);
      _snack(_s.photoUpdatedMessage);
    } catch (_) {
      _snack(_s.photoUploadError);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final phone = _phone.text.trim();
      await ref.read(secretaryRepositoryProvider).updateProfile(
            secretaryId: widget.profile.secretaryId,
            fullName: _name.text.trim(),
            phone: phone.isEmpty ? null : phone,
          );
      ref.invalidate(secretaryProfileProvider);
      _snack(_s.profileUpdatedMessage);
    } catch (_) {
      _snack(_s.profileSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = widget.profile;

    return PrPage(
      maxWidth: 640,
      children: [
        PrHeader(title: _s.myProfile, subtitle: _s.personalInformation),
        PrReveal(
          index: 1,
          child: PrCard(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              Stack(children: [
                PnAvatar(stored: p.photoUrl, name: p.fullName, radius: 54, bucket: pnStaffPhotos),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: cs.primary,
                    shape: CircleBorder(side: BorderSide(color: cs.surface, width: 3)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploading ? null : _changePhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: _uploading
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                            : Icon(Icons.camera_alt_rounded, size: 18, color: cs.onPrimary),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Text(p.fullName, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              PnChip(label: _s.sSecretaryRole, color: cs.primary, icon: Icons.badge_rounded),
              const SizedBox(height: 6),
              Text(_s.sChangePhotoLabel, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        PrReveal(
          index: 2,
          child: PnPanel(
            title: _s.personalInformation,
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: pnDeco(_s.fullName, icon: Icons.person_outline_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: pnDeco(_s.sPhoneOptionalLabel, icon: Icons.phone_outlined),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: p.email ?? '',
                  enabled: false,
                  decoration: pnDeco(_s.sAccountEmailLabel, icon: Icons.mail_outline_rounded),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _saving ? null : _save,
                    child: PnBusyLabel(busy: _saving, label: _s.saveChanges),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

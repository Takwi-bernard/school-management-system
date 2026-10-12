import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';

class ProprietorProfilePage extends ConsumerWidget {
  final AppStrings strings;
  const ProprietorProfilePage({super.key, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(proprietorProfileProvider);
    return async.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: strings, onRetry: () => ref.invalidate(proprietorProfileProvider)),
      data: (p) => p == null ? PrEmpty(icon: Icons.person_off_outlined, title: strings.prProfileMissing) : _Form(profile: p, strings: strings),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  final ProprietorProfile profile;
  final AppStrings strings;
  const _Form({required this.profile, required this.strings});

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.profile.fullName);
  late final TextEditingController _phone = TextEditingController(text: widget.profile.phone ?? '');
  bool _saving = false;
  bool _uploading = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      await ref.read(proprietorRepositoryProvider).uploadProfilePhoto(
            schoolId: widget.profile.schoolId,
            userId: widget.profile.userId,
            bytes: bytes,
            extension: ext,
          );
      ref.invalidate(proprietorProfileProvider);
      if (mounted) prSnack(context, _s.prPhotoUpdated);
    } catch (_) {
      if (mounted) prSnack(context, _s.prPhotoError);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final phone = _phone.text.trim();
      await ref.read(proprietorRepositoryProvider).updateProfile(
            proprietorId: widget.profile.proprietorId,
            fullName: _name.text.trim(),
            phone: phone.isEmpty ? null : phone,
          );
      ref.invalidate(proprietorProfileProvider);
      if (mounted) prSnack(context, _s.prProfileSaved);
    } catch (_) {
      if (mounted) prSnack(context, _s.prProfileSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final photo = widget.profile.photoUrl;
    final initial = widget.profile.fullName.trim().isNotEmpty ? widget.profile.fullName.trim()[0].toUpperCase() : '?';

    InputDecoration deco(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));

    return PrPage(
      maxWidth: 620,
      children: [
        PrHeader(title: s.prProfile, subtitle: s.prProfileDesc),
        PrReveal(
          child: PrCard(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _key,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: cs.primary,
                      backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo == null || photo.isEmpty ? Text(initial, style: TextStyle(color: cs.onPrimary, fontSize: 40, fontWeight: FontWeight.w800)) : null,
                    ),
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
                ),
                const SizedBox(height: 8),
                Center(child: Text(s.prChangePhoto, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
                const SizedBox(height: 24),
                TextFormField(controller: _name, decoration: deco(s.prFullName), validator: (v) => (v == null || v.trim().isEmpty) ? s.prRequiredField : null),
                const SizedBox(height: 14),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: deco(s.prPhone)),
                const SizedBox(height: 14),
                TextFormField(initialValue: widget.profile.email ?? '', enabled: false, decoration: deco(s.prEmail)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(s.prSave),
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
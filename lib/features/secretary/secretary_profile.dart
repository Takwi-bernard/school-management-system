import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SecretaryErrorView(error: e, strings: strings, onRetry: () => ref.invalidate(secretaryProfileProvider)),
      data: (p) {
        if (p == null) {
          return SecretaryEmptyState(icon: Icons.person_off_outlined, title: strings.profileNotFound);
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final photo = widget.profile.photoUrl;
    final initial = widget.profile.fullName.trim().isNotEmpty ? widget.profile.fullName.trim()[0].toUpperCase() : '?';

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SecretaryPageHeader(title: _s.myProfile, subtitle: _s.personalInformation),
                Center(
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: theme.colorScheme.primary,
                      backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo == null || photo.isEmpty
                          ? Text(initial, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800))
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : _changePhoto,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _uploading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Center(child: Text(_s.sChangePhotoLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: _s.fullName, border: const OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: _s.sPhoneOptionalLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: widget.profile.email ?? '',
                  enabled: false,
                  decoration: InputDecoration(labelText: _s.sAccountEmailLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_s.saveChanges),
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
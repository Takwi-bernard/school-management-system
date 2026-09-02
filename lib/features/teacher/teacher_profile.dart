import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

/// Now a shell tab, not its own pushed page/Scaffold. The old
/// standalone "Sign Out" button at the bottom was removed here - it's
/// redundant now that the sidebar (desktop/tablet) and drawer
/// (mobile) always carry one, and having it twice just added clutter
/// without adding capability.
class TeacherProfileTab extends ConsumerStatefulWidget {
  final TeacherProfile profile;
  const TeacherProfileTab({super.key, required this.profile});

  @override
  ConsumerState<TeacherProfileTab> createState() => _TeacherProfileTabState();
}

class _TeacherProfileTabState extends ConsumerState<TeacherProfileTab> {
  late final _nameController = TextEditingController(text: widget.profile.fullName);
  late final _phoneController = TextEditingController(text: widget.profile.phone ?? '');
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto(AppStrings strings) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final url = await ref.read(teacherRepositoryProvider).uploadProfilePhoto(
            schoolId: widget.profile.schoolId,
            userId: widget.profile.userId,
            bytes: bytes,
            extension: ext,
          );
      await ref.read(teacherRepositoryProvider).updateProfile(
            teacherId: widget.profile.teacherId,
            photoUrl: url,
          );
      ref.invalidate(teacherProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.photoUpdatedMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.photoUploadError)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save(AppStrings strings) async {
    setState(() => _saving = true);
    try {
      await ref.read(teacherRepositoryProvider).updateProfile(
            teacherId: widget.profile.teacherId,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      ref.invalidate(teacherProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.profileUpdatedMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.profileSaveError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.profile;
    final locale = ref.watch(activeLocaleProvider);
    final strings = AppStrings(locale);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RevealOnScroll(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                      ]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white24,
                              backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                              child: p.photoUrl == null
                                  ? Text(
                                      _initials(p.fullName),
                                      style: const TextStyle(
                                          fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: HoverLift(
                                liftPixels: 2,
                                onTap: _uploadingPhoto ? null : () => _changePhoto(strings),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: _uploadingPhoto
                                      ? const SizedBox(
                                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Icon(Icons.camera_alt_rounded, size: 18, color: theme.colorScheme.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(p.fullName,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        if (p.email != null) ...[
                          const SizedBox(height: 4),
                          Text(p.email!, style: const TextStyle(color: Colors.white70)),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration:
                              BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                          child: Text(strings.teacher, style: theme.textTheme.labelMedium?.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.personalInformation,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: strings.fullName,
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: strings.phoneNumber,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : () => _save(strings),
                            child: _saving
                                ? const SizedBox(
                                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(strings.saveChanges),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
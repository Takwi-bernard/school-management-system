import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_fees.dart';

class EnrollChildPage extends ConsumerStatefulWidget {
  final String schoolId;
  const EnrollChildPage({super.key, required this.schoolId});

  @override
  ConsumerState<EnrollChildPage> createState() => _EnrollChildPageState();
}

class _EnrollChildPageState extends ConsumerState<EnrollChildPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _guardianName = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _address = TextEditingController();

  ClassOption? _selectedClass;
  final Set<String> _selectedSubjects = {};
  XFile? _photo;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _guardianName, _emergencyName, _emergencyPhone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClass == null) return;

    setState(() => _submitting = true);
    try {
      final profile = await ref.read(parentProfileProvider.future);
      if (profile == null) throw Exception('Profile not found.');

      // FIX: previously read landing.currentAcademicYear, which is a
      // DISPLAY string like "2025/2026", not a UUID - that caused a
      // Postgres "invalid input syntax for type uuid" error on submit.
      // This looks up the school's actual current academic_years.id.
      final academicYearId = await ref.read(currentAcademicYearIdProvider(widget.schoolId).future);
      if (academicYearId == null) {
        throw Exception('This school has not set a current academic year yet. Please contact the school office.');
      }

      Uint8List? photoBytes;
      String? ext;
      if (_photo != null) {
        photoBytes = await _photo!.readAsBytes();
        ext = _photo!.name.contains('.') ? _photo!.name.split('.').last : 'jpg';
      }

            final admissionRequestId = await ref.read(parentRepositoryProvider).submitAdmissionRequest(
            schoolId: widget.schoolId,
            parentId: profile.parentId,
            requestedClassId: _selectedClass!.id,
            academicYearId: academicYearId,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            guardianName: _guardianName.text.trim().isEmpty ? null : _guardianName.text.trim(),
            emergencyContactName: _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
            emergencyContactPhone: _emergencyPhone.text.trim().isEmpty ? null : _emergencyPhone.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            photoBytes: photoBytes,
            photoExtension: ext,
            selectedSubjectIds: _selectedSubjects.toList(),
          );

      if (!mounted) return;
      ref.invalidate(pendingAdmissionsProvider);

      final registrationFee = await ref.read(parentRepositoryProvider).getRegistrationFee(
            classId: _selectedClass!.id,
            academicYearId: academicYearId,
          );

      if (!mounted) return;

      final landing = ref.read(landingProvider).value;
      if (registrationFee == null || landing == null) {
        // No fee configured for this class yet - nothing to pay right
        // now, so just confirm submission and go back.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrollment submitted. The school has not set a registration fee for this class yet.')),
        );
        Navigator.pop(context);
        return;
      }

      // Explicit choice, as requested - never silently assume either way.
      final wantsToPayNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enrollment Submitted'),
          content: Text(
            'A registration fee of ${registrationFee.toStringAsFixed(0)} FCFA is required to complete this enrollment. '
            'Your child will remain pending until it is paid.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Pay Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (wantsToPayNow == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MobileMoneyPaymentPage(
              admissionRequestId: admissionRequestId,
              landing: landing,
              amount: registrationFee,
              paymentPurpose: 'Registration Fee',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can complete the registration fee anytime from your dashboard.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = ref.watch(activeLocaleProvider);
    final strings = AppStrings(locale);
    final classesAsync = ref.watch(availableClassesProvider(widget.schoolId));

    return Scaffold(
      appBar: AppBar(title: Text(strings.enrollMyChild)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: _photo == null
                            ? Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary)
                            : ClipOval(child: Image.network(_photo!.path, width: 88, height: 88, fit: BoxFit.cover)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _firstName,
                    decoration: InputDecoration(labelText: strings.childFirstName, border: const OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? strings.required : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lastName,
                    decoration: InputDecoration(labelText: strings.childLastName, border: const OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? strings.required : null,
                  ),
                  const SizedBox(height: 14),

                  // DYNAMIC CLASS DROPDOWN - straight from this school's
                  // own `classes` table, never hardcoded.
                  classesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (classes) => DropdownButtonFormField<ClassOption>(
                      initialValue: _selectedClass,
                      decoration: InputDecoration(labelText: strings.requestedClass, border: const OutlineInputBorder()),
                      items: classes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.className)))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selectedClass = value;
                        _selectedSubjects.clear(); // reset - a new class may offer different subjects
                      }),
                      validator: (v) => v == null ? strings.required : null,
                    ),
                  ),

                  // DYNAMIC SUBJECT SELECTION - only appears if THIS
                  // class/department actually has offerings configured.
                  // Compulsory subjects are pre-checked and locked.
                  if (_selectedClass != null)
                    Consumer(
                      builder: (context, ref, _) {
                        final offeringsAsync = ref.watch(subjectOfferingsProvider(
                          (classId: _selectedClass!.id, departmentId: _selectedClass!.departmentId),
                        ));
                        return offeringsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => const SizedBox(),
                          data: (offerings) {
                            if (offerings.isEmpty) return const SizedBox(); // nothing configured - skip step entirely

                            // Auto-select compulsory ones once, on first load.
                            for (final o in offerings.where((o) => o.isCompulsory)) {
                              _selectedSubjects.add(o.subjectId);
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(strings.chooseSubjects,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(strings.compulsorySubjectsNote,
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                  const SizedBox(height: 12),
                                  ...offerings.map((o) => CheckboxListTile(
                                        value: _selectedSubjects.contains(o.subjectId),
                                        title: Text(o.subjectName),
                                        subtitle: o.isCompulsory ? Text(strings.compulsory) : null,
                                        onChanged: o.isCompulsory
                                            ? null // locked - can't be unchecked
                                            : (checked) => setState(() {
                                                  if (checked == true) {
                                                    _selectedSubjects.add(o.subjectId);
                                                  } else {
                                                    _selectedSubjects.remove(o.subjectId);
                                                  }
                                                }),
                                      )),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 24),
                  Text(strings.guardianInformation, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _guardianName,
                    decoration: InputDecoration(labelText: strings.guardianName, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emergencyName,
                    decoration: InputDecoration(labelText: strings.emergencyContactName, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emergencyPhone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: strings.emergencyContactPhone, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: strings.address, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: HoverLift(
                      onTap: _submitting ? null : _submit,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(14)),
                        child: _submitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(strings.submitEnrollment, style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
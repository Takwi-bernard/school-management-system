import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'parent_fees.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

class EnrollChildPage extends ConsumerStatefulWidget {
  final String schoolId;
  const EnrollChildPage({super.key, required this.schoolId});

  @override
  ConsumerState<EnrollChildPage> createState() => _EnrollChildPageState();
}

class _EnrollChildPageState extends ConsumerState<EnrollChildPage> {
  int _step = 0;
  bool _submitting = false;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _dateOfBirth;
  XFile? _photo;

  ClassOption? _selectedClass;
  final Set<String> _selectedSubjects = {};
  List<SubjectOfferingOption> _offerings = [];
  bool _offeringsLoaded = false;

  final _guardianName = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _address = TextEditingController();

  final _childInfoKey = GlobalKey<FormState>();

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _guardianName, _emergencyName, _emergencyPhone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Whether the subject-selection step should exist at all for the
  /// currently selected class - decided dynamically per the school's
  /// own subject_offerings configuration, never assumed.
  bool get _hasSubjectStep => _offeringsLoaded && _offerings.isNotEmpty;

  List<String> _stepTitles(AppStrings strings) => [
        strings.isFrench ? 'Enfant' : 'Child',
        strings.isFrench ? 'Classe' : 'Class',
        if (_hasSubjectStep) strings.isFrench ? 'Matières' : 'Subjects',
        strings.isFrench ? 'Tuteur' : 'Guardian',
        strings.isFrench ? 'Vérifier' : 'Review',
      ];

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _onClassSelected(ClassOption option) async {
    setState(() {
      _selectedClass = option;
      _selectedSubjects.clear();
      _offeringsLoaded = false;
    });
    final offerings = await ref.read(
      subjectOfferingsProvider((classId: option.id, departmentId: option.departmentId)).future,
    );
    if (!mounted) return;
    setState(() {
      _offerings = offerings;
      _offeringsLoaded = true;
      for (final o in offerings.where((o) => o.isCompulsory)) {
        _selectedSubjects.add(o.subjectId);
      }
    });
  }

  int get _totalSteps => _hasSubjectStep ? 5 : 4;

  void _goNext() {
    if (_step == 0 && !_childInfoKey.currentState!.validate()) return;
    if (_step == 1 && _selectedClass == null) return;
    setState(() => _step++);
  }

  void _goBack() => setState(() => _step--);

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final profile = await ref.read(parentProfileProvider.future);
      if (profile == null) throw Exception('Profile not found.');

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
            dateOfBirth: _dateOfBirth,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrollment submitted. The school has not set a registration fee for this class yet.')),
        );
        Navigator.pop(context);
        return;
      }

      final wantsToPayNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enrollment Submitted'),
          content: Text(
            'A registration fee of ${registrationFee.toStringAsFixed(0)} FCFA is required to complete this enrollment. '
            'Your child will remain pending, and the school will not see this request, until it is paid.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Pay Later')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Pay Now')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = ref.watch(activeLocaleProvider);
    final strings = AppStrings(locale);
    final landing = ref.watch(landingProvider).value;
    final classesAsync = ref.watch(availableClassesProvider(widget.schoolId));
    final titles = _stepTitles(strings);

    return Scaffold(
      appBar: AppBar(title: Text(strings.enrollMyChild)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                if (landing != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: brandedSubpageHeader(context, schoolName: landing.schoolName, logoUrl: landing.logoUrl),
                  ),
                _StepProgress(currentStep: _step, titles: titles),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: _buildStepContent(context, theme, strings, classesAsync),
                    ),
                  ),
                ),
                _NavigationBar(
                  step: _step,
                  totalSteps: _totalSteps,
                  submitting: _submitting,
                  canGoNext: _step == 1 ? _selectedClass != null : true,
                  onBack: _step > 0 ? _goBack : null,
                  onNext: _step < _totalSteps - 1 ? _goNext : null,
                  onSubmit: _step == _totalSteps - 1 ? _submit : null,
                  strings: strings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, ThemeData theme, AppStrings strings, AsyncValue<List<ClassOption>> classesAsync) {
    // Map logical step -> which content to show, accounting for the
    // subject step only existing conditionally.
    final subjectStepIndex = 2;
    final guardianStepIndex = _hasSubjectStep ? 3 : 2;
    final reviewStepIndex = _hasSubjectStep ? 4 : 3;

    if (_step == 0) return _buildChildInfoStep(theme, strings);
    if (_step == 1) return _buildClassStep(theme, strings, classesAsync);
    if (_hasSubjectStep && _step == subjectStepIndex) return _buildSubjectStep(theme, strings);
    if (_step == guardianStepIndex) return _buildGuardianStep(theme, strings);
    if (_step == reviewStepIndex) return _buildReviewStep(theme, strings);
    return const SizedBox();
  }

  Widget _buildChildInfoStep(ThemeData theme, AppStrings strings) {
    return Form(
      key: _childInfoKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.isFrench
                ? 'Commençons par les informations de base de votre enfant.'
                : 'Let\'s start with your child\'s basic information.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: _photo == null
                        ? Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 28)
                        : ClipOval(child: Image.network(_photo!.path, width: 96, height: 96, fit: BoxFit.cover)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                      child: Icon(Icons.edit_rounded, size: 14, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              strings.isFrench ? 'Photo (facultatif)' : 'Photo (optional)',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 28),
          _ModernField(
            controller: _firstName,
            label: strings.childFirstName,
            icon: Icons.badge_outlined,
            required: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? strings.required : null,
          ),
          const SizedBox(height: 14),
          _ModernField(
            controller: _lastName,
            label: strings.childLastName,
            icon: Icons.badge_outlined,
            required: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? strings.required : null,
          ),
          const SizedBox(height: 14),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDateOfBirth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: theme.colorScheme.outline, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dateOfBirth == null
                            ? (strings.isFrench ? 'Date de naissance (facultatif)' : 'Date of birth (optional)')
                            : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                        style: TextStyle(color: _dateOfBirth == null ? theme.colorScheme.outline : null),
                      ),
                    ),
                    Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassStep(ThemeData theme, AppStrings strings, AsyncValue<List<ClassOption>> classesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.isFrench
              ? 'Quelle classe demandez-vous pour votre enfant ?'
              : 'Which class are you requesting for your child?',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 20),
        classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (classes) {
            if (classes.isEmpty) {
              return Text(
                strings.isFrench
                    ? 'L\'école n\'a pas encore configuré de classes.'
                    : 'The school has not configured any classes yet.',
              );
            }
            return Column(
              children: classes
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SelectableCard(
                          title: c.className,
                          selected: _selectedClass?.id == c.id,
                          onTap: () => _onClassSelected(c),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubjectStep(ThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.compulsorySubjectsNote, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 16),
        ..._offerings.map((o) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: CheckboxListTile(
                value: _selectedSubjects.contains(o.subjectId),
                title: Text(o.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: o.isCompulsory
                    ? Text(strings.compulsory, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12))
                    : Text(strings.isFrench ? 'Facultatif' : 'Optional', style: theme.textTheme.bodySmall),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onChanged: o.isCompulsory
                    ? null
                    : (checked) => setState(() {
                          if (checked == true) {
                            _selectedSubjects.add(o.subjectId);
                          } else {
                            _selectedSubjects.remove(o.subjectId);
                          }
                        }),
              ),
            )),
      ],
    );
  }

  Widget _buildGuardianStep(ThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.isFrench
              ? 'Ces informations aident l\'école à vous contacter en cas de besoin. Tous les champs sont facultatifs.'
              : 'This helps the school reach you when needed. All fields here are optional.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 20),
        _ModernField(controller: _guardianName, label: strings.guardianName, icon: Icons.family_restroom_outlined),
        const SizedBox(height: 14),
        _ModernField(controller: _emergencyName, label: strings.emergencyContactName, icon: Icons.contact_phone_outlined),
        const SizedBox(height: 14),
        _ModernField(
          controller: _emergencyPhone,
          label: strings.emergencyContactPhone,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _ModernField(controller: _address, label: strings.address, icon: Icons.location_on_outlined, maxLines: 2),
      ],
    );
  }

  Widget _buildReviewStep(ThemeData theme, AppStrings strings) {
    final selectedNames = _offerings.where((o) => _selectedSubjects.contains(o.subjectId)).map((o) => o.subjectName).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.isFrench
              ? 'Vérifiez les informations ci-dessous avant de soumettre.'
              : 'Review the details below before submitting.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 20),
        _ReviewCard(theme: theme, title: strings.isFrench ? 'Enfant' : 'Child', rows: {
          strings.isFrench ? 'Nom' : 'Name': '${_firstName.text} ${_lastName.text}',
          if (_dateOfBirth != null)
            (strings.isFrench ? 'Naissance' : 'Born'): '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
        }),
        const SizedBox(height: 12),
        _ReviewCard(theme: theme, title: strings.requestedClass, rows: {
          strings.isFrench ? 'Classe' : 'Class': _selectedClass?.className ?? '-',
        }),
        if (_hasSubjectStep) ...[
          const SizedBox(height: 12),
          _ReviewCard(theme: theme, title: strings.chooseSubjects, rows: {
            strings.subject: selectedNames.isEmpty ? '-' : selectedNames.join(', '),
          }),
        ],
        if (_guardianName.text.isNotEmpty || _emergencyPhone.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ReviewCard(theme: theme, title: strings.guardianInformation, rows: {
            if (_guardianName.text.isNotEmpty) strings.guardianName: _guardianName.text,
            if (_emergencyPhone.text.isNotEmpty) strings.emergencyContactPhone: _emergencyPhone.text,
          }),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.isFrench
                      ? 'Après soumission, vous pourrez payer les frais d\'inscription immédiatement ou plus tard depuis votre tableau de bord.'
                      : 'After submitting, you\'ll be able to pay the registration fee right away or later from your dashboard.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int currentStep;
  final List<String> titles;
  const _StepProgress({required this.currentStep, required this.titles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      // Compact: "Step X of N: Title" + thin progress bar - matches
      // current best practice for small screens over a full stepper.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${currentStep + 1}/${titles.length} · ${titles[currentStep]}',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (currentStep + 1) / titles.length,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      );
    }

    // Desktop: full horizontal labeled stepper.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          for (int i = 0; i < titles.length; i++) ...[
            _StepDot(index: i, label: titles[i], isCurrent: i == currentStep, isDone: i < currentStep),
            if (i < titles.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i < currentStep ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool isCurrent;
  final bool isDone;
  const _StepDot({required this.index, required this.label, required this.isCurrent, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = (isCurrent || isDone) ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('${index + 1}', style: TextStyle(color: (isCurrent || isDone) ? Colors.white : theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500)),
      ],
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final bool submitting;
  final bool canGoNext;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;
  final AppStrings strings;
  const _NavigationBar({
    required this.step,
    required this.totalSteps,
    required this.submitting,
    required this.canGoNext,
    this.onBack,
    this.onNext,
    this.onSubmit,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            OutlinedButton(
              onPressed: submitting ? null : onBack,
              child: Text(strings.isFrench ? 'Retour' : 'Back'),
            ),
          const Spacer(),
          if (onNext != null)
            HoverLift(
              onTap: canGoNext ? onNext : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: canGoNext ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  strings.isFrench ? 'Suivant' : 'Next',
                  style: TextStyle(color: canGoNext ? theme.colorScheme.onPrimary : theme.colorScheme.outline, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (onSubmit != null)
            HoverLift(
              onTap: submitting ? null : onSubmit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(14)),
                child: submitting
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : Text(strings.submitEnrollment, style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableCard({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.school_outlined, color: selected ? theme.colorScheme.primary : theme.colorScheme.outline, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? theme.colorScheme.primary : null))),
              if (selected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final Map<String, String> rows;
  const _ReviewCard({required this.theme, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          ...rows.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13))),
                    Flexible(child: Text(e.value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Modern filled/rounded field style, replacing the flat
/// OutlineInputBorder used previously - matches the card-based
/// aesthetic already used across the rest of the parent module.
class _ModernField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ModernField({
    required this.controller,
    required this.label,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? label : '$label (${theme.brightness == Brightness.dark ? '' : ''}${_optionalWord(context)})',
        prefixIcon: Icon(icon, color: theme.colorScheme.outline, size: 20),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }

  String _optionalWord(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'fr' ? 'facultatif' : 'optional';
  }
}
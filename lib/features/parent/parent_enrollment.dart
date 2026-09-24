import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
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

/// Relationship a guardian can have to the child - mirrors the
/// guardian_relationship enum in the database exactly, so the value
/// sent on submit is always one it accepts.
const _relationshipValues = ['father', 'mother', 'guardian', 'uncle', 'aunt', 'grandparent', 'sibling', 'other'];

String _relationshipLabel(String value, AppStrings strings) {
  const fr = {
    'father': 'Père',
    'mother': 'Mère',
    'guardian': 'Tuteur/Tutrice',
    'uncle': 'Oncle',
    'aunt': 'Tante',
    'grandparent': 'Grand-parent',
    'sibling': 'Frère/Sœur',
    'other': 'Autre',
  };
  const en = {
    'father': 'Father',
    'mother': 'Mother',
    'guardian': 'Guardian',
    'uncle': 'Uncle',
    'aunt': 'Aunt',
    'grandparent': 'Grandparent',
    'sibling': 'Sibling',
    'other': 'Other',
  };
  return (strings.isFrench ? fr : en)[value] ?? value;
}

class EnrollChildPage extends ConsumerStatefulWidget {
  final String schoolId;
  const EnrollChildPage({super.key, required this.schoolId});

  @override
  ConsumerState<EnrollChildPage> createState() => _EnrollChildPageState();
}

class _EnrollChildPageState extends ConsumerState<EnrollChildPage> {
  int _step = 0;
  bool _submitting = false;
  String? _gender;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _dateOfBirth;
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _photoExtension;

  // Shown only after an attempted Next with something missing - not
  // nagged proactively before the parent has even tried.
  String? _childStepError;

  ClassOption? _selectedClass;
  final Set<String> _selectedSubjects = {};
  List<SubjectOfferingOption> _offerings = [];
  bool _offeringsLoaded = false;
  bool _loadingOfferings = false;

  // null = not yet answered (the guardian step forces an explicit
  // choice rather than defaulting silently either way).
  bool? _isGuardianSelf;
  String? _guardianRelationship;
  final _guardianName = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _address = TextEditingController();
  String? _guardianStepError;

  final _childInfoKey = GlobalKey<FormState>();

  // Sign-up-time draft reconciliation - a child name/photo the parent
  // may have entered on the registration screen, before this full
  // form existed for them to fill in. Offered once, not re-shown.
  bool _draftPromptHandled = false;
  bool _draftClassMatchAttempted = false;
  String? _draftId;

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

  Future<void> _pickPhoto(AppStrings strings) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final ext = (picked.name.contains('.') ? picked.name.split('.').last : 'jpg').toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        strings.isFrench ? 'Format non pris en charge. Utilisez JPG, PNG ou WEBP.' : 'Unsupported format. Please use JPG, PNG or WEBP.',
      )));
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        strings.isFrench ? 'La photo est trop volumineuse (5 Mo maximum).' : 'That photo is too large (5 MB maximum).',
      )));
      return;
    }

    setState(() {
      _photo = picked;
      _photoBytes = bytes;
      _photoExtension = ext;
      _childStepError = null;
    });
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
      _loadingOfferings = true;
    });
    try {
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
    } finally {
      if (mounted) setState(() => _loadingOfferings = false);
    }
  }

  int get _totalSteps => _hasSubjectStep ? 5 : 4;

  int get _guardianStepIndex => _hasSubjectStep ? 3 : 2;

  bool get _canGoNext {
    if (_step == 0) return true; // validated explicitly in _goNext (needs a snackbar-worthy message, not just disabling)
    if (_step == 1) return _selectedClass != null && !_loadingOfferings;
    return true;
  }

  void _goNext(AppStrings strings) {
    if (_step == 0) {
      final formOk = _childInfoKey.currentState!.validate();
      if (!formOk || _gender == null || _photoBytes == null || _dateOfBirth == null) {
        setState(() => _childStepError = strings.isFrench
            ? 'Merci de renseigner le nom, le sexe, la date de naissance et une photo de l\'enfant.'
            : 'Please fill in the name, gender, date of birth, and a photo of the child.');
        return;
      }
      setState(() => _childStepError = null);
    }
    if (_step == 1 && (_selectedClass == null || _loadingOfferings)) return;
    if (_step == _guardianStepIndex) {
      final missingChoice = _isGuardianSelf == null;
      final missingName = _isGuardianSelf == false && _guardianName.text.trim().isEmpty;
      final missingRelationship = _guardianRelationship == null;
      if (missingChoice || missingName || missingRelationship) {
        setState(() => _guardianStepError = strings.isFrench
            ? 'Merci d\'indiquer qui est le tuteur de cet enfant et votre lien avec lui.'
            : 'Please tell us who the guardian is and their relationship to the child.');
        return;
      }
      setState(() => _guardianStepError = null);
    }
    setState(() => _step++);
  }

  void _goBack() => setState(() => _step--);

  void _maybeOfferDraft(Map<String, dynamic> draft, AppStrings strings) {
    if (_draftPromptHandled) return;
    _draftPromptHandled = true;
    final name = (draft['child_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final continueIt = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.isFrench ? 'Reprendre où vous en étiez ?' : 'Continue where you left off?'),
          content: Text(
            strings.isFrench
                ? 'Vous aviez commencé à ajouter "$name" lors de votre inscription. Voulez-vous continuer avec ces informations ?'
                : 'You started adding "$name" when you registered. Would you like to continue with that?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.isFrench ? 'Recommencer' : 'Start Fresh'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.isFrench ? 'Continuer' : 'Continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (continueIt == true) {
        setState(() {
          _firstName.text = name;
          _draftId = draft['id'] as String?;
        });
      }
    });
  }

  Future<void> _submit(AppStrings strings) async {
    setState(() => _submitting = true);
    try {
      final profile = await ref.read(parentProfileProvider.future);
      if (profile == null) {
        throw StateError(strings.isFrench
            ? 'Profil introuvable. Veuillez vous reconnecter.'
            : 'Profile not found. Please sign in again.');
      }

      final academicYearId = await ref.read(currentAcademicYearIdProvider(widget.schoolId).future);
      if (academicYearId == null) {
        throw StateError(strings.isFrench
            ? 'Cette école n\'a pas encore défini d\'année scolaire en cours. Merci de contacter le secrétariat.'
            : 'This school has not set a current academic year yet. Please contact the school office.');
      }

      final admissionRequestId = await ref.read(parentRepositoryProvider).submitAdmissionRequest(
            schoolId: widget.schoolId,
            parentId: profile.parentId,
            requestedClassId: _selectedClass!.id,
            academicYearId: academicYearId,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            gender: _gender!,
            dateOfBirth: _dateOfBirth,
            guardianName: _isGuardianSelf == true ? profile.fullName : _guardianName.text.trim(),
            guardianRelationship: _guardianRelationship,
            emergencyContactName: _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
            emergencyContactPhone: _emergencyPhone.text.trim().isEmpty ? null : _emergencyPhone.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            photoBytes: _photoBytes,
            photoExtension: _photoExtension,
            selectedSubjectIds: _selectedSubjects.toList(),
          );

      if (!mounted) return;
      ref.invalidate(pendingAdmissionsProvider);

      if (_draftId != null) {
        // Best-effort - the enrollment itself already succeeded, so a
        // failure to clean up the draft shouldn't block or alarm the
        // parent.
        unawaited(ref.read(parentRepositoryProvider).deleteChildDraft(_draftId!).catchError((e) {
          debugPrint('[EnrollChildPage] draft cleanup failed: $e');
        }));
        ref.invalidate(childDraftProvider);
      }

      final registrationFee = await ref.read(parentRepositoryProvider).getRegistrationFee(
            classId: _selectedClass!.id,
            academicYearId: academicYearId,
          );

      if (!mounted) return;
      final landing = ref.read(landingProvider).value;

      if (registrationFee == null || landing == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          strings.isFrench
              ? 'Inscription soumise. L\'école n\'a pas encore défini de frais d\'inscription pour cette classe.'
              : 'Enrollment submitted. The school has not set a registration fee for this class yet.',
        )));
        Navigator.pop(context);
        return;
      }

      final wantsToPayNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.isFrench ? 'Inscription soumise' : 'Enrollment Submitted'),
          content: Text(
            strings.isFrench
                ? 'Des frais d\'inscription de ${registrationFee.toStringAsFixed(0)} FCFA sont requis pour finaliser cette inscription. '
                    'Votre enfant restera en attente, et l\'école ne verra pas cette demande, tant qu\'ils ne sont pas payés.'
                : 'A registration fee of ${registrationFee.toStringAsFixed(0)} FCFA is required to complete this enrollment. '
                    'Your child will remain pending, and the school will not see this request, until it is paid.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.isFrench ? 'Payer plus tard' : 'Pay Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.isFrench ? 'Payer maintenant' : 'Pay Now'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          strings.isFrench
              ? 'Vous pouvez régler les frais d\'inscription à tout moment depuis votre tableau de bord.'
              : 'You can complete the registration fee anytime from your dashboard.',
        )));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final landing = ref.watch(landingProvider).value;
    final classesAsync = ref.watch(availableClassesProvider(widget.schoolId));
    final titles = _stepTitles(strings);

    // One-time offer to continue a name/photo captured at sign-up.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(childDraftProvider, (previous, next) {
      final draft = next.valueOrNull;
      if (draft != null) _maybeOfferDraft(draft, strings);
    });

    // Best-effort auto-match of the draft's requested class name, once
    // classes have actually loaded - never overrides a class the
    // parent already picked themselves.
    if (!_draftClassMatchAttempted && _selectedClass == null) {
      final draft = ref.watch(childDraftProvider).valueOrNull;
      final classes = classesAsync.valueOrNull;
      final requestedName = (draft?['requested_class_name'] as String?)?.trim();
      if (draft != null && classes != null && requestedName != null && requestedName.isNotEmpty) {
        _draftClassMatchAttempted = true;
        for (final c in classes) {
          if (c.className.toLowerCase() == requestedName.toLowerCase()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedClass == null) _onClassSelected(c);
            });
            break;
          }
        }
      }
    }

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
                  canGoNext: _canGoNext,
                  onBack: _step > 0 ? _goBack : null,
                  onNext: _step < _totalSteps - 1 ? () => _goNext(strings) : null,
                  onSubmit: _step == _totalSteps - 1 ? () => _submit(strings) : null,
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
    final subjectStepIndex = 2;
    final reviewStepIndex = _hasSubjectStep ? 4 : 3;

    if (_step == 0) return _buildChildInfoStep(theme, strings);
    if (_step == 1) return _buildClassStep(theme, strings, classesAsync);
    if (_hasSubjectStep && _step == subjectStepIndex) return _buildSubjectStep(theme, strings);
    if (_step == _guardianStepIndex) return _buildGuardianStep(theme, strings);
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
                ? 'Commençons par les informations de base de votre enfant. Tous les champs de cette étape sont obligatoires - l\'école en a besoin pour créer le dossier de votre enfant, sa carte d\'identité et ses futurs bulletins.'
                : 'Let\'s start with your child\'s basic information. Everything on this step is required - the school needs it to create your child\'s record, ID card, and future report cards.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => _pickPhoto(strings),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: _photoBytes == null
                        ? Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 28)
                        : ClipOval(child: Image.memory(_photoBytes!, width: 96, height: 96, fit: BoxFit.cover)),
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
              strings.isFrench ? 'Photo (obligatoire)' : 'Photo (required)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _photoBytes == null ? theme.colorScheme.error : theme.colorScheme.outline,
                fontWeight: _photoBytes == null ? FontWeight.w700 : FontWeight.normal,
              ),
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
                            ? (strings.isFrench ? 'Date de naissance (obligatoire)' : 'Date of birth (required)')
                            : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                        style: TextStyle(
                          color: _dateOfBirth == null ? theme.colorScheme.error : null,
                          fontWeight: _dateOfBirth == null ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GenderOption(
                  label: strings.isFrench ? 'Masculin' : 'Male',
                  selected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderOption(
                  label: strings.isFrench ? 'Féminin' : 'Female',
                  selected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ],
          ),
          if (_childStepError != null) ...[
            const SizedBox(height: 16),
            Text(_childStepError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
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
              ? 'Quelle classe demandez-vous pour votre enfant ? L\'école examinera cette demande.'
              : 'Which class are you requesting for your child? The school will review this request.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 20),
        classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            strings.isFrench ? 'Impossible de charger les classes. Veuillez réessayer.' : 'Could not load classes. Please try again.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return Text(
                strings.isFrench
                    ? 'L\'école n\'a pas encore configuré de classes.'
                    : 'The school has not configured any classes yet.',
              );
            }
            return Column(
              children: [
                ...classes.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectableCard(
                        title: c.className,
                        selected: _selectedClass?.id == c.id,
                        onTap: () => _onClassSelected(c),
                      ),
                    )),
                if (_loadingOfferings)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(
                          strings.isFrench ? 'Chargement des matières pour cette classe…' : 'Loading subjects for this class…',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubjectStep(ThemeData theme, AppStrings strings) {
    final compulsory = _offerings.where((o) => o.isCompulsory).toList();
    final optional = _offerings.where((o) => !o.isCompulsory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.isFrench
              ? 'Cette classe a des matières obligatoires pour tous les élèves, et d\'autres au choix. Faites ce choix avec votre enfant, pour être sûr(e) de sélectionner ce qu\'il/elle souhaite réellement étudier.'
              : 'This class has subjects every student takes, and others your child can choose from. Make this choice together with your child, so you pick what they\'ll actually be studying.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        if (compulsory.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(strings.compulsory, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(height: 10),
          ...compulsory.map((o) => _SubjectTile(offering: o, selected: true, onChanged: null)),
        ],
        if (optional.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            strings.isFrench ? 'Matières au choix' : 'Optional Subjects',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...optional.map((o) => _SubjectTile(
                offering: o,
                selected: _selectedSubjects.contains(o.subjectId),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selectedSubjects.add(o.subjectId);
                  } else {
                    _selectedSubjects.remove(o.subjectId);
                  }
                }),
              )),
        ],
      ],
    );
  }

  Widget _buildGuardianStep(ThemeData theme, AppStrings strings) {
    final profile = ref.watch(parentProfileProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.isFrench
              ? 'Chaque enfant doit avoir un tuteur enregistré - la personne que l\'école contactera. C\'est généralement vous-même.'
              : 'Every child needs a registered guardian - the person the school will contact. That\'s usually you.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _GenderOption(
                label: strings.isFrench ? 'C\'est moi' : 'This is me',
                selected: _isGuardianSelf == true,
                onTap: () => setState(() {
                  _isGuardianSelf = true;
                  _guardianStepError = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderOption(
                label: strings.isFrench ? 'Une autre personne' : 'Someone else',
                selected: _isGuardianSelf == false,
                onTap: () => setState(() {
                  _isGuardianSelf = false;
                  _guardianStepError = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_isGuardianSelf == true) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.person_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile?.fullName ?? (strings.isFrench ? 'Vous' : 'You'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else if (_isGuardianSelf == false) ...[
          _ModernField(controller: _guardianName, label: strings.guardianName, icon: Icons.family_restroom_outlined, required: true),
          const SizedBox(height: 14),
        ],
        if (_isGuardianSelf != null) ...[
          Text(
            strings.isFrench ? 'Quel est votre lien avec l\'enfant ?' : 'What is your relationship to the child?',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _relationshipValues.map((value) {
              final selected = _guardianRelationship == value;
              return ChoiceChip(
                label: Text(_relationshipLabel(value, strings)),
                selected: selected,
                onSelected: (_) => setState(() {
                  _guardianRelationship = value;
                  _guardianStepError = null;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          strings.isFrench
              ? 'Ces informations aident l\'école à vous joindre en cas d\'urgence. Facultatif.'
              : 'This helps the school reach someone in an emergency. Optional.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
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
        if (_guardianStepError != null) ...[
          const SizedBox(height: 16),
          Text(_guardianStepError!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  Widget _buildReviewStep(ThemeData theme, AppStrings strings) {
    final selectedNames = _offerings.where((o) => _selectedSubjects.contains(o.subjectId)).map((o) => o.subjectName).toList();
    final profile = ref.watch(parentProfileProvider).valueOrNull;
    final guardianDisplayName = _isGuardianSelf == true ? (profile?.fullName ?? '-') : _guardianName.text;

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
        if (_photoBytes != null)
          Center(
            child: CircleAvatar(radius: 36, backgroundImage: MemoryImage(_photoBytes!)),
          ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        _ReviewCard(theme: theme, title: strings.guardianInformation, rows: {
          strings.guardianName: guardianDisplayName,
          if (_guardianRelationship != null)
            (strings.isFrench ? 'Lien' : 'Relationship'): _relationshipLabel(_guardianRelationship!, strings),
          if (_emergencyPhone.text.isNotEmpty) strings.emergencyContactPhone: _emergencyPhone.text,
        }),
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

/// Simple no-op awaiter so a fire-and-forget Future's errors are still
/// caught (via .catchError at the call site) without this method
/// itself needing to be async - keeps _submit's flow linear.
void unawaited(Future<void> future) {}

class _SubjectTile extends StatelessWidget {
  final SubjectOfferingOption offering;
  final bool selected;
  final ValueChanged<bool?>? onChanged;
  const _SubjectTile({required this.offering, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: CheckboxListTile(
        value: selected,
        title: Text(offering.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onChanged: onChanged,
      ),
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

class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderOption({required this.label, required this.selected, required this.onTap});

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
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? theme.colorScheme.primary : null)),
        ),
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

/// Modern filled/rounded field style, matching the card-based
/// aesthetic used across the rest of the parent module.
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
        labelText: required ? label : '$label (${_optionalWord(context)})',
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

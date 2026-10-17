import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import '../principal/principal_core.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_fees.dart';
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';
import 'parent_ui.dart';

/// Relationship a guardian can have to the child - mirrors the
/// guardian_relationship enum in the database exactly.
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

  // Shown only after an attempted Next with something missing.
  String? _childStepError;

  ClassOption? _selectedClass;
  final Set<String> _selectedSubjects = {};
  List<SubjectOfferingOption> _offerings = [];
  bool _offeringsLoaded = false;
  bool _loadingOfferings = false;

  // null = not yet answered (the guardian step forces an explicit choice).
  bool? _isGuardianSelf;
  String? _guardianRelationship;
  final _guardianName = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _address = TextEditingController();
  String? _guardianStepError;

  final _childInfoKey = GlobalKey<FormState>();

  // Sign-up-time draft reconciliation, offered once.
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

  /// Whether the subject step exists for the selected class, decided by
  /// the school's own subject_offerings configuration.
  bool get _hasSubjectStep => _offeringsLoaded && _offerings.isNotEmpty;

  List<String> _stepTitles(AppStrings strings) => [
        strings.isFrench ? 'Enfant' : 'Child',
        strings.isFrench ? 'Classe' : 'Class',
        if (_hasSubjectStep) strings.isFrench ? 'Matières' : 'Subjects',
        strings.isFrench ? 'Tuteur' : 'Guardian',
        strings.isFrench ? 'Vérifier' : 'Review',
      ];

  Future<void> _pickPhoto(AppStrings strings) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (picked == null || !mounted) return;

    final ext = (picked.name.contains('.') ? picked.name.split('.').last : 'jpg').toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(ext)) {
      prSnack(context, strings.isFrench ? 'Format non pris en charge. Utilisez JPG, PNG ou WEBP.' : 'Unsupported format. Please use JPG, PNG or WEBP.');
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      prSnack(context, strings.isFrench ? 'La photo est trop volumineuse (5 Mo maximum).' : 'That photo is too large (5 MB maximum).');
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
      initialDate: _dateOfBirth ?? DateTime(now.year - 10),
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
      final offerings = await ref.read(subjectOfferingsProvider((classId: option.id, departmentId: option.departmentId)).future);
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
      final continueIt = await pnSheet<bool>(
        context,
        (sheetContext) => PnSheetBody(
          title: strings.isFrench ? 'Reprendre où vous en étiez ?' : 'Continue where you left off?',
          children: [
            Text(
              strings.isFrench
                  ? 'Vous aviez commencé à ajouter "$name" lors de votre inscription. Voulez-vous continuer avec ces informations ?'
                  : 'You started adding "$name" when you registered. Would you like to continue with that?',
            ),
          ],
          actions: [
            TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: Text(strings.isFrench ? 'Recommencer' : 'Start Fresh')),
            FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(strings.isFrench ? 'Continuer' : 'Continue')),
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
        throw StateError(strings.isFrench ? 'Profil introuvable. Veuillez vous reconnecter.' : 'Profile not found. Please sign in again.');
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
        // Best-effort - the enrollment already succeeded.
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
        prSnack(
          context,
          strings.isFrench
              ? 'Inscription soumise. L\'école n\'a pas encore défini de frais d\'inscription pour cette classe.'
              : 'Enrollment submitted. The school has not set a registration fee for this class yet.',
        );
        popParentContent(ref);
        return;
      }

      final wantsToPayNow = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (sheetContext) => PnSheetBody(
          title: strings.isFrench ? 'Inscription soumise' : 'Enrollment Submitted',
          children: [
            Center(child: PaStatusBadge(icon: Icons.check_rounded, color: Theme.of(sheetContext).colorScheme.primary)),
            const SizedBox(height: 16),
            Text(
              strings.isFrench
                  ? 'Des frais d\'inscription de ${paMoney(registrationFee)} sont requis pour finaliser cette inscription. '
                      'Votre enfant restera en attente, et l\'école ne verra pas cette demande, tant qu\'ils ne sont pas payés.'
                  : 'A registration fee of ${paMoney(registrationFee)} is required to complete this enrollment. '
                      'Your child will remain pending, and the school will not see this request, until it is paid.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          actions: [
            TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: Text(strings.isFrench ? 'Payer plus tard' : 'Pay Later')),
            FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(strings.isFrench ? 'Payer maintenant' : 'Pay Now')),
          ],
        ),
      );

      if (!mounted) return;

      if (wantsToPayNow == true) {
        popParentContent(ref);
        Navigator.push(
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
        prSnack(
          context,
          strings.isFrench
              ? 'Vous pouvez régler les frais d\'inscription à tout moment depuis votre tableau de bord.'
              : 'You can complete the registration fee anytime from your dashboard.',
        );
        popParentContent(ref);
      }
    } catch (e) {
      if (mounted) prSnack(context, paMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final classesAsync = ref.watch(availableClassesProvider(widget.schoolId));
    final titles = _stepTitles(strings);

    // One-time offer to continue a name/photo captured at sign-up.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(childDraftProvider, (previous, next) {
      final draft = next.valueOrNull;
      if (draft != null) _maybeOfferDraft(draft, strings);
    });

    // Best-effort auto-match of the draft's requested class name.
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

    final pad = PrPage.padding(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: PaStepper(titles: titles, current: _step)),
              IconButton(
                onPressed: _submitting ? null : () => popParentContent(ref),
                icon: const Icon(Icons.close_rounded),
                tooltip: strings.isFrench ? 'Fermer' : 'Close',
              ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation), child: child),
              ),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 20),
                child: _buildStepContent(theme, strings, classesAsync),
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
        ]),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme, AppStrings strings, AsyncValue<List<ClassOption>> classesAsync) {
    final reviewStepIndex = _hasSubjectStep ? 4 : 3;
    if (_step == 0) return _buildChildInfoStep(theme, strings);
    if (_step == 1) return _buildClassStep(theme, strings, classesAsync);
    if (_hasSubjectStep && _step == 2) return _buildSubjectStep(theme, strings);
    if (_step == _guardianStepIndex) return _buildGuardianStep(theme, strings);
    if (_step == reviewStepIndex) return _buildReviewStep(theme, strings);
    return const SizedBox();
  }

  Widget _intro(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline, height: 1.45)),
      );

  Widget _buildChildInfoStep(ThemeData theme, AppStrings strings) {
    final cs = theme.colorScheme;
    final fr = strings.isFrench;
    return Form(
      key: _childInfoKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _intro(
          theme,
          fr
              ? 'Commençons par les informations de base de votre enfant. Tous les champs de cette étape sont obligatoires - l\'école en a besoin pour créer le dossier de votre enfant, sa carte d\'identité et ses futurs bulletins.'
              : 'Let\'s start with your child\'s basic information. Everything on this step is required - the school needs it to create your child\'s record, ID card, and future report cards.',
        ),
        Center(
          child: GestureDetector(
            onTap: () => _pickPhoto(strings),
            child: Stack(children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: cs.surfaceContainerHighest,
                child: _photoBytes == null
                    ? Icon(Icons.add_a_photo_outlined, color: cs.primary, size: 28)
                    : ClipOval(child: Image.memory(_photoBytes!, width: 96, height: 96, fit: BoxFit.cover)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  child: Icon(Icons.edit_rounded, size: 14, color: cs.onPrimary),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            fr ? 'Photo (obligatoire)' : 'Photo (required)',
            style: theme.textTheme.bodySmall?.copyWith(color: _photoBytes == null ? cs.error : cs.outline, fontWeight: _photoBytes == null ? FontWeight.w700 : FontWeight.normal),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          decoration: pnDeco(strings.childFirstName, icon: Icons.badge_outlined),
          validator: (v) => (v == null || v.trim().isEmpty) ? strings.required : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          decoration: pnDeco(strings.childLastName, icon: Icons.badge_outlined),
          validator: (v) => (v == null || v.trim().isEmpty) ? strings.required : null,
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickDateOfBirth,
          child: InputDecorator(
            decoration: pnDeco(fr ? 'Date de naissance (obligatoire)' : 'Date of birth (required)', icon: Icons.cake_outlined),
            child: Text(_dateOfBirth == null ? ' ' : paDate(_dateOfBirth!), style: theme.textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: PaOptionTile(
              icon: Icons.male_rounded,
              title: fr ? 'Masculin' : 'Male',
              selected: _gender == 'male',
              onTap: () => setState(() => _gender = 'male'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PaOptionTile(
              icon: Icons.female_rounded,
              title: fr ? 'Féminin' : 'Female',
              selected: _gender == 'female',
              onTap: () => setState(() => _gender = 'female'),
            ),
          ),
        ]),
        if (_childStepError != null) ...[
          const SizedBox(height: 16),
          PnNotice(text: _childStepError!, icon: Icons.error_outline_rounded, color: cs.error),
        ],
      ]),
    );
  }

  Widget _buildClassStep(ThemeData theme, AppStrings strings, AsyncValue<List<ClassOption>> classesAsync) {
    final fr = strings.isFrench;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _intro(theme, fr ? 'Quelle classe demandez-vous pour votre enfant ? L\'école examinera cette demande.' : 'Which class are you requesting for your child? The school will review this request.'),
      PaAsync<List<ClassOption>>(
        value: classesAsync,
        strings: strings,
        onRetry: () => ref.invalidate(availableClassesProvider(widget.schoolId)),
        rows: 4,
        rowHeight: 64,
        isEmpty: (l) => l.isEmpty,
        empty: PaEmpty(icon: Icons.class_outlined, title: fr ? 'L\'école n\'a pas encore configuré de classes.' : 'The school has not configured any classes yet.'),
        builder: (classes) => Column(children: [
          for (final c in classes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaOptionTile(icon: Icons.school_outlined, title: c.className, selected: _selectedClass?.id == c.id, onTap: () => _onClassSelected(c)),
            ),
          if (_loadingOfferings)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(fr ? 'Chargement des matières pour cette classe…' : 'Loading subjects for this class…', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _buildSubjectStep(ThemeData theme, AppStrings strings) {
    final fr = strings.isFrench;
    final compulsory = _offerings.where((o) => o.isCompulsory).toList();
    final optional = _offerings.where((o) => !o.isCompulsory).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _intro(
        theme,
        fr
            ? 'Cette classe a des matières obligatoires pour tous les élèves, et d\'autres au choix. Faites ce choix avec votre enfant, pour être sûr(e) de sélectionner ce qu\'il/elle souhaite réellement étudier.'
            : 'This class has subjects every student takes, and others your child can choose from. Make this choice together with your child, so you pick what they\'ll actually be studying.',
      ),
      if (compulsory.isNotEmpty) ...[
        PrSectionTitle(title: strings.compulsory),
        const SizedBox(height: 10),
        for (final o in compulsory) _SubjectTile(offering: o, selected: true, onChanged: null),
      ],
      if (optional.isNotEmpty) ...[
        const SizedBox(height: 16),
        PrSectionTitle(title: fr ? 'Matières au choix' : 'Optional Subjects'),
        const SizedBox(height: 10),
        for (final o in optional)
          _SubjectTile(
            offering: o,
            selected: _selectedSubjects.contains(o.subjectId),
            onChanged: (checked) => setState(() {
              if (checked == true) {
                _selectedSubjects.add(o.subjectId);
              } else {
                _selectedSubjects.remove(o.subjectId);
              }
            }),
          ),
      ],
    ]);
  }

  Widget _buildGuardianStep(ThemeData theme, AppStrings strings) {
    final cs = theme.colorScheme;
    final fr = strings.isFrench;
    final profile = ref.watch(parentProfileProvider).valueOrNull;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _intro(
        theme,
        fr
            ? 'Chaque enfant doit avoir un tuteur enregistré - la personne que l\'école contactera. C\'est généralement vous-même.'
            : 'Every child needs a registered guardian - the person the school will contact. That\'s usually you.',
      ),
      Row(children: [
        Expanded(
          child: PaOptionTile(
            icon: Icons.person_rounded,
            title: fr ? 'C\'est moi' : 'This is me',
            selected: _isGuardianSelf == true,
            onTap: () => setState(() {
              _isGuardianSelf = true;
              _guardianStepError = null;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PaOptionTile(
            icon: Icons.family_restroom_outlined,
            title: fr ? 'Une autre personne' : 'Someone else',
            selected: _isGuardianSelf == false,
            onTap: () => setState(() {
              _isGuardianSelf = false;
              _guardianStepError = null;
            }),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (_isGuardianSelf == true) ...[
        PrCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.person_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(profile?.fullName ?? (fr ? 'Vous' : 'You'), style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 14),
      ] else if (_isGuardianSelf == false) ...[
        TextFormField(controller: _guardianName, textCapitalization: TextCapitalization.words, decoration: pnDeco(strings.guardianName, icon: Icons.family_restroom_outlined)),
        const SizedBox(height: 14),
      ],
      if (_isGuardianSelf != null) ...[
        Text(fr ? 'Quel est votre lien avec l\'enfant ?' : 'What is your relationship to the child?', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _relationshipValues)
              ChoiceChip(
                label: Text(_relationshipLabel(value, strings)),
                selected: _guardianRelationship == value,
                onSelected: (_) => setState(() {
                  _guardianRelationship = value;
                  _guardianStepError = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 22),
      ],
      Text(
        fr ? 'Ces informations aident l\'école à vous joindre en cas d\'urgence. Facultatif.' : 'This helps the school reach someone in an emergency. Optional.',
        style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
      ),
      const SizedBox(height: 14),
      TextFormField(controller: _emergencyName, textCapitalization: TextCapitalization.words, decoration: pnDeco(strings.emergencyContactName, icon: Icons.contact_phone_outlined)),
      const SizedBox(height: 14),
      TextFormField(controller: _emergencyPhone, keyboardType: TextInputType.phone, decoration: pnDeco(strings.emergencyContactPhone, icon: Icons.phone_outlined)),
      const SizedBox(height: 14),
      TextFormField(controller: _address, maxLines: 2, decoration: pnDeco(strings.address, icon: Icons.location_on_outlined)),
      if (_guardianStepError != null) ...[
        const SizedBox(height: 16),
        PnNotice(text: _guardianStepError!, icon: Icons.error_outline_rounded, color: cs.error),
      ],
    ]);
  }

  Widget _buildReviewStep(ThemeData theme, AppStrings strings) {
    final fr = strings.isFrench;
    final selectedNames = _offerings.where((o) => _selectedSubjects.contains(o.subjectId)).map((o) => o.subjectName).toList();
    final profile = ref.watch(parentProfileProvider).valueOrNull;
    final guardianDisplayName = _isGuardianSelf == true ? (profile?.fullName ?? '-') : _guardianName.text;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _intro(theme, fr ? 'Vérifiez les informations ci-dessous avant de soumettre.' : 'Review the details below before submitting.'),
      if (_photoBytes != null) Center(child: CircleAvatar(radius: 38, backgroundImage: MemoryImage(_photoBytes!))),
      const SizedBox(height: 16),
      _ReviewCard(title: fr ? 'Enfant' : 'Child', rows: [
        MapEntry(fr ? 'Nom' : 'Name', '${_firstName.text} ${_lastName.text}'),
        if (_dateOfBirth != null) MapEntry(fr ? 'Naissance' : 'Born', paDate(_dateOfBirth!)),
      ]),
      const SizedBox(height: 12),
      _ReviewCard(title: strings.requestedClass, rows: [MapEntry(fr ? 'Classe' : 'Class', _selectedClass?.className ?? '-')]),
      if (_hasSubjectStep) ...[
        const SizedBox(height: 12),
        _ReviewCard(title: strings.chooseSubjects, rows: [MapEntry(strings.subject, selectedNames.isEmpty ? '-' : selectedNames.join(', '))]),
      ],
      const SizedBox(height: 12),
      _ReviewCard(title: strings.guardianInformation, rows: [
        MapEntry(strings.guardianName, guardianDisplayName),
        if (_guardianRelationship != null) MapEntry(fr ? 'Lien' : 'Relationship', _relationshipLabel(_guardianRelationship!, strings)),
        if (_emergencyPhone.text.isNotEmpty) MapEntry(strings.emergencyContactPhone, _emergencyPhone.text),
      ]),
      const SizedBox(height: 16),
      PnNotice(
        text: fr
            ? 'Après soumission, vous pourrez payer les frais d\'inscription immédiatement ou plus tard depuis votre tableau de bord.'
            : 'After submitting, you\'ll be able to pay the registration fee right away or later from your dashboard.',
      ),
    ]);
  }
}

/// Keeps a fire-and-forget Future's errors caught (via .catchError at the
/// call site) without making _submit's flow non-linear.
void unawaited(Future<void> future) {}

class _SubjectTile extends StatelessWidget {
  final SubjectOfferingOption offering;
  final bool selected;
  final ValueChanged<bool?>? onChanged;
  const _SubjectTile({required this.offering, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? cs.primary.withValues(alpha: 0.06) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: CheckboxListTile(
        value: selected,
        title: Text(offering.subjectName, style: const TextStyle(fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onChanged: onChanged,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> rows;
  const _ReviewCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        for (final r in rows) PaKeyValue(label: r.key, value: r.value),
      ]),
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
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fr = strings.isFrench;
    final pad = PrPage.padding(context);
    final isLast = step == totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)))),
      child: Row(children: [
        if (onBack != null) ...[
          OutlinedButton.icon(onPressed: submitting ? null : onBack, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(fr ? 'Retour' : 'Back')),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton(
            onPressed: submitting ? null : (isLast ? onSubmit : (canGoNext ? onNext : null)),
            child: submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isLast ? strings.submitEnrollment : (fr ? 'Suivant' : 'Next')),
          ),
        ),
      ]),
    );
  }
}

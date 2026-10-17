import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import '../principal/principal_core.dart';
import '../principal/principal_kit.dart';
import '../proprietor/proprietor_ui.dart';
import 'secretary_flow_strings.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_payments.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

enum _Step { parent, child, classStep, guardian, review }

/// Bottom sheet that ignores swipes and outside taps (for flows where
/// closing by accident would lose something, such as the one-time
/// password of a new parent account).
Future<T?> _lockedSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: builder,
  );
}

/// Enrollment wizard. With [editing] set it becomes the edit-enrollment
/// flow for a child whose registration fee has not been paid yet (the
/// parent step is skipped - the parent cannot change).
class EnrollChildPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  final AwaitingRegistration? editing;
  final void Function(bool saved)? onFinished;

  const EnrollChildPage({
    super.key,
    required this.schoolId,
    required this.landing,
    required this.strings,
    this.editing,
    this.onFinished,
  });

  @override
  ConsumerState<EnrollChildPage> createState() => _EnrollChildPageState();
}

class _EnrollChildPageState extends ConsumerState<EnrollChildPage> {
  int _index = 0;
  bool _submitting = false;
  final _scroll = ScrollController();

  // parent
  ParentMatch? _parent;
  final _searchController = TextEditingController();
  List<ParentMatch> _results = [];
  bool _searching = false;
  bool _searchedOnce = false;
  Timer? _debounce;
  int _searchToken = 0;

  // child
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  String? _gender;
  DateTime? _dob;
  Uint8List? _photoBytes;
  String? _photoName;
  String? _existingPhotoUrl;

  // class + subjects
  String? _departmentId;
  EnrollClass? _class;
  List<EnrollSubject> _offerings = [];
  final Set<String> _subjects = {};
  bool _loadingOfferings = false;
  int _offeringsToken = 0;

  // guardian
  final _guardian = TextEditingController();
  final _emName = TextEditingController();
  final _emPhone = TextEditingController();
  final _address = TextEditingController();

  AppStrings get _s => widget.strings;
  bool get _isEdit => widget.editing != null;

  List<_Step> get _steps => _isEdit
      ? const [_Step.child, _Step.classStep, _Step.guardian, _Step.review]
      : const [_Step.parent, _Step.child, _Step.classStep, _Step.guardian, _Step.review];

  _Step get _current => _steps[_index];

  String _stepTitle(_Step s) {
    switch (s) {
      case _Step.parent:
        return _s.sStepParent;
      case _Step.child:
        return _s.sStepChild;
      case _Step.classStep:
        return _s.sStepClass;
      case _Step.guardian:
        return _s.sStepGuardian;
      case _Step.review:
        return _s.sStepReview;
    }
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _first.text = e.firstName;
      _last.text = e.lastName;
      _gender = e.gender;
      _dob = e.dateOfBirth;
      _existingPhotoUrl = e.photoUrl;
      _guardian.text = e.guardianName ?? '';
      _emName.text = e.emergencyContactName ?? '';
      _emPhone.text = e.emergencyContactPhone ?? '';
      _address.text = e.address ?? '';
      _departmentId = e.departmentId;
      _subjects.addAll(e.subjectIds);
      _hydrateClass(e);
    }
  }

  Future<void> _hydrateClass(AwaitingRegistration e) async {
    try {
      final classes = await ref.read(enrollClassesProvider(widget.schoolId).future);
      EnrollClass? match;
      for (final c in classes) {
        if (c.id == e.classId) {
          match = c;
          break;
        }
      }
      if (match == null || !mounted) return;
      setState(() {
        _class = match;
        _departmentId = match!.departmentId;
      });
      await _loadOfferings(match, keepSelection: true);
    } catch (err) {
      _snack(sxMessage(err));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    for (final c in [_searchController, _first, _last, _guardian, _emName, _emPhone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    if (mounted) prSnack(context, message);
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _index = 0;
      _parent = null;
      _results = [];
      _searchedOnce = false;
      _searchController.clear();
      _first.clear();
      _last.clear();
      _gender = null;
      _dob = null;
      _photoBytes = null;
      _photoName = null;
      _existingPhotoUrl = null;
      _departmentId = null;
      _class = null;
      _offerings = [];
      _subjects.clear();
      _guardian.clear();
      _emName.clear();
      _emPhone.clear();
      _address.clear();
    });
    _toTop();
  }

  // ---------------- parent search / create ----------------

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _searchToken++;
      setState(() {
        _results = [];
        _searchedOnce = false;
        _searching = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final token = ++_searchToken;
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final found = await ref.read(secretaryRepositoryProvider).findParents(value.trim());
        if (!mounted || token != _searchToken) return;
        setState(() {
          _results = found;
          _searchedOnce = true;
        });
      } catch (e) {
        if (token == _searchToken) _snack(sxMessage(e));
      } finally {
        if (mounted && token == _searchToken) setState(() => _searching = false);
      }
    });
  }

  Future<void> _createParent() async {
    final creds = await pnSheet<NewParentCredentials>(context, (_) => _NewParentSheet(strings: _s));
    if (creds == null || !mounted) return;
    setState(() => _parent = ParentMatch(parentId: creds.parentId, fullName: creds.fullName, phone: creds.phone, email: creds.email));
    await _lockedSheet<void>(context, (_) => _CredentialsSheet(credentials: creds, schoolId: widget.schoolId, landing: widget.landing, strings: _s));
  }

  // ---------------- child ----------------

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoName = picked.name;
      });
    } catch (_) {
      _snack(_s.fPhotoPickError);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _onClassSelected(EnrollClass c) async {
    setState(() => _class = c);
    await _loadOfferings(c);
  }

  Future<void> _loadOfferings(EnrollClass c, {bool keepSelection = false}) async {
    final token = ++_offeringsToken;
    setState(() {
      _loadingOfferings = true;
      _offerings = [];
      if (!keepSelection) _subjects.clear();
    });
    try {
      final offerings = await ref.read(secretaryRepositoryProvider).getSubjectOfferings(c.id, c.departmentId);
      if (!mounted || token != _offeringsToken) return;
      setState(() {
        _offerings = offerings;
        for (final o in offerings.where((o) => o.isCompulsory)) {
          _subjects.add(o.subjectId);
        }
      });
    } catch (err) {
      if (token == _offeringsToken) _snack(sxMessage(err));
    } finally {
      if (mounted && token == _offeringsToken) setState(() => _loadingOfferings = false);
    }
  }

  // ---------------- navigation ----------------

  void _go(int to) {
    setState(() => _index = to);
    _toTop();
  }

  void _next() {
    final step = _current;
    if (step == _Step.parent && _parent == null) return _snack(_s.fSelectParentFirst);
    if (step == _Step.child) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_gender == null) return _snack(_s.fSelectGender);
    }
    if (step == _Step.classStep && _class == null) return _snack(_s.fSelectClass);
    _go(_index + 1);
  }

  String _photoExtension() {
    final name = _photoName ?? '';
    final raw = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final cleaned = raw.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.isEmpty ? 'jpg' : cleaned;
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(secretaryRepositoryProvider);

      String? photoUrl = _existingPhotoUrl;
      if (_photoBytes != null) {
        photoUrl = await repo.uploadChildPhoto(schoolId: widget.schoolId, bytes: _photoBytes!, extension: _photoExtension());
      }

      final subjectIds = _offerings.where((o) => _subjects.contains(o.subjectId)).map((o) => o.subjectId).toList();
      final childName = '${_first.text.trim()} ${_last.text.trim()}'.trim();

      if (_isEdit) {
        await repo.updateEnrollment(
          admissionRequestId: widget.editing!.id,
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          gender: _gender,
          dateOfBirth: _dob,
          classId: _class!.id,
          guardianName: _guardian.text.trim(),
          emergencyName: _emName.text.trim(),
          emergencyPhone: _emPhone.text.trim(),
          address: _address.text.trim(),
          photoUrl: photoUrl,
          subjectIds: subjectIds,
        );
        ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
        ref.invalidate(secretaryDashboardProvider(widget.schoolId));
        _snack(_s.sEnrollmentUpdatedMessage);
        widget.onFinished?.call(true);
        return;
      }

      final result = await repo.enrollChild(
        parentId: _parent!.parentId,
        classId: _class!.id,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        gender: _gender!,
        dateOfBirth: _dob,
        guardianName: _nullIfEmpty(_guardian.text),
        emergencyName: _nullIfEmpty(_emName.text),
        emergencyPhone: _nullIfEmpty(_emPhone.text),
        address: _nullIfEmpty(_address.text),
        photoUrl: photoUrl,
        subjectIds: subjectIds,
      );

      ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
      ref.invalidate(secretaryDashboardProvider(widget.schoolId));
      if (!mounted) return;

      final fee = result.registrationFee;
      if (fee == null || fee <= 0) {
        _snack(_s.fEnrollmentCreatedNoFee(childName));
        _reset();
        return;
      }

      final paid = await showCollectPayment(
        context,
        landing: widget.landing,
        strings: _s,
        kind: 'registration',
        purpose: _s.fRegistrationFeePurpose,
        childName: childName,
        amount: fee,
        admissionRequestId: result.admissionRequestId,
      );
      if (!mounted) return;
      _snack(paid == true ? _s.fRegistrationFeeRecorded(childName) : _s.sCollectLaterMessage);
      ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
      ref.invalidate(secretaryDashboardProvider(widget.schoolId));
      _reset();
    } catch (e) {
      _snack(sxMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final classesAsync = ref.watch(enrollClassesProvider(widget.schoolId));
    final steps = _steps;
    final pad = PrPage.padding(context);

    return Column(children: [
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!_isEdit) PrHeader(title: _s.sEnrollChild, subtitle: _s.sEnrollChildDescription),
                  PrReveal(child: SxStepper(titles: [for (final s in steps) _stepTitle(s)], current: _index)),
                  const SizedBox(height: 20),
                  if (_isEdit) ...[PnNotice(text: _s.fEditNote), const SizedBox(height: 14)],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(a), child: child)),
                    child: KeyedSubtree(key: ValueKey(_current), child: _stepContent(theme, classesAsync)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
        decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(children: [
              if (_index > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _submitting ? null : () => _go(_index - 1),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(_s.sBack),
                ),
              const Spacer(),
              if (_current != _Step.review)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(_s.sNext),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary)) : const Icon(Icons.check_rounded),
                  label: Text(_submitting ? _s.sSavingLabel : (_isEdit ? _s.fSaveChanges : _s.sCreateEnrollmentButton)),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _stepContent(ThemeData theme, AsyncValue<List<EnrollClass>> classesAsync) {
    switch (_current) {
      case _Step.parent:
        return _parentStep(theme);
      case _Step.child:
        return _childStep(theme);
      case _Step.classStep:
        return classesAsync.when(
          skipLoadingOnReload: true,
          loading: () => const SxSkeletonList(rows: 3, height: 64),
          error: (e, _) => SxError(error: e, strings: _s, onRetry: () => ref.invalidate(enrollClassesProvider(widget.schoolId))),
          data: (classes) => _classStep(theme, classes),
        );
      case _Step.guardian:
        return _guardianStep(theme);
      case _Step.review:
        return _reviewStep(theme);
    }
  }

  // ---------------- step: parent ----------------

  Widget _childrenChips(ThemeData theme, List<ParentChild> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_s.sExistingChildren, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in children)
            PnChip(label: c.className == null || c.className!.isEmpty ? c.fullName : '${c.fullName} · ${c.className}', icon: Icons.child_care_rounded),
        ]),
      ]),
    );
  }

  Widget _parentStep(ThemeData theme) {
    final cs = theme.colorScheme;
    if (_parent != null) {
      final p = _parent!;
      return PrCard(
        color: cs.primary.withValues(alpha: 0.06),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PrAvatar(name: p.fullName, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, color: pnGood(), size: 18),
              ]),
              Text('${p.email ?? _s.fNoEmail} · ${p.phone ?? _s.fNoPhone}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
              _childrenChips(theme, p.children),
              const SizedBox(height: 6),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => setState(() => _parent = null),
                child: Text(_s.sChangeParent),
              ),
            ]),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_s.fParentStepHelp, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4)),
      const SizedBox(height: 12),
      PnSearch(controller: _searchController, hint: _s.sSearchParentHint, onChanged: _onSearchChanged),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _searching ? 12 : 0,
        padding: const EdgeInsets.only(top: 8),
        child: _searching ? const LinearProgressIndicator(minHeight: 3) : null,
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < _results.length; i++)
        SxRow(
          index: i,
          leading: PrAvatar(name: _results[i].fullName, radius: 22),
          title: _results[i].fullName,
          lines: ['${_results[i].email ?? _s.fNoEmail} · ${_results[i].phone ?? _s.fNoPhone}'],
          bottom: _results[i].children.isEmpty ? null : _childrenChips(theme, _results[i].children),
          trailing: Icon(Icons.chevron_right_rounded, color: cs.outline),
          onTap: () => setState(() => _parent = _results[i]),
        ),
      if (_searchedOnce && _results.isEmpty && !_searching)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: PnNotice(text: _s.sNoParentFound, icon: Icons.search_off_rounded)),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: _createParent,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_s.sCreateNewParentAccount),
      ),
    ]);
  }

  // ---------------- step: child ----------------

  Widget _photoPreview(ThemeData theme, {double radius = 48}) {
    final cs = theme.colorScheme;
    if (_photoBytes != null) {
      return CircleAvatar(radius: radius, backgroundColor: cs.surfaceContainerHighest, backgroundImage: MemoryImage(_photoBytes!));
    }
    if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return PnAvatar(stored: _existingPhotoUrl, name: '${_first.text} ${_last.text}', radius: radius);
    }
    return CircleAvatar(radius: radius, backgroundColor: cs.primary.withValues(alpha: 0.10), child: Icon(Icons.add_a_photo_rounded, color: cs.primary, size: radius * 0.6));
  }

  Widget _childStep(ThemeData theme) {
    final cs = theme.colorScheme;
    final hasPhoto = _photoBytes != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);
    return Form(
      key: _formKey,
      child: PnPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _pickPhoto,
              child: Stack(children: [
                _photoPreview(theme),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle, border: Border.all(color: cs.surface, width: 2.5)),
                    child: Icon(Icons.camera_alt_rounded, size: 15, color: cs.onPrimary),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(hasPhoto ? _s.fKeepCurrentPhoto : _s.sChildPhotoHint, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final firstField = TextFormField(
              controller: _first,
              textCapitalization: TextCapitalization.words,
              decoration: pnDeco(_s.fFirstName),
              validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
            );
            final lastField = TextFormField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: pnDeco(_s.fLastName),
              validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
            );
            if (c.maxWidth < 460) return Column(children: [firstField, const SizedBox(height: 12), lastField]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: firstField), const SizedBox(width: 12), Expanded(child: lastField)]);
          }),
          const SizedBox(height: 14),
          Text(_s.sGenderLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: SxOptionTile(icon: Icons.boy_rounded, title: _s.sMale, selected: _gender == 'male', onTap: () => setState(() => _gender = 'male'))),
            const SizedBox(width: 10),
            Expanded(child: SxOptionTile(icon: Icons.girl_rounded, title: _s.sFemale, selected: _gender == 'female', onTap: () => setState(() => _gender = 'female'))),
          ]),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDob,
            child: InputDecorator(
              decoration: pnDeco(_s.sDateOfBirthOptional, icon: Icons.cake_outlined),
              child: Text(_dob == null ? ' ' : formatDate(_dob!), style: theme.textTheme.bodyLarge),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------- step: class + subjects ----------------

  Widget _classStep(ThemeData theme, List<EnrollClass> classes) {
    final cs = theme.colorScheme;
    final departments = <String, String>{for (final c in classes) c.departmentId: c.departmentName};
    final filtered = classes.where((c) => c.departmentId == _departmentId).toList();
    final deptValue = departments.containsKey(_departmentId) ? _departmentId : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PnPanel(
        title: _s.sStepClass,
        subtitle: _s.fClassStepHelp,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            key: ValueKey('dept-$deptValue'),
            initialValue: deptValue,
            isExpanded: true,
            decoration: pnDeco(_s.sDepartmentLabel, icon: Icons.account_tree_outlined),
            items: departments.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.isEmpty ? _s.sDepartmentLabel : e.value, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              _offeringsToken++;
              setState(() {
                _departmentId = v;
                _class = null;
                _offerings = [];
                _subjects.clear();
                _loadingOfferings = false;
              });
            },
          ),
          const SizedBox(height: 14),
          if (deptValue == null)
            PnNotice(text: _s.sSelectDepartmentFirst)
          else if (filtered.isEmpty)
            PnNotice(text: _s.sNoClassesInDepartment, icon: Icons.info_outline_rounded, color: pnWarn())
          else
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 560 ? 2 : 1;
              const gap = 10.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final cl in filtered)
                  SizedBox(width: w, child: SxOptionTile(icon: Icons.class_rounded, title: cl.className, selected: _class?.id == cl.id, onTap: () => _onClassSelected(cl))),
              ]);
            }),
        ]),
      ),
      if (_class != null) ...[
        const SizedBox(height: 16),
        PnPanel(
          title: _s.fSubjectsTitle,
          subtitle: _offerings.isEmpty ? null : _s.fCompulsoryLocked,
          child: _loadingOfferings
              ? const SxSkeletonList(rows: 3, height: 58)
              : _offerings.isEmpty
                  ? Text(_s.fNoSubjectsConfigured, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))
                  : Column(children: [
                      for (final o in _offerings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SxOptionTile(
                            icon: o.isCompulsory ? Icons.lock_outline_rounded : (_subjects.contains(o.subjectId) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
                            title: o.name,
                            subtitle: o.isCompulsory ? _s.fCompulsory : _s.fOptional,
                            selected: _subjects.contains(o.subjectId),
                            onTap: o.isCompulsory
                                ? null
                                : () => setState(() {
                                      if (_subjects.contains(o.subjectId)) {
                                        _subjects.remove(o.subjectId);
                                      } else {
                                        _subjects.add(o.subjectId);
                                      }
                                    }),
                          ),
                        ),
                    ]),
        ),
      ],
    ]);
  }

  // ---------------- step: guardian ----------------

  Widget _guardianStep(ThemeData theme) {
    return PnPanel(
      title: _s.sStepGuardian,
      subtitle: _s.sGuardianDetailsHint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _guardian, textCapitalization: TextCapitalization.words, decoration: pnDeco(_s.fGuardianName, icon: Icons.person_outline_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _emName, textCapitalization: TextCapitalization.words, decoration: pnDeco(_s.fEmergencyName, icon: Icons.emergency_outlined)),
        const SizedBox(height: 14),
        TextField(controller: _emPhone, keyboardType: TextInputType.phone, decoration: pnDeco(_s.fEmergencyPhone, icon: Icons.phone_outlined)),
        const SizedBox(height: 14),
        TextField(controller: _address, maxLines: 2, decoration: pnDeco(_s.fAddress, icon: Icons.home_outlined)),
      ]),
    );
  }

  // ---------------- step: review ----------------

  Widget _reviewStep(ThemeData theme) {
    final cs = theme.colorScheme;
    final subjectNames = _offerings.where((o) => _subjects.contains(o.subjectId)).map((o) => o.name).toList();
    final parentName = _isEdit ? widget.editing!.parentName : (_parent?.fullName ?? '');
    final parentEmail = _isEdit ? '' : (_parent?.email ?? '');
    final childName = '${_first.text.trim()} ${_last.text.trim()}'.trim();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrCard(
        child: Column(children: [
          _photoPreview(theme, radius: 42),
          const SizedBox(height: 10),
          Text(childName, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_class == null ? '-' : (_class!.departmentName.isEmpty ? _class!.className : '${_class!.className} · ${_class!.departmentName}'),
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          SxKeyValue(label: _s.sReviewParentLabel, value: parentEmail.isEmpty ? parentName : '$parentName\n$parentEmail'),
          SxKeyValue(label: _s.sReviewGenderLabel, value: genderLabel(_s, _gender)),
          if (_dob != null) SxKeyValue(label: _s.sReviewBornLabel, value: formatDate(_dob!)),
          if (subjectNames.isNotEmpty) SxKeyValue(label: _s.sReviewSubjectsLabel, value: subjectNames.join(', ')),
          if (_guardian.text.trim().isNotEmpty) SxKeyValue(label: _s.sReviewGuardianLabel, value: _guardian.text.trim()),
          if (_emPhone.text.trim().isNotEmpty) SxKeyValue(label: _s.sReviewEmergencyPhoneLabel, value: _emPhone.text.trim()),
        ]),
      ),
      if (!_isEdit) ...[const SizedBox(height: 14), PnNotice(text: _s.sNextStepNote)],
    ]);
  }
}

// ============================================================ new parent

class _NewParentSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  const _NewParentSheet({required this.strings});

  @override
  ConsumerState<_NewParentSheet> createState() => _NewParentSheetState();
}

class _NewParentSheetState extends ConsumerState<_NewParentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final creds = await ref.read(secretaryRepositoryProvider).createParent(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.pop(context, creds);
    } catch (e) {
      if (mounted) setState(() => _error = sxMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PnSheetBody(
      title: _s.sNewParentAccountTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: pnDeco(_s.fullName, icon: Icons.person_outline_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: pnDeco(_s.fEmailLoginLabel, icon: Icons.mail_outline_rounded),
              validator: (v) => (v == null || !v.contains('@')) ? _s.fInvalidEmail : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: pnDeco(_s.fPhoneLabel, icon: Icons.phone_outlined),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              PnNotice(text: _error!, icon: Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
            ],
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(_s.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: PnBusyLabel(busy: _saving, label: _s.fCreateAccount)),
      ],
    );
  }
}

// ============================================================ credentials

class _CredentialsSheet extends ConsumerStatefulWidget {
  final NewParentCredentials credentials;
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const _CredentialsSheet({required this.credentials, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<_CredentialsSheet> createState() => _CredentialsSheetState();
}

class _CredentialsSheetState extends ConsumerState<_CredentialsSheet> {
  bool _printing = false;

  AppStrings get _s => widget.strings;
  NewParentCredentials get _c => widget.credentials;
  String get _signInUrl => Uri.base.origin;

  String get _plainText => _s.fCredentialsPlainText(widget.landing.schoolName, _signInUrl, _c.email, _c.temporaryPassword);

  Future<void> _printSlip() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
      final branding = await OfficialBranding.fetch(assets);

      pw.Widget line(String label, String value) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Row(children: [
              pw.SizedBox(width: 110, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
            ]),
          );

      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            buildDocumentHeader(branding: branding, schoolName: widget.landing.schoolName, motto: widget.landing.motto),
            pw.SizedBox(height: 18),
            pw.Center(child: pw.Text(_s.fSlipTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 14),
            line(_s.fullName, _c.fullName),
            line(_s.sSignInAtLabel, _signInUrl),
            line(_s.email, _c.email),
            line(_s.sTemporaryPasswordLabel, _c.temporaryPassword),
            pw.SizedBox(height: 16),
            pw.Text(_s.fSlipNote, style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
      ));
      await Printing.sharePdf(bytes: await doc.save(), filename: 'parent_account_${_c.fullName.replaceAll(' ', '_')}.pdf');
    } catch (_) {
      if (mounted) prSnack(context, _s.fSlipError);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Center(child: SxSuccessBadge(size: 64)),
        const SizedBox(height: 12),
        Text(_s.fParentAccountCreatedTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        PnNotice(text: _s.sAccountCreatedWarning, icon: Icons.warning_amber_rounded, color: pnWarn()),
        const SizedBox(height: 14),
        PrCard(
          color: cs.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s.sSignInAtLabel, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            SelectableText(_signInUrl, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(_s.email, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            SelectableText(_c.email, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(_s.sTemporaryPasswordLabel, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: SelectableText(_c.temporaryPassword, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => prCopy(context, _plainText, _s.fCopiedMessage),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(_s.sCopy),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _printing ? null : _printSlip,
              icon: _printing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print_outlined, size: 16),
              label: Text(_s.sPrintSlip),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.pop(context),
          child: Text(_s.fDone),
        ),
      ]),
    );
  }
}

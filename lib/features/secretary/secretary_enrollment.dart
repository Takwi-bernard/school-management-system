import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import 'secretary_flow_strings.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_payments.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

String _clean(Object e) => '$e'.replaceFirst('Exception: ', '');

enum _Step { parent, child, classStep, guardian, review }

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
      _snack(_clean(err));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_searchController, _first, _last, _guardian, _emName, _emPhone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        if (token == _searchToken) _snack(_clean(e));
      } finally {
        if (mounted && token == _searchToken) setState(() => _searching = false);
      }
    });
  }

  Future<void> _createParent() async {
    final creds = await showDialog<NewParentCredentials>(
      context: context,
      builder: (_) => _NewParentDialog(strings: _s),
    );
    if (creds == null || !mounted) return;
    setState(() => _parent = ParentMatch(parentId: creds.parentId, fullName: creds.fullName, phone: creds.phone, email: creds.email));
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CredentialsDialog(credentials: creds, schoolId: widget.schoolId, landing: widget.landing, strings: _s),
    );
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
      if (token == _offeringsToken) _snack(_clean(err));
    } finally {
      if (mounted && token == _offeringsToken) setState(() => _loadingOfferings = false);
    }
  }

  // ---------------- navigation ----------------

  void _next() {
    final step = _current;
    if (step == _Step.parent && _parent == null) return _snack(_s.fSelectParentFirst);
    if (step == _Step.child) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_gender == null) return _snack(_s.fSelectGender);
    }
    if (step == _Step.classStep && _class == null) return _snack(_s.fSelectClass);
    setState(() => _index++);
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

      final paid = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CollectPaymentDialog(
          landing: widget.landing,
          strings: _s,
          kind: 'registration',
          purpose: _s.fRegistrationFeePurpose,
          childName: childName,
          amount: fee,
          admissionRequestId: result.admissionRequestId,
        ),
      );
      if (!mounted) return;
      _snack(paid == true ? _s.fRegistrationFeeRecorded(childName) : _s.sCollectLaterMessage);
      ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
      ref.invalidate(secretaryDashboardProvider(widget.schoolId));
      _reset();
    } catch (e) {
      _snack(_clean(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classesAsync = ref.watch(enrollClassesProvider(widget.schoolId));
    final steps = _steps;

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_isEdit) SecretaryPageHeader(title: _s.sEnrollChild, subtitle: _s.sEnrollChildDescription),
        Text(
          _s.fStepOf(_index + 1, steps.length, _stepTitle(_current)),
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) => _stepBar(theme, c.maxWidth)),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_isEdit) ...[
                    SecretaryCard(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_s.fEditNote, style: theme.textTheme.bodySmall)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _stepContent(theme, classesAsync),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          if (_index > 0)
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => setState(() => _index--),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(_s.sBack),
            ),
          const Spacer(),
          if (_current != _Step.review)
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(_s.sNext),
            ),
          if (_current == _Step.review)
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_submitting ? _s.sSavingLabel : (_isEdit ? _s.fSaveChanges : _s.sCreateEnrollmentButton)),
            ),
        ]),
      ]),
    );
  }

  Widget _stepBar(ThemeData theme, double width) {
    final steps = _steps;
    final showLabels = width >= 560;
    final active = theme.colorScheme.primary;
    final idle = theme.colorScheme.outlineVariant;

    Widget dot(int i) {
      final done = i < _index;
      final current = i == _index;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (done || current) ? active : Colors.transparent,
            border: Border.all(color: (done || current) ? active : idle, width: 2),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 14, color: theme.colorScheme.onPrimary)
              : Text('${i + 1}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: current ? theme.colorScheme.onPrimary : theme.colorScheme.outline)),
        ),
        if (showLabels) ...[
          const SizedBox(height: 4),
          Text(
            _stepTitle(steps[i]),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: current ? FontWeight.w800 : FontWeight.w500,
              color: current ? active : theme.colorScheme.outline,
            ),
          ),
        ],
      ]);
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 11, left: 4, right: 4),
              child: Container(height: 2, color: i <= _index ? active : idle),
            ),
          ),
        dot(i),
      ],
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
          loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(
            height: 220,
            child: SecretaryErrorView(error: e, strings: _s, onRetry: () => ref.invalidate(enrollClassesProvider(widget.schoolId))),
          ),
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
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final c in children)
            Chip(
              label: Text(c.className == null || c.className!.isEmpty ? c.fullName : '${c.fullName} · ${c.className}', style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.child_care_rounded, size: 14),
            ),
        ]),
      ]),
    );
  }

  Widget _parentStep(ThemeData theme) {
    if (_parent != null) {
      final p = _parent!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${p.email ?? _s.fNoEmail} · ${p.phone ?? _s.fNoPhone}', style: theme.textTheme.bodySmall),
              _childrenChips(theme, p.children),
            ]),
          ),
          TextButton(onPressed: () => setState(() => _parent = null), child: Text(_s.sChangeParent)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_s.fParentStepHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          labelText: _s.sSearchParentLabel,
          hintText: _s.sSearchParentHint,
          border: const OutlineInputBorder(),
        ),
      ),
      if (_searching) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      const SizedBox(height: 8),
      ..._results.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SecretaryCard(
              onTap: () => setState(() => _parent = p),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${p.email ?? _s.fNoEmail} · ${p.phone ?? _s.fNoPhone}', style: theme.textTheme.bodySmall),
                    _childrenChips(theme, p.children),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          )),
      if (_searchedOnce && _results.isEmpty && !_searching)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_s.sNoParentFound, style: theme.textTheme.bodySmall),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _createParent, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(_s.sCreateNewParentAccount)),
    ]);
  }

  // ---------------- step: child ----------------

  Widget _photoPreview(ThemeData theme) {
    Widget inner;
    if (_photoBytes != null) {
      inner = ClipOval(child: Image.memory(_photoBytes!, width: 92, height: 92, fit: BoxFit.cover));
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(
          _existingPhotoUrl!,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 28),
        ),
      );
    } else {
      inner = Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 28);
    }
    return CircleAvatar(radius: 46, backgroundColor: theme.colorScheme.surfaceContainerHighest, child: inner);
  }

  Widget _childStep(ThemeData theme) {
    final hasPhoto = _photoBytes != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: GestureDetector(onTap: _pickPhoto, child: _photoPreview(theme))),
        const SizedBox(height: 6),
        Center(
          child: Text(
            hasPhoto ? _s.fKeepCurrentPhoto : _s.sChildPhotoHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _first,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _s.fFirstName, border: const OutlineInputBorder()),
          validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _last,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _s.fLastName, border: const OutlineInputBorder()),
          validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _genderCard(_s.sMale, 'male', theme)),
          const SizedBox(width: 10),
          Expanded(child: _genderCard(_s.sFemale, 'female', theme)),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDob,
          icon: const Icon(Icons.cake_outlined),
          label: Text(_dob == null ? _s.sDateOfBirthOptional : formatDate(_dob!)),
        ),
      ]),
    );
  }

  Widget _genderCard(String label, String value, ThemeData theme) {
    final selected = _gender == value;
    return Material(
      color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? theme.colorScheme.primary : null)),
        ),
      ),
    );
  }

  // ---------------- step: class + subjects ----------------

  Widget _classStep(ThemeData theme, List<EnrollClass> classes) {
    final departments = <String, String>{for (final c in classes) c.departmentId: c.departmentName};
    final filtered = classes.where((c) => c.departmentId == _departmentId).toList();
    final deptValue = departments.containsKey(_departmentId) ? _departmentId : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_s.fClassStepHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('dept-$deptValue'),
        initialValue: deptValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: _s.sDepartmentLabel, border: const OutlineInputBorder()),
        items: departments.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.isEmpty ? _s.sDepartmentLabel : e.value, overflow: TextOverflow.ellipsis)))
            .toList(),
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
      const SizedBox(height: 12),
      if (deptValue == null)
        Text(_s.sSelectDepartmentFirst, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))
      else if (filtered.isEmpty)
        Text(_s.sNoClassesInDepartment, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ...filtered.map((c) {
        final selected = _class?.id == c.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _onClassSelected(c),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
                ),
                child: Row(children: [
                  Expanded(child: Text(c.className, style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (selected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                ]),
              ),
            ),
          ),
        );
      }),
      if (_class != null) ...[
        const SizedBox(height: 16),
        Text(_s.fSubjectsTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (_loadingOfferings)
          const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator())
        else if (_offerings.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_s.fNoSubjectsConfigured, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          )
        else ...[
          Text(_s.fCompulsoryLocked, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ..._offerings.map((o) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _subjects.contains(o.subjectId),
                title: Text(o.name),
                subtitle: Text(o.isCompulsory ? _s.fCompulsory : _s.fOptional),
                onChanged: o.isCompulsory
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _subjects.add(o.subjectId);
                          } else {
                            _subjects.remove(o.subjectId);
                          }
                        }),
              )),
        ],
      ],
    ]);
  }

  // ---------------- step: guardian ----------------

  Widget _guardianStep(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_s.sGuardianDetailsHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      TextField(
        controller: _guardian,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: _s.fGuardianName, border: const OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _emName,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: _s.fEmergencyName, border: const OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _emPhone,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(labelText: _s.fEmergencyPhone, border: const OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _address,
        maxLines: 2,
        decoration: InputDecoration(labelText: _s.fAddress, border: const OutlineInputBorder()),
      ),
    ]);
  }

  // ---------------- step: review ----------------

  Widget _reviewStep(ThemeData theme) {
    final subjectNames = _offerings.where((o) => _subjects.contains(o.subjectId)).map((o) => o.name).toList();
    final parentName = _isEdit ? widget.editing!.parentName : (_parent?.fullName ?? '');
    final parentEmail = _isEdit ? '' : (_parent?.email ?? '');

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(color: theme.colorScheme.outline))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );

    return SecretaryCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: _photoPreview(theme)),
        const SizedBox(height: 12),
        row(_s.sReviewParentLabel, parentEmail.isEmpty ? parentName : '$parentName\n$parentEmail'),
        row(_s.sReviewChildLabel, '${_first.text.trim()} ${_last.text.trim()}'),
        row(_s.sReviewGenderLabel, genderLabel(_s, _gender)),
        if (_dob != null) row(_s.sReviewBornLabel, formatDate(_dob!)),
        row(_s.sReviewClassLabel, _class == null ? '-' : (_class!.departmentName.isEmpty ? _class!.className : '${_class!.className} · ${_class!.departmentName}')),
        if (subjectNames.isNotEmpty) row(_s.sReviewSubjectsLabel, subjectNames.join(', ')),
        if (_guardian.text.trim().isNotEmpty) row(_s.sReviewGuardianLabel, _guardian.text.trim()),
        if (_emPhone.text.trim().isNotEmpty) row(_s.sReviewEmergencyPhoneLabel, _emPhone.text.trim()),
        if (!_isEdit) ...[
          const SizedBox(height: 10),
          Text(_s.sNextStepNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ]),
    );
  }
}

// ============================================================
// NEW PARENT ACCOUNT
// ============================================================

class _NewParentDialog extends ConsumerStatefulWidget {
  final AppStrings strings;
  const _NewParentDialog({required this.strings});

  @override
  ConsumerState<_NewParentDialog> createState() => _NewParentDialogState();
}

class _NewParentDialogState extends ConsumerState<_NewParentDialog> {
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
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(400.0, MediaQuery.of(context).size.width - 80);
    return AlertDialog(
      title: Text(_s.sNewParentAccountTitle),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: _s.fullName),
                validator: (v) => (v == null || v.trim().isEmpty) ? _s.required : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: _s.fEmailLoginLabel),
                validator: (v) => (v == null || !v.contains('@')) ? _s.fInvalidEmail : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: _s.fPhoneLabel),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(_s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_s.fCreateAccount),
        ),
      ],
    );
  }
}

// ============================================================
// CREDENTIALS (shown once) + printable slip
// ============================================================

class _CredentialsDialog extends ConsumerStatefulWidget {
  final NewParentCredentials credentials;
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const _CredentialsDialog({required this.credentials, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends ConsumerState<_CredentialsDialog> {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_s.fSlipError)));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = math.min(420.0, MediaQuery.of(context).size.width - 80);

    return AlertDialog(
      title: Text(_s.fParentAccountCreatedTitle),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(_s.sAccountCreatedWarning, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 14),
            Text(_s.sSignInAtLabel, style: theme.textTheme.bodySmall),
            SelectableText(_signInUrl, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_s.email, style: theme.textTheme.bodySmall),
            SelectableText(_c.email, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_s.sTemporaryPasswordLabel, style: theme.textTheme.bodySmall),
            SelectableText(_c.temporaryPassword, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
          ]),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _plainText));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_s.fCopiedMessage)));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(_s.sCopy),
        ),
        TextButton.icon(
          onPressed: _printing ? null : _printSlip,
          icon: _printing
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print_outlined, size: 16),
          label: Text(_s.sPrintSlip),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(_s.fDone)),
      ],
    );
  }
}
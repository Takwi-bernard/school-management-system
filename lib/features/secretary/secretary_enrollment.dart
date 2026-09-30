import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import 'secretary_models.dart';
import 'secretary_payments.dart';
import 'secretary_providers.dart';

class EnrollChildPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  const EnrollChildPage({super.key, required this.schoolId, required this.landing});

  @override
  ConsumerState<EnrollChildPage> createState() => _EnrollChildPageState();
}

class _EnrollChildPageState extends ConsumerState<EnrollChildPage> {
  static const _titles = ['Parent', 'Child', 'Class', 'Guardian', 'Review'];

  int _step = 0;
  bool _submitting = false;

  // step 0 - parent
  ParentMatch? _parent;
  final _searchController = TextEditingController();
  List<ParentMatch> _results = [];
  bool _searching = false;
  bool _searchedOnce = false;
  Timer? _debounce;

  // step 1 - child
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  String? _gender;
  DateTime? _dob;
  XFile? _photo;

  // step 2 - class + subjects
  String? _departmentId;
  EnrollClass? _class;
  List<EnrollSubject> _offerings = [];
  final Set<String> _subjects = {};

  // step 3 - guardian
  final _guardian = TextEditingController();
  final _emName = TextEditingController();
  final _emPhone = TextEditingController();
  final _address = TextEditingController();

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
    setState(() {
      _step = 0;
      _parent = null;
      _results = [];
      _searchedOnce = false;
      _searchController.clear();
      _first.clear();
      _last.clear();
      _gender = null;
      _dob = null;
      _photo = null;
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
      setState(() { _results = []; _searchedOnce = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      try {
        final found = await ref.read(secretaryRepositoryProvider).findParents(value.trim());
        if (mounted) setState(() { _results = found; _searchedOnce = true; });
      } catch (e) {
        _snack('$e'.replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _createParent() async {
    final creds = await showDialog<NewParentCredentials>(context: context, builder: (_) => const _NewParentDialog());
    if (creds == null || !mounted) return;
    setState(() => _parent = ParentMatch(parentId: creds.parentId, fullName: creds.fullName, phone: creds.phone, email: creds.email));
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CredentialsDialog(credentials: creds, schoolId: widget.schoolId, landing: widget.landing),
    );
  }

  // ---------------- child ----------------

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _photo = picked);
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
    setState(() { _class = c; _offerings = []; _subjects.clear(); });
    try {
      final offerings = await ref.read(secretaryRepositoryProvider).getSubjectOfferings(c.id, c.departmentId);
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        for (final o in offerings.where((o) => o.isCompulsory)) {
          _subjects.add(o.subjectId);
        }
      });
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  // ---------------- navigation ----------------

  void _next() {
    if (_step == 0 && _parent == null) return _snack('Select or create the parent first.');
    if (_step == 1) {
      if (!_formKey.currentState!.validate()) return;
      if (_gender == null) return _snack('Please select the child\'s gender.');
    }
    if (_step == 2 && _class == null) return _snack('Please select a class.');
    setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final repo = ref.read(secretaryRepositoryProvider);

      String? photoUrl;
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        final ext = _photo!.name.contains('.') ? _photo!.name.split('.').last : 'jpg';
        photoUrl = await repo.uploadChildPhoto(schoolId: widget.schoolId, bytes: bytes, extension: ext);
      }

      final childName = '${_first.text.trim()} ${_last.text.trim()}';
      final result = await repo.enrollChild(
        parentId: _parent!.parentId,
        classId: _class!.id,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        gender: _gender!,
        dateOfBirth: _dob,
        guardianName: _guardian.text.trim().isEmpty ? null : _guardian.text.trim(),
        emergencyName: _emName.text.trim().isEmpty ? null : _emName.text.trim(),
        emergencyPhone: _emPhone.text.trim().isEmpty ? null : _emPhone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        photoUrl: photoUrl,
        subjectIds: _subjects.toList(),
      );

      ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
      if (!mounted) return;

      final fee = result.registrationFee;
      if (fee == null || fee <= 0) {
        _snack('Enrollment created for $childName, but this class has no registration fee configured yet. Ask the Principal to set it under School Fees.');
        _reset();
        return;
      }

      final paid = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CollectPaymentDialog(
          landing: widget.landing,
          kind: 'registration',
          purpose: 'Registration Fee',
          childName: childName,
          amount: fee,
          admissionRequestId: result.admissionRequestId,
        ),
      );
      if (!mounted) return;
      _snack(paid == true
          ? 'Registration fee recorded. $childName is now with the Principal for approval.'
          : 'Enrollment saved. Collect the registration fee anytime from "Awaiting Registration Payment".');
      ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
      _reset();
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classesAsync = ref.watch(enrollClassesProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enroll a Child', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Step ${_step + 1} of ${_titles.length} · ${_titles[_step]}',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: (_step + 1) / _titles.length, minHeight: 6),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _stepContent(theme, classesAsync),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (_step > 0) OutlinedButton(onPressed: _submitting ? null : () => setState(() => _step--), child: const Text('Back')),
            const Spacer(),
            if (_step < _titles.length - 1) FilledButton(onPressed: _next, child: const Text('Next')),
            if (_step == _titles.length - 1)
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_submitting ? 'Saving...' : 'Create Enrollment'),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _stepContent(ThemeData theme, AsyncValue<List<EnrollClass>> classesAsync) {
    switch (_step) {
      case 0:
        return _parentStep(theme);
      case 1:
        return _childStep(theme);
      case 2:
        return classesAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (classes) => _classStep(theme, classes),
        );
      case 3:
        return _guardianStep(theme);
      default:
        return _reviewStep(theme);
    }
  }

  Widget _parentStep(ThemeData theme) {
    if (_parent != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_parent!.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${_parent!.email ?? ''} · ${_parent!.phone ?? ''}', style: theme.textTheme.bodySmall),
            ]),
          ),
          TextButton(onPressed: () => setState(() => _parent = null), child: const Text('Change')),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Search for the parent by name, phone or email. If they have no account yet, create one.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search parent', border: OutlineInputBorder()),
      ),
      if (_searching) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      const SizedBox(height: 8),
      ..._results.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${p.email ?? 'no email'} · ${p.phone ?? 'no phone'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() => _parent = p),
            ),
          )),
      if (_searchedOnce && _results.isEmpty && !_searching)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No parent found. You can create an account for them below.', style: theme.textTheme.bodySmall),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _createParent, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Create a new parent account')),
    ]);
  }

  Widget _childStep(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: _photo == null
                  ? Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 28)
                  : ClipOval(child: Image.network(_photo!.path, width: 92, height: 92, fit: BoxFit.cover)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text('Photo (recommended - used on ID cards and report cards)', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
        const SizedBox(height: 20),
        TextFormField(
          controller: _first,
          decoration: const InputDecoration(labelText: 'First name', border: OutlineInputBorder()),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _last,
          decoration: const InputDecoration(labelText: 'Last name', border: OutlineInputBorder()),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _genderCard('Male', 'male', theme)),
          const SizedBox(width: 10),
          Expanded(child: _genderCard('Female', 'female', theme)),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDob,
          icon: const Icon(Icons.cake_outlined),
          label: Text(_dob == null ? 'Date of birth (optional)' : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
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

  Widget _classStep(ThemeData theme, List<EnrollClass> classes) {
    final departments = <String, String>{for (final c in classes) c.departmentId: c.departmentName};
    final filtered = classes.where((c) => c.departmentId == _departmentId).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Choose the department first, then the class - the same class name can exist in two departments.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _departmentId,
        decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
        items: departments.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.isEmpty ? 'Department' : e.value))).toList(),
        onChanged: (v) => setState(() { _departmentId = v; _class = null; _offerings = []; _subjects.clear(); }),
      ),
      const SizedBox(height: 12),
      ...filtered.map((c) {
        final selected = _class?.id == c.id;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
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
                  Expanded(child: Text('${c.className}  ·  ${c.departmentName}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (selected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                ]),
              ),
            ),
          ),
        );
      }),
      if (_class != null && _offerings.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Subjects', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text('Compulsory subjects are locked in.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ..._offerings.map((o) => CheckboxListTile(
              value: _subjects.contains(o.subjectId),
              title: Text(o.name),
              subtitle: o.isCompulsory ? const Text('Compulsory') : const Text('Optional'),
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
    ]);
  }

  Widget _guardianStep(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('All optional - helps the school reach the family and prints on the ID card.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      TextField(controller: _guardian, decoration: const InputDecoration(labelText: 'Guardian name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _emName, decoration: const InputDecoration(labelText: 'Emergency contact name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _emPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Emergency contact phone', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
    ]);
  }

  Widget _reviewStep(ThemeData theme) {
    final subjectNames = _offerings.where((o) => _subjects.contains(o.subjectId)).map((o) => o.name).toList();
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(color: theme.colorScheme.outline))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row('Parent', '${_parent?.fullName ?? ''}\n${_parent?.email ?? ''}'),
        row('Child', '${_first.text.trim()} ${_last.text.trim()}'),
        row('Gender', _gender ?? '-'),
        if (_dob != null) row('Born', '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
        row('Class', '${_class?.className ?? ''} · ${_class?.departmentName ?? ''}'),
        if (subjectNames.isNotEmpty) row('Subjects', subjectNames.join(', ')),
        if (_guardian.text.trim().isNotEmpty) row('Guardian', _guardian.text.trim()),
        if (_emPhone.text.trim().isNotEmpty) row('Emergency phone', _emPhone.text.trim()),
        const SizedBox(height: 10),
        Text('Next you will be asked to collect the registration fee (cash, bank, or Mobile Money) - or you can collect it later.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ]),
    );
  }
}

// ============================================================
// NEW PARENT ACCOUNT
// ============================================================

class _NewParentDialog extends ConsumerStatefulWidget {
  const _NewParentDialog();

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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final creds = await ref.read(secretaryRepositoryProvider).createParent(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.pop(context, creds);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New parent account'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (their login)'),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create account'),
        ),
      ],
    );
  }
}

class _CredentialsDialog extends ConsumerWidget {
  final NewParentCredentials credentials;
  final String schoolId;
  final LandingModel landing;
  const _CredentialsDialog({required this.credentials, required this.schoolId, required this.landing});

  String get _signInUrl => Uri.base.origin;

  String get _plainText =>
      '${landing.schoolName}\nParent account\nSign in: $_signInUrl\nEmail: ${credentials.email}\nTemporary password: ${credentials.temporaryPassword}\nPlease change your password after signing in.';

  Future<void> _printSlip(WidgetRef ref) async {
    final assets = await ref.read(officialBrandingProvider(schoolId).future);
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
          buildDocumentHeader(branding: branding, schoolName: landing.schoolName, motto: landing.motto),
          pw.SizedBox(height: 18),
          pw.Center(child: pw.Text('PARENT ACCOUNT DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 14),
          line('Name', credentials.fullName),
          line('Sign in at', _signInUrl),
          line('Email', credentials.email),
          line('Temporary password', credentials.temporaryPassword),
          pw.SizedBox(height: 16),
          pw.Text('Please sign in and change your password right away. Keep this slip private.', style: const pw.TextStyle(fontSize: 9)),
        ]),
      ),
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'parent_account_${credentials.fullName.replaceAll(' ', '_')}.pdf');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Parent account created'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Text('These details are shown ONLY NOW. Give them to the parent (print the slip or copy them) before closing this window.', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 14),
          Text('Sign in at', style: theme.textTheme.bodySmall),
          SelectableText(_signInUrl, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Email', style: theme.textTheme.bodySmall),
          SelectableText(credentials.email, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Temporary password', style: theme.textTheme.bodySmall),
          SelectableText(credentials.temporaryPassword, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
        ]),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _plainText));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy'),
        ),
        TextButton.icon(onPressed: () => _printSlip(ref), icon: const Icon(Icons.print_outlined, size: 16), label: const Text('Print slip')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}
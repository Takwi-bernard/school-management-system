import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// ADMISSIONS AWAITING APPROVAL - Department -> Class -> list
// ============================================================

class AdmissionsReviewPage extends ConsumerStatefulWidget {
  final String schoolId;
  const AdmissionsReviewPage({super.key, required this.schoolId});

  @override
  ConsumerState<AdmissionsReviewPage> createState() => _AdmissionsReviewPageState();
}

class _AdmissionsReviewPageState extends ConsumerState<AdmissionsReviewPage> {
  DepartmentFull? _department;
  ManagedClass? _class;

  Future<void> _approve(BuildContext context, WidgetRef ref, PendingAdmissionReview a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve ${a.fullName}?'),
        content: Text('This creates a real student record, enrolls them in ${a.requestedClassName}, and links them to their parent\'s account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(principalRepositoryProvider).approveAdmission(a.id);
      ref.invalidate(admissionsForClassProvider((schoolId: widget.schoolId, classId: _class!.id)));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${a.fullName} approved and enrolled.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, PendingAdmissionReview a) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject ${a.fullName}?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('The parent will see this request marked as rejected.'),
          const SizedBox(height: 12),
          TextField(controller: reasonController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Reason (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).rejectAdmission(a.id, reasonController.text.trim());
    ref.invalidate(admissionsForClassProvider((schoolId: widget.schoolId, classId: _class!.id)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_class != null) {
      return Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _class = null)),
              Text('${_class!.className} · ${_department!.departmentName}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final admissionsAsync = ref.watch(admissionsForClassProvider((schoolId: widget.schoolId, classId: _class!.id)));
                  return admissionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (admissions) {
                      if (admissions.isEmpty) return const Center(child: Text('No pending admissions left in this class.'));
                      return ListView.separated(
                        itemCount: admissions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final a = admissions[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(radius: 24, backgroundImage: a.photoUrl != null ? NetworkImage(a.photoUrl!) : null, child: a.photoUrl == null ? Text(a.firstName.isNotEmpty ? a.firstName[0] : '?') : null),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(a.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                                ]),
                                const SizedBox(height: 10),
                                if (a.guardianName != null) _detailRow('Guardian', a.guardianName!),
                                if (a.emergencyContactName != null) _detailRow('Emergency Contact', '${a.emergencyContactName} · ${a.emergencyContactPhone ?? ""}'),
                                if (a.selectedSubjectNames.isNotEmpty) _detailRow('Subjects', a.selectedSubjectNames.join(', ')),
                                const SizedBox(height: 12),
                                Row(children: [
                                  OutlinedButton(onPressed: () => _reject(context, ref, a), child: const Text('Reject')),
                                  const SizedBox(width: 8),
                                  FilledButton(onPressed: () => _approve(context, ref, a), child: const Text('Approve')),
                                ]),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (_department != null) {
      return Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _department = null)),
              Text(_department!.departmentName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final classesAsync = ref.watch(classesWithPendingAdmissionsProvider((schoolId: widget.schoolId, departmentId: _department!.id)));
                  return classesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (classes) {
                      if (classes.isEmpty) return const Center(child: Text('No pending admissions in this department.'));
                      return ListView.separated(
                        itemCount: classes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _DrillTile(title: classes[i].className, onTap: () => setState(() => _class = classes[i])),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admissions Awaiting Approval', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Choose a department, then a class.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final deptsAsync = ref.watch(departmentsWithPendingAdmissionsProvider(widget.schoolId));
                return deptsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (departments) {
                    if (departments.isEmpty) return const Center(child: Text('No admissions are currently waiting for approval.'));
                    return ListView.separated(
                      itemCount: departments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _DrillTile(title: departments[i].departmentName, onTap: () => setState(() => _department = departments[i])),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: Colors.black87), children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: value),
        ])),
      );
}

class _DrillTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _DrillTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded)])),
      ),
    );
  }
}

// ============================================================
// ALL STUDENTS - tap a student to see detail + guardians
// ============================================================

class AllStudentsPage extends ConsumerStatefulWidget {
  final String schoolId;
  const AllStudentsPage({super.key, required this.schoolId});

  @override
  ConsumerState<AllStudentsPage> createState() => _AllStudentsPageState();
}

class _AllStudentsPageState extends ConsumerState<AllStudentsPage> {
  String? _departmentFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentsAsync = ref.watch(allStudentsProvider(widget.schoolId));
    final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('All Students', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStudentByPrincipalPage(schoolId: widget.schoolId))),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Enroll a Student'),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Every enrolled student at this school. Tap a student to see their full profile and guardians.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Search by name', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()), onChanged: (v) => setState(() => _search = v.toLowerCase()))),
            const SizedBox(width: 12),
            departmentsAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (departments) => DropdownButton<String?>(
                value: _departmentFilter,
                hint: const Text('All departments'),
                items: [const DropdownMenuItem(value: null, child: Text('All departments')), ...departments.map((d) => DropdownMenuItem(value: d.departmentName, child: Text(d.departmentName)))],
                onChanged: (v) => setState(() => _departmentFilter = v),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (students) {
                final filtered = students.where((s) {
                  final matchesSearch = _search.isEmpty || s.fullName.toLowerCase().contains(_search);
                  final matchesDept = _departmentFilter == null || s.departmentName == _departmentFilter;
                  return matchesSearch && matchesDept;
                }).toList();
                if (filtered.isEmpty) return const Center(child: Text('No students match this filter.'));
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => showDialog(context: context, builder: (_) => StudentDetailDialog(studentId: s.id)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            CircleAvatar(backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null, child: s.photoUrl == null ? Text(s.firstName.isNotEmpty ? s.firstName[0] : '?') : null),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${s.admissionNumber} · ${s.className} · ${s.departmentName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                            ])),
                            const Icon(Icons.chevron_right_rounded),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STUDENT DETAIL DIALOG
// ============================================================

class StudentDetailDialog extends ConsumerWidget {
  final String studentId;
  const StudentDetailDialog({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(studentDetailProvider(studentId));
    return AlertDialog(
      content: SizedBox(
        width: 420,
        child: detailAsync.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (detail) {
            final s = detail.student;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(children: [
                      CircleAvatar(radius: 36, backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null, child: s.photoUrl == null ? Text(s.firstName.isNotEmpty ? s.firstName[0] : '?') : null),
                      const SizedBox(height: 10),
                      Text(s.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(s.admissionNumber, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ]),
                  ),
                  const Divider(height: 28),
                  Text('${s.className} · ${s.departmentName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Status: ${s.currentStatus}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 20),
                  Text('Guardians', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (detail.guardians.isEmpty)
                    const Text('No guardian information on file.')
                  else
                    ...detail.guardians.map((g) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(g.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              Text('(${g.relationshipType})', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                              if (g.isPrimary) ...[const SizedBox(width: 6), const Chip(label: Text('Primary', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)],
                            ]),
                            if (g.phone != null) Text('Phone: ${g.phone}', style: Theme.of(context).textTheme.bodySmall),
                            if (g.email != null) Text('Email: ${g.email}', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        )),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

// ============================================================
// PRINCIPAL ENROLLS A STUDENT ON BEHALF OF A PARENT
// Same downstream pipeline as parent-initiated enrollment: goes to
// 'awaiting_payment', appears on the SELECTED parent's own dashboard
// for them to pay - no separate payment step exists here by design.
// ============================================================

class CreateStudentByPrincipalPage extends ConsumerStatefulWidget {
  final String schoolId;
  const CreateStudentByPrincipalPage({super.key, required this.schoolId});

  @override
  ConsumerState<CreateStudentByPrincipalPage> createState() => _CreateStudentByPrincipalPageState();
}

class _CreateStudentByPrincipalPageState extends ConsumerState<CreateStudentByPrincipalPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _guardianName = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _address = TextEditingController();
  final _parentSearchController = TextEditingController();

  ParentSearchResult? _selectedParent;
  List<ParentSearchResult> _parentResults = [];
  Timer? _debounce;

  ManagedClass? _selectedClass;
  final Set<String> _selectedSubjects = {};
  List<SubjectOfferingRow> _offerings = [];
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_firstName, _lastName, _guardianName, _emergencyName, _emergencyPhone, _address, _parentSearchController]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onParentSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await ref.read(principalRepositoryProvider).searchParents(widget.schoolId, query);
      if (mounted) setState(() => _parentResults = results);
    });
  }

  Future<void> _onClassSelected(ManagedClass c) async {
    setState(() { _selectedClass = c; _selectedSubjects.clear(); });
    final offerings = await ref.read(principalRepositoryProvider).getSubjectOfferingsForClass(widget.schoolId, c.id);
    final actuallyOffered = offerings.where((o) => o.isOffered).toList();
    if (!mounted) return;
    setState(() {
      _offerings = actuallyOffered;
      for (final o in actuallyOffered.where((o) => o.isCompulsory)) {
        _selectedSubjects.add(o.subjectId);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedParent == null || _selectedClass == null) {
      if (_selectedParent == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the parent.')));
      if (_selectedClass == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final principal = await ref.read(principalProfileProvider.future);
      if (principal == null) throw Exception('Could not load your principal profile.');
      final yearId = await ref.read(principalRepositoryProvider).getCurrentAcademicYearId(widget.schoolId);
      if (yearId == null) throw Exception('No current academic year is set for this school.');

      await ref.read(principalRepositoryProvider).createAdmissionOnBehalfOfParent(
            schoolId: widget.schoolId,
            parentId: _selectedParent!.parentId,
            requestedClassId: _selectedClass!.id,
            academicYearId: yearId,
            principalUserId: principal.userId,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            guardianName: _guardianName.text.trim().isEmpty ? null : _guardianName.text.trim(),
            emergencyContactName: _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
            emergencyContactPhone: _emergencyPhone.text.trim().isEmpty ? null : _emergencyPhone.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            selectedSubjectIds: _selectedSubjects.toList(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment created. It now appears on ${_selectedParent!.fullName}\'s dashboard for the registration fee to be paid.')),
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
    final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Enroll a Student')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Text('Use this to enroll a child on behalf of a parent who has an account but hasn\'t completed enrollment themselves. The parent will still pay the registration fee from their own dashboard.'),
                  ),
                  const SizedBox(height: 20),
                  Text('1. Select the Parent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _parentSearchController,
                    decoration: const InputDecoration(labelText: 'Search parent by name', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
                    onChanged: _onParentSearchChanged,
                  ),
                  if (_selectedParent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        label: Text('Selected: ${_selectedParent!.fullName}'),
                        onDeleted: () => setState(() => _selectedParent = null),
                      ),
                    )
                  else if (_parentResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: _parentResults.map((p) => ListTile(
                          title: Text(p.fullName),
                          subtitle: Text('${p.email ?? ""} · ${p.phone ?? ""}'),
                          onTap: () => setState(() { _selectedParent = p; _parentResults = []; _parentSearchController.clear(); }),
                        )).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text('2. Child Information', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  classesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (classes) => DropdownButtonFormField<ManagedClass>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                      items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
                      onChanged: (v) { if (v != null) _onClassSelected(v); },
                    ),
                  ),
                  if (_offerings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Subjects', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ..._offerings.map((o) => CheckboxListTile(
                          value: _selectedSubjects.contains(o.subjectId),
                          title: Text(o.subjectName),
                          subtitle: o.isCompulsory ? const Text('Compulsory') : null,
                          onChanged: o.isCompulsory ? null : (v) => setState(() { if (v == true) { _selectedSubjects.add(o.subjectId); } else { _selectedSubjects.remove(o.subjectId); } }),
                        )),
                  ],
                  const SizedBox(height: 24),
                  Text('3. Guardian Information (optional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  TextFormField(controller: _guardianName, decoration: const InputDecoration(labelText: 'Guardian Name', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _emergencyName, decoration: const InputDecoration(labelText: 'Emergency Contact Name', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _emergencyPhone, decoration: const InputDecoration(labelText: 'Emergency Contact Phone', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()), maxLines: 2),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Enrollment'),
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
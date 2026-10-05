import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';

Widget _darkField(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) => TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );

class AcademicStructurePage extends ConsumerStatefulWidget {
  final SchoolSummary school;
  const AcademicStructurePage({super.key, required this.school});

  @override
  ConsumerState<AcademicStructurePage> createState() => _AcademicStructurePageState();
}

class _AcademicStructurePageState extends ConsumerState<AcademicStructurePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(academicStructureProvider(widget.school.id));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text('${widget.school.schoolName} · Academic Structure', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [Tab(text: 'Departments & Classes'), Tab(text: 'Subjects'), Tab(text: 'Years & Sequences'), Tab(text: 'Fees')],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('$e', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center))),
        data: (structure) => TabBarView(controller: _tabs, children: [
          _DepartmentsClassesTab(schoolId: widget.school.id, structure: structure),
          _SubjectsTab(schoolId: widget.school.id, structure: structure),
          _YearsTermsTab(schoolId: widget.school.id, structure: structure),
          _FeesTab(schoolId: widget.school.id, structure: structure),
        ]),
      ),
    );
  }
}

// ============================================================
// DEPARTMENTS & CLASSES
// ============================================================

class _DepartmentsClassesTab extends ConsumerWidget {
  final String schoolId;
  final AcademicStructure structure;
  const _DepartmentsClassesTab({required this.schoolId, required this.structure});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Departments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          FilledButton.icon(
            onPressed: () async {
              final saved = await showDialog<bool>(context: context, builder: (_) => _DepartmentDialog(schoolId: schoolId));
              if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Department'),
          ),
        ]),
        const SizedBox(height: 12),
        ...structure.departments.map((dept) {
          final classesInDept = structure.classes.where((c) => c.departmentId == dept.id).toList()..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(dept.departmentName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                  onPressed: () async {
                    final saved = await showDialog<bool>(context: context, builder: (_) => _DepartmentDialog(schoolId: schoolId, existing: dept));
                    if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  onPressed: () async {
                    await ref.read(superAdminRepositoryProvider).deleteDepartment(dept.id);
                    ref.invalidate(academicStructureProvider(schoolId));
                  },
                ),
              ]),
              const SizedBox(height: 8),
              ...classesInDept.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(child: Text('${c.className} (${c.classCode ?? "GEN"}) · max ${c.maxStudents}', style: TextStyle(color: c.isActive ? Colors.white70 : Colors.white24))),
                          if (!c.isActive)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: const Text('Inactive', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                      IconButton(
                        icon: Icon(c.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38, size: 16),
                        tooltip: c.isActive ? 'Deactivate' : 'Reactivate',
                        onPressed: () async {
                          await ref.read(superAdminRepositoryProvider).saveClass(
                                id: c.id,
                                schoolId: schoolId,
                                className: c.className,
                                classCode: c.classCode,
                                departmentId: c.departmentId,
                                levelOrder: c.levelOrder,
                                maxStudents: c.maxStudents,
                                isActive: !c.isActive,
                              );
                          ref.invalidate(academicStructureProvider(schoolId));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 16),
                        onPressed: () async {
                          final saved = await showDialog<bool>(context: context, builder: (_) => _ClassDialog(schoolId: schoolId, departmentId: dept.id, existing: c));
                          if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                        },
                      ),
                    ]),
                  )),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final saved = await showDialog<bool>(context: context, builder: (_) => _ClassDialog(schoolId: schoolId, departmentId: dept.id));
                  if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Class'),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _DepartmentDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final AsDepartment? existing;
  const _DepartmentDialog({required this.schoolId, this.existing});

  @override
  ConsumerState<_DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends ConsumerState<_DepartmentDialog> {
  late final TextEditingController _name;
  late final TextEditingController _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.departmentName ?? '');
    _type = TextEditingController(text: widget.existing?.departmentType ?? 'general');
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveDepartment(id: widget.existing?.id, schoolId: widget.schoolId, name: _name.text.trim(), type: _type.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.existing == null ? 'Add Department' : 'Edit Department', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _darkField(_name, 'Department name'),
          const SizedBox(height: 10),
          _darkField(_type, 'Type (e.g. general, technical, commercial)'),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}

class _ClassDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String departmentId;
  final AsClass? existing;
  const _ClassDialog({required this.schoolId, required this.departmentId, this.existing});

  @override
  ConsumerState<_ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends ConsumerState<_ClassDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _level;
  late final TextEditingController _capacity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.className ?? '');
    _code = TextEditingController(text: e?.classCode ?? '');
    _level = TextEditingController(text: e?.levelOrder.toString() ?? '');
    _capacity = TextEditingController(text: e?.maxStudents.toString() ?? '50');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _level.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      // Preserve the class's current active state explicitly - never
      // silently reactivate a class the Super Admin had deactivated.
      await ref.read(superAdminRepositoryProvider).saveClass(
            id: widget.existing?.id,
            schoolId: widget.schoolId,
            className: _name.text.trim(),
            classCode: _code.text.trim().isEmpty ? null : _code.text.trim(),
            departmentId: widget.departmentId,
            levelOrder: int.tryParse(_level.text) ?? 0,
            maxStudents: int.tryParse(_capacity.text) ?? 50,
            isActive: widget.existing?.isActive,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.existing == null ? 'Add Class' : 'Edit Class', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _darkField(_name, 'Class name (e.g. Form 1E)'),
          const SizedBox(height: 10),
          _darkField(_code, 'Class code (e.g. F1E)'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _darkField(_level, 'Order', keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _darkField(_capacity, 'Max students', keyboardType: TextInputType.number)),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}

// ============================================================
// SUBJECTS - with coefficient per department, offering per class
// ============================================================

class _SubjectsTab extends ConsumerStatefulWidget {
  final String schoolId;
  final AcademicStructure structure;
  const _SubjectsTab({required this.schoolId, required this.structure});

  @override
  ConsumerState<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends ConsumerState<_SubjectsTab> {
  AsDepartment? _selectedDept;
  AsClass? _selectedClass;

  @override
  Widget build(BuildContext context) {
    final structure = widget.structure;
    final subjectsById = {for (final s in structure.subjects) s.id: s};
    final subjectCoeffsForDept = _selectedDept == null ? <AsSubjectDepartment>[] : structure.subjectDepartments.where((sd) => sd.departmentId == _selectedDept!.id).toList();
    final classesInDept = _selectedDept == null ? <AsClass>[] : structure.classes.where((c) => c.departmentId == _selectedDept!.id).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<AsDepartment>(
          initialValue: _selectedDept,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: '1. Department', labelStyle: TextStyle(color: Colors.white38)),
          items: structure.departments.map((d) => DropdownMenuItem(value: d, child: Text(d.departmentName))).toList(),
          onChanged: (v) => setState(() {
            _selectedDept = v;
            _selectedClass = null;
          }),
        ),
        if (_selectedDept != null) ...[
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('Subjects & Coefficients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
            FilledButton.icon(
              onPressed: () async {
                final saved = await showDialog<bool>(context: context, builder: (_) => _SubjectDialog(schoolId: widget.schoolId, departmentId: _selectedDept!.id, allSubjects: structure.subjects));
                if (saved == true) ref.invalidate(academicStructureProvider(widget.schoolId));
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Subject'),
            ),
          ]),
          const SizedBox(height: 10),
          ...subjectCoeffsForDept.map((sd) {
            final subject = subjectsById[sd.subjectId];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(subject?.subjectName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text('Coef. ${sd.coefficient}', style: const TextStyle(color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 16),
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (_) => _SubjectDialog(
                        schoolId: widget.schoolId,
                        departmentId: _selectedDept!.id,
                        allSubjects: structure.subjects,
                        existingSubjectId: subject?.id,
                        existingCoefficient: sd.coefficient,
                      ),
                    );
                    if (saved == true) ref.invalidate(academicStructureProvider(widget.schoolId));
                  },
                ),
              ]),
            );
          }),
          const SizedBox(height: 24),
          const Text('Which classes offer each subject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          DropdownButtonFormField<AsClass>(
            initialValue: _selectedClass,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: '2. Class', labelStyle: TextStyle(color: Colors.white38)),
            items: classesInDept.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
            onChanged: (v) => setState(() => _selectedClass = v),
          ),
          if (_selectedClass != null) ...[
            const SizedBox(height: 10),
            ...subjectCoeffsForDept.map((sd) {
              final subject = subjectsById[sd.subjectId];
              final offering = structure.subjectOfferings.where((o) => o.classId == _selectedClass!.id && o.subjectId == sd.subjectId).toList();
              final isOffered = offering.isNotEmpty;
              final isCompulsory = isOffered && offering.first.isCompulsory;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: Text(subject?.subjectName ?? '', style: const TextStyle(color: Colors.white))),
                  Row(children: [
                    const Text('Compulsory', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Switch(
                      value: isCompulsory,
                      onChanged: isOffered
                          ? (v) async {
                              await ref.read(superAdminRepositoryProvider).setSubjectOffering(classId: _selectedClass!.id, subjectId: sd.subjectId, isOffered: true, isCompulsory: v);
                              ref.invalidate(academicStructureProvider(widget.schoolId));
                            }
                          : null,
                    ),
                  ]),
                  Switch(
                    value: isOffered,
                    onChanged: (v) async {
                      await ref.read(superAdminRepositoryProvider).setSubjectOffering(classId: _selectedClass!.id, subjectId: sd.subjectId, isOffered: v, isCompulsory: false);
                      ref.invalidate(academicStructureProvider(widget.schoolId));
                    },
                  ),
                ]),
              );
            }),
          ],
        ],
      ]),
    );
  }
}

class _SubjectDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String departmentId;
  final List<AsSubject> allSubjects;
  final String? existingSubjectId;
  final int? existingCoefficient;
  const _SubjectDialog({required this.schoolId, required this.departmentId, required this.allSubjects, this.existingSubjectId, this.existingCoefficient});

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  AsSubject? _picked;
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _coefficient;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSubjectId != null) {
      final matches = widget.allSubjects.where((s) => s.id == widget.existingSubjectId);
      _picked = matches.isNotEmpty ? matches.first : null;
    }
    _name = TextEditingController();
    _code = TextEditingController();
    _coefficient = TextEditingController(text: (widget.existingCoefficient ?? 2).toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _coefficient.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveSubjectWithCoefficient(
            subjectId: _picked?.id,
            schoolId: widget.schoolId,
            departmentId: widget.departmentId,
            subjectCode: _picked == null ? _code.text.trim() : null,
            subjectName: _picked == null ? _name.text.trim() : null,
            coefficient: int.tryParse(_coefficient.text) ?? 1,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditingCoefficientOnly = widget.existingSubjectId != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(isEditingCoefficientOnly ? 'Edit Coefficient' : 'Add Subject', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!isEditingCoefficientOnly) ...[
            DropdownButtonFormField<AsSubject?>(
              initialValue: _picked,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Use an existing subject (optional)', labelStyle: TextStyle(color: Colors.white38)),
              items: [
                const DropdownMenuItem(value: null, child: Text('— New subject —')),
                ...widget.allSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s.subjectName))),
              ],
              onChanged: (v) => setState(() => _picked = v),
            ),
            if (_picked == null) ...[
              const SizedBox(height: 10),
              _darkField(_name, 'Subject name'),
              const SizedBox(height: 10),
              _darkField(_code, 'Subject code'),
            ],
            const SizedBox(height: 10),
          ],
          _darkField(_coefficient, 'Coefficient', keyboardType: TextInputType.number),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}

// ============================================================
// YEARS, TERMS & SEQUENCES - now with a one-tap "set current" and
// full edit for both Years and Terms, matching the pattern that was
// missing before.
// ============================================================

class _YearsTermsTab extends ConsumerWidget {
  final String schoolId;
  final AcademicStructure structure;
  const _YearsTermsTab({required this.schoolId, required this.structure});

  Future<void> _setCurrentYear(WidgetRef ref, BuildContext context, AsAcademicYear year) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Set ${year.yearName} as the current academic year?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Every class, term, sequence, fee lookup, promotion, and report card in this school is based on whichever year is current. The previous current year will no longer be marked as current.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Set as Current')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(superAdminRepositoryProvider).setCurrentAcademicYear(id: year.id, schoolId: schoolId);
    ref.invalidate(academicStructureProvider(schoolId));
  }

  Future<void> _setCurrentTerm(WidgetRef ref, AsAcademicTerm term) async {
    await ref.read(superAdminRepositoryProvider).setCurrentAcademicTerm(id: term.id, academicYearId: term.academicYearId);
    ref.invalidate(academicStructureProvider(schoolId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCurrent = structure.academicYears.any((y) => y.isCurrent);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!hasCurrent && structure.academicYears.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No academic year is set as current. Classes, fees, and promotions will not work correctly until one is marked current.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                ),
              ),
            ]),
          ),
        Row(children: [
          const Expanded(child: Text('Academic Years', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          FilledButton.icon(
            onPressed: () async {
              final saved = await showDialog<bool>(context: context, builder: (_) => _AcademicYearDialog(schoolId: schoolId));
              if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Year'),
          ),
        ]),
        const SizedBox(height: 12),
        ...structure.academicYears.map((year) {
          final terms = structure.academicTerms.where((t) => t.academicYearId == year.id).toList()..sort((a, b) => a.termOrder.compareTo(b.termOrder));
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: year.isCurrent ? Border.all(color: Colors.indigo, width: 1.5) : null),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(year.yearName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                if (year.isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Current', style: TextStyle(color: Colors.white, fontSize: 11)),
                  )
                else
                  TextButton(onPressed: () => _setCurrentYear(ref, context, year), child: const Text('Set as Current', style: TextStyle(fontSize: 12))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                  onPressed: () async {
                    final saved = await showDialog<bool>(context: context, builder: (_) => _AcademicYearDialog(schoolId: schoolId, existing: year));
                    if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                  },
                ),
              ]),
              const SizedBox(height: 10),
              ...terms.map((term) {
                final periods = structure.examPeriods.where((p) => p.academicTermId == term.id).toList()..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(term.termName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                        if (term.isCurrent)
                          const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 16))
                        else
                          TextButton(
                            onPressed: () => _setCurrentTerm(ref, term),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Set Current', style: TextStyle(fontSize: 11)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 14),
                          onPressed: () async {
                            final saved = await showDialog<bool>(context: context, builder: (_) => _AcademicTermDialog(academicYearId: year.id, nextOrder: term.termOrder, existing: term));
                            if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                          },
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: periods
                            .map((p) => Chip(label: Text(p.periodName, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.white.withValues(alpha: 0.06), labelStyle: const TextStyle(color: Colors.white)))
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final saved = await showDialog<bool>(
                            context: context,
                            builder: (_) => _ExamPeriodDialog(schoolId: schoolId, academicYearId: year.id, academicTermId: term.id, nextOrder: periods.length + 1),
                          );
                          if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                        },
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Add Sequence'),
                      ),
                    ]),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () async {
                  final saved = await showDialog<bool>(context: context, builder: (_) => _AcademicTermDialog(academicYearId: year.id, nextOrder: terms.length + 1));
                  if (saved == true) ref.invalidate(academicStructureProvider(schoolId));
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Term'),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _AcademicYearDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final AsAcademicYear? existing;
  const _AcademicYearDialog({required this.schoolId, this.existing});

  @override
  ConsumerState<_AcademicYearDialog> createState() => _AcademicYearDialogState();
}

class _AcademicYearDialogState extends ConsumerState<_AcademicYearDialog> {
  late final TextEditingController _name;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.yearName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    // For a new year, dates are required. For an edit, keep today's
    // date if the admin didn't re-pick one, rather than blocking save.
    final start = _start ?? DateTime.now();
    final end = _end ?? DateTime.now().add(const Duration(days: 300));
    if (widget.existing == null && (_start == null || _end == null)) return;

    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveAcademicYear(
            id: widget.existing?.id,
            schoolId: widget.schoolId,
            yearName: _name.text.trim(),
            startDate: start,
            endDate: end,
            isCurrent: false, // use the dedicated "Set as Current" action instead
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.existing == null ? 'Add Academic Year' : 'Edit Academic Year', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _darkField(_name, 'Year name (e.g. 2026/2027)'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) setState(() => _start = p);
            },
            child: Text(_start == null ? 'Start date${widget.existing != null ? ' (unchanged if not picked)' : ''}' : '${_start!.day}/${_start!.month}/${_start!.year}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) setState(() => _end = p);
            },
            child: Text(_end == null ? 'End date${widget.existing != null ? ' (unchanged if not picked)' : ''}' : '${_end!.day}/${_end!.month}/${_end!.year}'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}

class _AcademicTermDialog extends ConsumerStatefulWidget {
  final String academicYearId;
  final int nextOrder;
  final AsAcademicTerm? existing;
  const _AcademicTermDialog({required this.academicYearId, required this.nextOrder, this.existing});

  @override
  ConsumerState<_AcademicTermDialog> createState() => _AcademicTermDialogState();
}

class _AcademicTermDialogState extends ConsumerState<_AcademicTermDialog> {
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.termName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveAcademicTerm(
            id: widget.existing?.id,
            academicYearId: widget.academicYearId,
            termName: _name.text.trim(),
            termOrder: widget.existing?.termOrder ?? widget.nextOrder,
            isCurrent: false, // use the dedicated "Set Current" action instead
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.existing == null ? 'Add Term' : 'Edit Term', style: const TextStyle(color: Colors.white)),
      content: SizedBox(width: 340, child: _darkField(_name, 'Term name (e.g. First Term)')),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}

class _ExamPeriodDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String academicTermId;
  final int nextOrder;
  const _ExamPeriodDialog({required this.schoolId, required this.academicYearId, required this.academicTermId, required this.nextOrder});

  @override
  ConsumerState<_ExamPeriodDialog> createState() => _ExamPeriodDialogState();
}

class _ExamPeriodDialogState extends ConsumerState<_ExamPeriodDialog> {
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveExamPeriod(
            schoolId: widget.schoolId,
            academicYearId: widget.academicYearId,
            academicTermId: widget.academicTermId,
            periodName: _name.text.trim(),
            sequenceOrder: widget.nextOrder,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Add Sequence', style: TextStyle(color: Colors.white)),
      content: SizedBox(width: 340, child: _darkField(_name, 'Sequence name (e.g. Sequence 1)')),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}

// ============================================================
// FEES
// ============================================================

class _FeesTab extends ConsumerStatefulWidget {
  final String schoolId;
  final AcademicStructure structure;
  const _FeesTab({required this.schoolId, required this.structure});

  @override
  ConsumerState<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends ConsumerState<_FeesTab> {
  AsClass? _selectedClass;
  AsAcademicYear? _selectedYear;
  final _registrationFee = TextEditingController();
  List<Map<String, dynamic>> _installments = [];
  String? _feeId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _registrationFee.dispose();
    super.dispose();
  }

  void _loadFor(String classId, String yearId) {
    final matches = widget.structure.fees.where((f) => f.classId == classId && f.academicYearId == yearId);
    if (matches.isEmpty) {
      _registrationFee.text = '';
      _installments = [];
      _feeId = null;
    } else {
      final fee = matches.first;
      _registrationFee.text = fee.registrationFee.toStringAsFixed(0);
      _feeId = fee.id;
      _installments = widget.structure.installments
          .where((i) => i.feeId == fee.id)
          .map((i) => {'installment_name': i.installmentName, 'amount': i.amount, 'due_date': i.dueDate?.toIso8601String().split('T').first})
          .toList();
    }
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveFeeStructure(
            feeId: _feeId,
            schoolId: widget.schoolId,
            classId: _selectedClass!.id,
            academicYearId: _selectedYear!.id,
            registrationFee: double.tryParse(_registrationFee.text) ?? 0,
            installments: _installments,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee structure saved.')));
        ref.invalidate(academicStructureProvider(widget.schoolId));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final structure = widget.structure;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<AsAcademicYear>(
          initialValue: _selectedYear,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Academic year', labelStyle: TextStyle(color: Colors.white38)),
          items: structure.academicYears.map((y) => DropdownMenuItem(value: y, child: Text('${y.yearName}${y.isCurrent ? ' (Current)' : ''}'))).toList(),
          onChanged: (v) => setState(() {
            _selectedYear = v;
            _loaded = false;
            if (_selectedClass != null && v != null) _loadFor(_selectedClass!.id, v.id);
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AsClass>(
          initialValue: _selectedClass,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Class', labelStyle: TextStyle(color: Colors.white38)),
          items: structure.classes.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
          onChanged: (v) => setState(() {
            _selectedClass = v;
            _loaded = false;
            if (v != null && _selectedYear != null) _loadFor(v.id, _selectedYear!.id);
          }),
        ),
        if (_selectedClass != null && _selectedYear != null && _loaded) ...[
          const SizedBox(height: 20),
          _darkField(_registrationFee, 'Registration fee (FCFA)', keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('Installments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            TextButton.icon(
              onPressed: () => setState(() => _installments.add({'installment_name': 'Installment ${_installments.length + 1}', 'amount': 0.0, 'due_date': null})),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
            ),
          ]),
          ..._installments.asMap().entries.map((entry) {
            final i = entry.key;
            final inst = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: inst['installment_name'] as String?,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white38)),
                    onChanged: (v) => inst['installment_name'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: (inst['amount'] as num).toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Amount', labelStyle: TextStyle(color: Colors.white38)),
                    onChanged: (v) => inst['amount'] = double.tryParse(v) ?? 0,
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => setState(() => _installments.removeAt(i))),
              ]),
            );
          }),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Fee Structure'),
          ),
        ],
      ]),
    );
  }
}
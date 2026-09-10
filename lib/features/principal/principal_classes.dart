import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// TOP LEVEL: pick a Department first, then drill down
// ============================================================

class ManageClassesPage extends ConsumerStatefulWidget {
  final String schoolId;
  const ManageClassesPage({super.key, required this.schoolId});

  @override
  ConsumerState<ManageClassesPage> createState() => _ManageClassesPageState();
}

class _ManageClassesPageState extends ConsumerState<ManageClassesPage> {
  DepartmentFull? _selectedDepartment;

  Future<void> _openDepartmentDialog({DepartmentFull? existing}) async {
    final nameController = TextEditingController(text: existing?.departmentName ?? '');
    final typeController = TextEditingController(text: existing?.departmentType ?? 'general');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New Department' : 'Edit Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Department name (e.g. General Education, Technical)')),
            const SizedBox(height: 12),
            TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Type (e.g. general, technical, commercial)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    final repo = ref.read(principalRepositoryProvider);
    if (existing == null) {
      await repo.createDepartment(schoolId: widget.schoolId, name: nameController.text.trim(), type: typeController.text.trim());
    } else {
      await repo.updateDepartment(departmentId: existing.id, name: nameController.text.trim(), type: typeController.text.trim());
    }
    ref.invalidate(departmentsFullProvider(widget.schoolId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedDepartment != null) {
      return _DepartmentDetailPane(
        schoolId: widget.schoolId,
        department: _selectedDepartment!,
        onBack: () => setState(() => _selectedDepartment = null),
      );
    }

    final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Departments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              FilledButton.icon(onPressed: () => _openDepartmentDialog(), icon: const Icon(Icons.add_rounded), label: const Text('New Department')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select a department to manage its classes and subjects.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: departmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (departments) {
                if (departments.isEmpty) {
                  return const Center(child: Text('No departments yet. Create one to get started.'));
                }
                return ListView.separated(
                  itemCount: departments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = departments[i];
                    return Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _selectedDepartment = d),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.departmentName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    if (d.departmentType != null) Text(d.departmentType!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openDepartmentDialog(existing: d)),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
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
// DEPARTMENT DETAIL: breadcrumb + subjects (with coefficient) +
// classes within this department
// ============================================================

class _DepartmentDetailPane extends ConsumerStatefulWidget {
  final String schoolId;
  final DepartmentFull department;
  final VoidCallback onBack;
  const _DepartmentDetailPane({required this.schoolId, required this.department, required this.onBack});

  @override
  ConsumerState<_DepartmentDetailPane> createState() => _DepartmentDetailPaneState();
}

class _DepartmentDetailPaneState extends ConsumerState<_DepartmentDetailPane> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  ManagedClass? _selectedClass;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  Future<void> _openSubjectDialog() async {
    final allSubjectsAsync = ref.read(managedSubjectsProvider(widget.schoolId));
    final allSubjects = allSubjectsAsync.valueOrNull ?? await ref.read(managedSubjectsProvider(widget.schoolId).future);

    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final coefController = TextEditingController(text: '2');
    ManagedSubject? existingPick;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Subject to This Department'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ManagedSubject?>(
                  initialValue: existingPick,
                  decoration: const InputDecoration(labelText: 'Use an existing school subject (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Create a new subject —')),
                    ...allSubjects!.map((s) => DropdownMenuItem(value: s, child: Text('${s.subjectName} (${s.subjectCode})'))),
                  ],
                  onChanged: (v) => setDialogState(() => existingPick = v),
                ),
                if (existingPick == null) ...[
                  const SizedBox(height: 12),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Subject Name')),
                  const SizedBox(height: 12),
                  TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Subject Code (e.g. MATH)')),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: coefController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Coefficient in ${widget.department.departmentName}',
                    helperText: 'How heavily this subject counts toward the average in this department.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final coefficient = int.tryParse(coefController.text) ?? 1;
    final repo = ref.read(principalRepositoryProvider);

    if (existingPick != null) {
      await repo.attachExistingSubjectToDepartment(subjectId: existingPick!.id, departmentId: widget.department.id, coefficient: coefficient);
    } else {
      if (nameController.text.trim().isEmpty) return;
      await repo.createSubjectInDepartment(
        schoolId: widget.schoolId,
        departmentId: widget.department.id,
        subjectCode: codeController.text.trim().toUpperCase(),
        subjectName: nameController.text.trim(),
        coefficient: coefficient,
      );
    }
    ref.invalidate(subjectsForDepartmentProvider(widget.department.id));
    ref.invalidate(managedSubjectsProvider(widget.schoolId));
  }

  Future<void> _editCoefficient(SubjectWithCoefficient s) async {
    final controller = TextEditingController(text: s.coefficient.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Coefficient for ${s.subjectName}'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coefficient')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await ref.read(principalRepositoryProvider).updateSubjectCoefficient(
          subjectId: s.subjectId, departmentId: widget.department.id, coefficient: int.tryParse(controller.text) ?? s.coefficient,
        );
    ref.invalidate(subjectsForDepartmentProvider(widget.department.id));
  }

   Future<void> _openClassDialog({ManagedClass? existing}) async {
    final nameController = TextEditingController(text: existing?.className ?? '');
    final codeController = TextEditingController(text: existing?.classCode ?? '');
    final levelController = TextEditingController(text: existing?.levelOrder.toString() ?? '');
    final capacityController = TextEditingController(text: existing?.maxStudents.toString() ?? '50');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New Class in ${widget.department.departmentName}' : 'Edit Class'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Class Name (e.g. Form 1E)')),
              const SizedBox(height: 12),
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Class Code (e.g. F1E)')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: levelController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: capacityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity'))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;

    final repo = ref.read(principalRepositoryProvider);

    if (existing == null) {
      // NEW class - offer to configure its subjects immediately,
      // since an empty class with no subject offerings is a common,
      // easy-to-forget mistake. "Later" is always safe too - offerings
      // can be added or removed at any time from the Classes tab.
      final newClass = await repo.createClass(
        schoolId: widget.schoolId,
        className: nameController.text.trim(),
        classCode: codeController.text.trim().isEmpty ? null : codeController.text.trim().toUpperCase(),
        departmentId: widget.department.id,
        levelOrder: int.tryParse(levelController.text) ?? 0,
        maxStudents: int.tryParse(capacityController.text) ?? 50,
      );
      ref.invalidate(managedClassesProvider(widget.schoolId));

      if (!mounted) return;
      final configureNow = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${newClass.className} created'),
          content: const Text(
            'Would you like to configure which subjects this class offers now? You can always do this later, and subjects can be added or removed at any time.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Configure Now')),
          ],
        ),
      );
      if (configureNow == true && mounted) {
        setState(() {
          _tabs.animateTo(1); // jump to the Classes tab
          _selectedClass = newClass;
        });
      }
    } else {
      await repo.updateClass(
        classId: existing.id,
        className: nameController.text.trim(),
        classCode: codeController.text.trim().isEmpty ? null : codeController.text.trim().toUpperCase(),
        departmentId: widget.department.id,
        levelOrder: int.tryParse(levelController.text) ?? 0,
        maxStudents: int.tryParse(capacityController.text) ?? 50,
      );
      ref.invalidate(managedClassesProvider(widget.schoolId));
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack),
              Text('Departments', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              const Icon(Icons.chevron_right_rounded, size: 16),
              Text(widget.department.departmentName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [Tab(text: 'Subjects & Coefficients'), Tab(text: 'Classes')],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // --- SUBJECTS TAB ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(onPressed: _openSubjectDialog, icon: const Icon(Icons.add_rounded), label: const Text('Add Subject')),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final subjectsAsync = ref.watch(subjectsForDepartmentProvider(widget.department.id));
                          return subjectsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Text('$e'),
                            data: (subjects) {
                              if (subjects.isEmpty) return const Center(child: Text('No subjects in this department yet.'));
                              return ListView.separated(
                                itemCount: subjects.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final s = subjects[i];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('${s.subjectName} (${s.subjectCode})', style: const TextStyle(fontWeight: FontWeight.w600))),
                                        Chip(label: Text('Coefficient ${s.coefficient}')),
                                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _editCoefficient(s)),
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

                // --- CLASSES TAB ---
                _selectedClass != null
                    ? _ClassSubjectOfferingsPane(
                        schoolId: widget.schoolId,
                        classInfo: _selectedClass!,
                        onBack: () => setState(() => _selectedClass = null),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(onPressed: () => _openClassDialog(), icon: const Icon(Icons.add_rounded), label: const Text('New Class')),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
                                return classesAsync.when(
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (e, _) => Text('$e'),
                                  data: (classes) {
                                    final filtered = classes.where((c) => c.departmentId == widget.department.id).toList();
                                    if (filtered.isEmpty) return const Center(child: Text('No classes in this department yet.'));
                                    return ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, i) {
                                        final c = filtered[i];
                                        return Material(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => setState(() => _selectedClass = c),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Row(
                                                children: [
                                                  Expanded(child: Text(c.className, style: const TextStyle(fontWeight: FontWeight.w700))),
                                                  Text('Max ${c.maxStudents}', style: theme.textTheme.bodySmall),
                                                  const SizedBox(width: 8),
                                                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _openClassDialog(existing: c)),
                                                  const Icon(Icons.chevron_right_rounded),
                                                ],
                                              ),
                                            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CLASS -> which subjects it offers, compulsory toggle
// ============================================================

class _ClassSubjectOfferingsPane extends ConsumerWidget {
  final String schoolId;
  final ManagedClass classInfo;
  final VoidCallback onBack;
  const _ClassSubjectOfferingsPane({required this.schoolId, required this.classInfo, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offeringsAsync = ref.watch(subjectOfferingsForClassProvider((schoolId: schoolId, classId: classInfo.id)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
            Text(classInfo.className, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        Text(
          'Turn a subject on to offer it in this class. Mark it compulsory to lock it in during parent enrollment.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: offeringsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (offerings) => ListView(
              children: offerings
                  .map((o) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(child: Text(o.subjectName, style: const TextStyle(fontWeight: FontWeight.w600))),
                            if (o.isOffered) ...[
                              const Text('Compulsory', style: TextStyle(fontSize: 12)),
                              Switch(
                                value: o.isCompulsory,
                                onChanged: (v) async {
                                  await ref.read(principalRepositoryProvider).setSubjectOffering(
                                        classId: classInfo.id, subjectId: o.subjectId, isOffered: true, isCompulsory: v,
                                      );
                                  ref.invalidate(subjectOfferingsForClassProvider((schoolId: schoolId, classId: classInfo.id)));
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(o.isOffered ? 'Offered' : 'Not offered', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                            Switch(
                              value: o.isOffered,
                              onChanged: (v) async {
                                await ref.read(principalRepositoryProvider).setSubjectOffering(
                                      classId: classInfo.id, subjectId: o.subjectId, isOffered: v, isCompulsory: false,
                                    );
                                ref.invalidate(subjectOfferingsForClassProvider((schoolId: schoolId, classId: classInfo.id)));
                              },
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SUBJECT BROWSE / REVIEW - grouped by department, expandable
// ============================================================

class SubjectBrowsePage extends ConsumerWidget {
  final String schoolId;
  const SubjectBrowsePage({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final yearIdAsync = ref.watch(principalCurrentAcademicYearIdProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Subjects', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Grouped by department. Expand any subject to see which classes offer it and which teachers are assigned.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          Expanded(
            child: yearIdAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (yearId) {
                if (yearId == null) return const Text('No current academic year set.');
                final browseAsync = ref.watch(subjectBrowseListProvider((schoolId: schoolId, academicYearId: yearId)));
                return browseAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (items) {
                    final grouped = <String, List<SubjectBrowseItem>>{};
                    for (final item in items) {
                      grouped.putIfAbsent(item.departmentName, () => []).add(item);
                    }
                    return ListView(
                      children: grouped.entries.map((entry) {
                        return ExpansionTile(
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                          children: entry.value.map((s) => ExpansionTile(
                            title: Text(s.subjectName),
                            subtitle: Text('Coefficient ${s.coefficient}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Offered in: ${s.classesOffering.isEmpty ? "No classes yet" : s.classesOffering.join(", ")}'),
                                    const SizedBox(height: 6),
                                    Text('Taught by: ${s.teachersAssigned.isEmpty ? "No teacher assigned yet" : s.teachersAssigned.join(", ")}'),
                                  ],
                                ),
                              ),
                            ],
                          )).toList(),
                        );
                      }).toList(),
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
// FEES (unchanged from before - kept working)
// ============================================================

class ManageFeesEntryPage extends ConsumerStatefulWidget {
  final String schoolId;
  const ManageFeesEntryPage({super.key, required this.schoolId});

  @override
  ConsumerState<ManageFeesEntryPage> createState() => _ManageFeesEntryPageState();
}

class _ManageFeesEntryPageState extends ConsumerState<ManageFeesEntryPage> {
  ManagedClass? _selectedClass;
  final _regFeeController = TextEditingController();
  List<ManagedInstallment> _installments = [];
  bool _loaded = false;
  bool _saving = false;
  String? _feeId;

  @override
  void dispose() {
    _regFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadFor(String classId, String academicYearId) async {
    final config = await ref.read(principalRepositoryProvider).getFeeConfig(classId: classId, academicYearId: academicYearId);
    setState(() {
      _regFeeController.text = config.registrationFee == 0 ? '' : config.registrationFee.toStringAsFixed(0);
      _installments = config.installments;
      _feeId = config.feeId;
      _loaded = true;
    });
  }

  void _addInstallmentRow() {
    setState(() => _installments.add(ManagedInstallment(name: 'Installment ${_installments.length + 1}', amount: 0, displayOrder: _installments.length + 1)));
  }

  Future<void> _save(String academicYearId) async {
    setState(() => _saving = true);
    try {
      final config = ManagedFeeConfig(feeId: _feeId, registrationFee: double.tryParse(_regFeeController.text) ?? 0, installments: _installments);
      await ref.read(principalRepositoryProvider).saveFeeConfig(schoolId: widget.schoolId, classId: _selectedClass!.id, academicYearId: academicYearId, config: config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee configuration saved.')));
        _loaded = false;
        await _loadFor(_selectedClass!.id, academicYearId);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
    final yearIdAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('School Fees', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          yearIdAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (yearId) {
              if (yearId == null) return const Text('No current academic year is set for this school yet.');
              return Expanded(
                child: classesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (classes) => ListView(
                    children: [
                      DropdownButtonFormField<ManagedClass>(
                        initialValue: _selectedClass,
                        decoration: const InputDecoration(labelText: 'Select a class', border: OutlineInputBorder()),
                        items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
                        onChanged: (v) {
                          setState(() { _selectedClass = v; _loaded = false; });
                          if (v != null) _loadFor(v.id, yearId);
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_selectedClass != null && _loaded) ...[
                        TextFormField(controller: _regFeeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Registration Fee (FCFA)', border: OutlineInputBorder())),
                        const SizedBox(height: 20),
                        Row(children: [
                          Text('Installments', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton.icon(onPressed: _addInstallmentRow, icon: const Icon(Icons.add_rounded), label: const Text('Add Installment')),
                        ]),
                        ..._installments.asMap().entries.map((entry) {
                          final i = entry.key;
                          final inst = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              Expanded(flex: 3, child: TextFormField(initialValue: inst.name, decoration: const InputDecoration(labelText: 'Name'), onChanged: (v) => inst.name = v)),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: TextFormField(initialValue: inst.amount == 0 ? '' : inst.amount.toStringAsFixed(0), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'), onChanged: (v) => inst.amount = double.tryParse(v) ?? 0)),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(context: context, initialDate: inst.dueDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
                                    if (picked != null) setState(() => inst.dueDate = picked);
                                  },
                                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Due date'), child: Text(inst.dueDate == null ? 'Pick date' : '${inst.dueDate!.day}/${inst.dueDate!.month}/${inst.dueDate!.year}')),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => setState(() => _installments.removeAt(i))),
                            ]),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text('Total: ${_installments.fold(0.0, (s, i) => s + i.amount).toStringAsFixed(0)} FCFA', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : () => _save(yearId),
                          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Fee Configuration'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
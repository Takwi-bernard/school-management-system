import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// MANAGE CLASSES
// ============================================================

class ManageClassesPage extends ConsumerStatefulWidget {
  final String schoolId;
  const ManageClassesPage({super.key, required this.schoolId});

  @override
  ConsumerState<ManageClassesPage> createState() => _ManageClassesPageState();
}

class _ManageClassesPageState extends ConsumerState<ManageClassesPage> {
  bool _showInactive = false;
  late Future<List<ManagedClass>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = ref.read(principalRepositoryProvider).getClasses(widget.schoolId, includeInactive: _showInactive);
  }

  Future<void> _openClassDialog({ManagedClass? existing}) async {
    final departments = await ref.read(departmentsProvider(widget.schoolId).future);
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ClassFormDialog(schoolId: widget.schoolId, departments: departments, existing: existing),
    );
    if (saved == true) setState(_refresh);
  }

  Future<void> _toggleActive(ManagedClass c) async {
    final action = c.isActive ? (AppStrings(ref.read(activeLocaleProvider)).isFrench ? 'désactiver' : 'deactivate') : 'activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${c.isActive ? "Deactivate" : "Activate"} ${c.className}?'),
        content: Text(c.isActive
            ? 'Deactivated classes are hidden from new enrollment, but existing students are unaffected.'
            : 'This class will become available for new enrollment again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action[0].toUpperCase() + action.substring(1))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).setClassActive(c.id, !c.isActive);
    setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(strings.isFrench ? 'Gérer les classes' : 'Manage Classes',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
              FilledButton.icon(
                onPressed: () => _openClassDialog(),
                icon: const Icon(Icons.add_rounded),
                label: Text(strings.isFrench ? 'Nouvelle classe' : 'New Class'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.isFrench
                ? 'Ces classes déterminent ce qu\'un parent peut choisir lors de l\'inscription.'
                : 'These classes determine what a parent can select during enrollment.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(value: _showInactive, onChanged: (v) => setState(() { _showInactive = v; _refresh(); })),
              Text(strings.isFrench ? 'Afficher les classes désactivées' : 'Show deactivated classes'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<ManagedClass>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final classes = snapshot.data!;
                if (classes.isEmpty) {
                  return Center(child: Text(strings.isFrench ? 'Aucune classe pour le moment.' : 'No classes yet.'));
                }
                return ListView.separated(
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = classes[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: c.isActive ? null : Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(c.className, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  if (!c.isActive) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                      child: Text('Inactive', style: TextStyle(color: theme.colorScheme.error, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ]),
                                Text('${c.departmentName ?? "-"} · Code: ${c.classCode ?? "GEN"} · Max ${c.maxStudents} students',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openClassDialog(existing: c)),
                          IconButton(
                            icon: Icon(c.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            tooltip: c.isActive ? 'Deactivate' : 'Activate',
                            onPressed: () => _toggleActive(c),
                          ),
                        ],
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

class _ClassFormDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final List<DepartmentOption> departments;
  final ManagedClass? existing;
  const _ClassFormDialog({required this.schoolId, required this.departments, this.existing});

  @override
  ConsumerState<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends ConsumerState<_ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _level;
  late final TextEditingController _maxStudents;
  String? _departmentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.className ?? '');
    _code = TextEditingController(text: e?.classCode ?? '');
    _level = TextEditingController(text: e?.levelOrder.toString() ?? '');
    _maxStudents = TextEditingController(text: e?.maxStudents.toString() ?? '50');
    _departmentId = e?.departmentId ?? (widget.departments.isNotEmpty ? widget.departments.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _level.dispose();
    _maxStudents.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _departmentId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(principalRepositoryProvider);
      if (widget.existing == null) {
        await repo.createClass(
          schoolId: widget.schoolId,
          className: _name.text.trim(),
          classCode: _code.text.trim().isEmpty ? null : _code.text.trim().toUpperCase(),
          departmentId: _departmentId!,
          levelOrder: int.tryParse(_level.text) ?? 0,
          maxStudents: int.tryParse(_maxStudents.text) ?? 50,
        );
      } else {
        await repo.updateClass(
          classId: widget.existing!.id,
          className: _name.text.trim(),
          classCode: _code.text.trim().isEmpty ? null : _code.text.trim().toUpperCase(),
          departmentId: _departmentId!,
          levelOrder: int.tryParse(_level.text) ?? 0,
          maxStudents: int.tryParse(_maxStudents.text) ?? 50,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Class' : 'Edit Class'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Class Name (e.g. Form 1E)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Class Code (e.g. F1E) - used in student IDs', hintText: 'Optional - defaults to GEN'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _departmentId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: widget.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.departmentName))).toList(),
                onChanged: (v) => setState(() => _departmentId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _level,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Order (1, 2, 3...)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxStudents,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Students'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================
// MANAGE SUBJECTS (school-wide list + per-class offering toggles)
// ============================================================

class ManageSubjectsPage extends ConsumerStatefulWidget {
  final String schoolId;
  const ManageSubjectsPage({super.key, required this.schoolId});

  @override
  ConsumerState<ManageSubjectsPage> createState() => _ManageSubjectsPageState();
}

class _ManageSubjectsPageState extends ConsumerState<ManageSubjectsPage> {
  ManagedClass? _selectedClass;

  Future<void> _addSubject() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Subject Name')),
            const SizedBox(height: 12),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Subject Code (e.g. MATH)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    await ref.read(principalRepositoryProvider).createSubject(
          schoolId: widget.schoolId,
          subjectCode: codeController.text.trim().toUpperCase(),
          subjectName: nameController.text.trim(),
        );
    ref.invalidate(managedSubjectsProvider(widget.schoolId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
    final subjectsAsync = ref.watch(managedSubjectsProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Manage Subjects', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              FilledButton.icon(onPressed: _addSubject, icon: const Icon(Icons.add_rounded), label: const Text('New Subject')),
            ],
          ),
          const SizedBox(height: 6),
          Text('All subjects offered anywhere at this school:', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 10),
          subjectsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (subjects) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((s) => Chip(label: Text('${s.subjectName} (${s.subjectCode})'))).toList(),
            ),
          ),
          const Divider(height: 32),
          Text('Configure which subjects a class offers:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Toggle a subject on to offer it. Mark it compulsory to lock it in during enrollment - a parent will never be able to unselect a compulsory subject.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          classesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (classes) => DropdownButtonFormField<ManagedClass>(
              initialValue: _selectedClass,
              decoration: const InputDecoration(labelText: 'Select a class', border: OutlineInputBorder()),
              items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
              onChanged: (v) => setState(() => _selectedClass = v),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedClass != null)
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final offeringsAsync = ref.watch(
                    subjectOfferingsForClassProvider((schoolId: widget.schoolId, classId: _selectedClass!.id)),
                  );
                  return offeringsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (offerings) => ListView(
                      children: offerings
                          .map((o) => _OfferingRow(
                                offering: o,
                                classId: _selectedClass!.id,
                                onChanged: () => ref.invalidate(
                                  subjectOfferingsForClassProvider((schoolId: widget.schoolId, classId: _selectedClass!.id)),
                                ),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferingRow extends ConsumerWidget {
  final SubjectOfferingRow offering;
  final String classId;
  final VoidCallback onChanged;
  const _OfferingRow({required this.offering, required this.classId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(offering.subjectName, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (offering.isOffered) ...[
            const Text('Compulsory', style: TextStyle(fontSize: 12)),
            Switch(
              value: offering.isCompulsory,
              onChanged: (v) async {
                await ref.read(principalRepositoryProvider).setSubjectOffering(
                      classId: classId, subjectId: offering.subjectId, isOffered: true, isCompulsory: v,
                    );
                onChanged();
              },
            ),
            const SizedBox(width: 12),
          ],
          Switch(
            value: offering.isOffered,
            activeTrackColor: theme.colorScheme.primary,
            onChanged: (v) async {
              await ref.read(principalRepositoryProvider).setSubjectOffering(
                    classId: classId, subjectId: offering.subjectId, isOffered: v, isCompulsory: false,
                  );
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCHOOL FEES ENTRY (registration fee + installments per class)
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
    setState(() => _installments.add(ManagedInstallment(
          name: 'Installment ${_installments.length + 1}',
          amount: 0,
          displayOrder: _installments.length + 1,
        )));
  }

  Future<void> _save(String academicYearId) async {
    setState(() => _saving = true);
    try {
      final config = ManagedFeeConfig(
        feeId: _feeId,
        registrationFee: double.tryParse(_regFeeController.text) ?? 0,
        installments: _installments,
      );
      await ref.read(principalRepositoryProvider).saveFeeConfig(
            schoolId: widget.schoolId,
            classId: _selectedClass!.id,
            academicYearId: academicYearId,
            config: config,
          );
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
          const SizedBox(height: 6),
          Text(
            'Set a registration fee and installment plan per class. Parents will see exactly what you configure here - the number of installments is entirely up to you.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          yearIdAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (yearId) {
              if (yearId == null) {
                return const Text('No current academic year is set for this school yet.');
              }
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
                        TextFormField(
                          controller: _regFeeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Registration Fee (FCFA)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text('Installments', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            TextButton.icon(onPressed: _addInstallmentRow, icon: const Icon(Icons.add_rounded), label: const Text('Add Installment')),
                          ],
                        ),
                        ..._installments.asMap().entries.map((entry) {
                          final i = entry.key;
                          final inst = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: inst.name,
                                    decoration: const InputDecoration(labelText: 'Name'),
                                    onChanged: (v) => inst.name = v,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: inst.amount == 0 ? '' : inst.amount.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Amount'),
                                    onChanged: (v) => inst.amount = double.tryParse(v) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: inst.dueDate ?? DateTime.now(),
                                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                        lastDate: DateTime.now().add(const Duration(days: 730)),
                                      );
                                      if (picked != null) setState(() => inst.dueDate = picked);
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Due date'),
                                      child: Text(inst.dueDate == null ? 'Pick date' : '${inst.dueDate!.day}/${inst.dueDate!.month}/${inst.dueDate!.year}'),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => setState(() => _installments.removeAt(i)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text(
                          'Total school fee (sum of installments): ${_installments.fold(0.0, (s, i) => s + i.amount).toStringAsFixed(0)} FCFA',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : () => _save(yearId),
                          child: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Fee Configuration'),
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
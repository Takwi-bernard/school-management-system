import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// SLOT-FIRST TEACHING SLOT CREATOR
// Department -> Class -> Subject -> periods/day/time -> Select Teacher
// ============================================================

class CreateTeachingSlotPage extends ConsumerStatefulWidget {
  final String schoolId;
  const CreateTeachingSlotPage({super.key, required this.schoolId});

  @override
  ConsumerState<CreateTeachingSlotPage> createState() => _CreateTeachingSlotPageState();
}

class _CreateTeachingSlotPageState extends ConsumerState<CreateTeachingSlotPage> {
  DepartmentFull? _department;
  ManagedClass? _class;
  ManagedSubject? _subject;
  final _periodsController = TextEditingController(text: '3');
  int? _preferredDay;
  TimeOfDay? _start;
  TimeOfDay? _end;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _periodsController.dispose();
    super.dispose();
  }

  String? _fmtTime(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  bool get _slotReady => _department != null && _class != null && _subject != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departmentsAsync = ref.watch(departmentsFullProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create a Teaching Slot', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Define the department, class, and subject first, then choose who teaches it.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                departmentsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (departments) => DropdownButtonFormField<DepartmentFull>(
                    initialValue: _department,
                    decoration: const InputDecoration(labelText: '1. Department', border: OutlineInputBorder()),
                    items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d.departmentName))).toList(),
                    onChanged: (v) => setState(() { _department = v; _class = null; _subject = null; }),
                  ),
                ),
                const SizedBox(height: 14),
                if (_department != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
                      return classesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (classes) {
                          final filtered = classes.where((c) => c.departmentId == _department!.id).toList();
                          return DropdownButtonFormField<ManagedClass>(
                            initialValue: _class,
                            decoration: const InputDecoration(labelText: '2. Class', border: OutlineInputBorder()),
                            items: filtered.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
                            onChanged: (v) => setState(() => _class = v),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 14),
                if (_department != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(subjectsForDepartmentProvider(_department!.id));
                      return subjectsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (subjects) => DropdownButtonFormField<ManagedSubject>(
                          initialValue: null,
                          decoration: const InputDecoration(labelText: '3. Subject', border: OutlineInputBorder()),
                          items: subjects.map((s) => DropdownMenuItem(value: ManagedSubject(id: s.subjectId, subjectCode: s.subjectCode, subjectName: s.subjectName), child: Text(s.subjectName))).toList(),
                          onChanged: (v) => setState(() => _subject = v),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                if (_slotReady) ...[
                  TextFormField(controller: _periodsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Periods per week', border: OutlineInputBorder())),
                  const SizedBox(height: 14),
                  Text('Preferred teaching time (optional)', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: List.generate(7, (i) => ChoiceChip(label: Text(_weekdays[i]), selected: _preferredDay == i + 1, onSelected: (sel) => setState(() => _preferredDay = sel ? i + 1 : null)))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () async { final p = await showTimePicker(context: context, initialTime: _start ?? const TimeOfDay(hour: 8, minute: 0)); if (p != null) setState(() => _start = p); }, child: Text(_start == null ? 'Start time' : _start!.format(context)))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: () async { final p = await showTimePicker(context: context, initialTime: _end ?? const TimeOfDay(hour: 9, minute: 0)); if (p != null) setState(() => _end = p); }, child: Text(_end == null ? 'End time' : _end!.format(context)))),
                  ]),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => SelectTeacherDialog(
                        schoolId: widget.schoolId,
                        classId: _class!.id,
                        className: _class!.className,
                        subjectId: _subject!.id,
                        subjectName: _subject!.subjectName,
                        periodsPerWeek: int.tryParse(_periodsController.text) ?? 1,
                        preferredDay: _preferredDay,
                        preferredStartTime: _fmtTime(_start),
                        preferredEndTime: _fmtTime(_end),
                      ),
                    ),
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('Select Teacher for This Slot'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SELECT TEACHER - full profile list, approve pending ones inline
// ============================================================

class SelectTeacherDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final int periodsPerWeek;
  final int? preferredDay;
  final String? preferredStartTime;
  final String? preferredEndTime;

  const SelectTeacherDialog({
    super.key,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.periodsPerWeek,
    this.preferredDay,
    this.preferredStartTime,
    this.preferredEndTime,
  });

  @override
  ConsumerState<SelectTeacherDialog> createState() => _SelectTeacherDialogState();
}

class _SelectTeacherDialogState extends ConsumerState<SelectTeacherDialog> {
  AllTeacherProfile? _picked;
  bool _saving = false;
  String? _academicYearId;

  @override
  void initState() {
    super.initState();
    ref.read(principalRepositoryProvider).getCurrentAcademicYearId(widget.schoolId).then((id) {
      if (mounted) setState(() => _academicYearId = id);
    });
  }

  Future<void> _confirm(AllTeacherProfile teacher) async {
    final principal = await ref.read(principalProfileProvider.future);
    if (principal == null || _academicYearId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(teacher.isApproved ? 'Assign ${teacher.fullName}?' : 'Approve & Assign ${teacher.fullName}?'),
        content: Text(teacher.isApproved
            ? '${teacher.fullName} will be assigned to teach ${widget.subjectName} in ${widget.className}.'
            : '${teacher.fullName} is not yet approved at this school. Selecting them for this slot will approve their account AND assign them to teach ${widget.subjectName} in ${widget.className}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(teacher.isApproved ? 'Assign' : 'Approve & Assign')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(principalRepositoryProvider).approveAndAssign(
            schoolId: widget.schoolId,
            academicYearId: _academicYearId!,
            teacherId: teacher.teacherId,
            wasAlreadyApproved: teacher.isApproved,
            principalId: principal.principalId,
            classId: widget.classId,
            subjectId: widget.subjectId,
            periodsPerWeek: widget.periodsPerWeek,
            preferredDay: widget.preferredDay,
            preferredStartTime: widget.preferredStartTime,
            preferredEndTime: widget.preferredEndTime,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${teacher.fullName} assigned to ${widget.subjectName} - ${widget.className}.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject(AllTeacherProfile teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject ${teacher.fullName}?'),
        content: const Text('This account will not gain teacher access at this school.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true) return;
    final principal = await ref.read(principalProfileProvider.future);
    if (principal == null) return;
    await ref.read(principalRepositoryProvider).rejectTeacher(teacher.teacherId, principal.principalId);
    ref.invalidate(allTeachersProvider(widget.schoolId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teachersAsync = ref.watch(allTeachersProvider(widget.schoolId));

    return AlertDialog(
      title: Text('Select a teacher for ${widget.subjectName} - ${widget.className}'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: teachersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (teachers) {
            if (teachers.isEmpty) return const Center(child: Text('No teachers have signed up at this school yet.'));
            return ListView.separated(
              itemCount: teachers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = teachers[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      CircleAvatar(child: Text(t.fullName.isNotEmpty ? t.fullName[0] : '?')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              if (!t.isApproved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                  child: const Text('Pending', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
                                ),
                            ]),
                            Text('${t.email ?? ''} · ${t.phone ?? ''}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                      if (!t.isApproved)
                        IconButton(icon: const Icon(Icons.close_rounded), color: theme.colorScheme.error, tooltip: 'Reject', onPressed: () => _reject(t)),
                      FilledButton(
                        onPressed: _saving ? null : () => _confirm(t),
                        child: Text(t.isApproved ? 'Assign' : 'Approve & Assign'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
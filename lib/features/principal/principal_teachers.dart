import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// PENDING TEACHER APPROVALS
// ============================================================

class PendingTeachersPage extends ConsumerWidget {
  final String schoolId;
  const PendingTeachersPage({super.key, required this.schoolId});

  Future<void> _handle(BuildContext context, WidgetRef ref, PendingTeacher teacher, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approve ? 'Approve ${teacher.fullName}?' : 'Reject ${teacher.fullName}?'),
        content: Text(approve
            ? 'They will gain access to their teacher dashboard. You\'ll be asked to assign subjects and classes next.'
            : 'This account will not be granted teacher access at this school.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: approve ? null : FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final principal = await ref.read(principalProfileProvider.future);
    if (principal == null) return;

    final repo = ref.read(principalRepositoryProvider);
    if (approve) {
      await repo.approveTeacher(teacher.teacherId, principal.principalId);
    } else {
      await repo.rejectTeacher(teacher.teacherId, principal.principalId);
    }
    ref.invalidate(pendingTeachersProvider(schoolId));

    if (approve && context.mounted) {
      // Approval and assignment happen together, as one flow - a
      // just-approved teacher immediately gets assigned subjects.
      await showDialog(
        context: context,
        builder: (_) => AssignTeacherDialog(schoolId: schoolId, teacherId: teacher.teacherId, teacherName: teacher.fullName),
      );
      ref.invalidate(approvedTeachersProvider(schoolId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(pendingTeachersProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Teacher Approvals', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'A teacher cannot access their dashboard or be assigned any classes until you approve them here.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (teachers) {
                if (teachers.isEmpty) {
                  return Center(
                    child: Text('No pending teacher applications right now.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                  );
                }
                return ListView.separated(
                  itemCount: teachers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = teachers[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          CircleAvatar(child: Text(t.fullName.isNotEmpty ? t.fullName[0] : '?')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text('${t.email ?? ''} · ${t.phone ?? ''}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                          OutlinedButton(onPressed: () => _handle(context, ref, t, false), child: const Text('Reject')),
                          const SizedBox(width: 8),
                          FilledButton(onPressed: () => _handle(context, ref, t, true), child: const Text('Approve')),
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

// ============================================================
// APPROVED TEACHERS + THEIR ASSIGNMENTS
// ============================================================

class ApprovedTeachersPage extends ConsumerWidget {
  final String schoolId;
  const ApprovedTeachersPage({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final teachersAsync = ref.watch(approvedTeachersProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teachers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: teachersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (teachers) {
                if (teachers.isEmpty) return const Center(child: Text('No approved teachers yet.'));
                return ListView.separated(
                  itemCount: teachers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = teachers[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          CircleAvatar(child: Text(t.fullName.isNotEmpty ? t.fullName[0] : '?')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text('${t.assignmentCount} assignment${t.assignmentCount == 1 ? '' : 's'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => AssignTeacherDialog(schoolId: schoolId, teacherId: t.teacherId, teacherName: t.fullName),
                            ).then((_) => ref.invalidate(approvedTeachersProvider(schoolId))),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Manage Assignments'),
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

// ============================================================
// ASSIGN TEACHER TO CLASS + SUBJECT (+ optional period preference)
// ============================================================

class AssignTeacherDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String teacherId;
  final String teacherName;
  const AssignTeacherDialog({super.key, required this.schoolId, required this.teacherId, required this.teacherName});

  @override
  ConsumerState<AssignTeacherDialog> createState() => _AssignTeacherDialogState();
}

class _AssignTeacherDialogState extends ConsumerState<AssignTeacherDialog> {
  String? _classId;
  String? _subjectId;
  final _periodsController = TextEditingController(text: '3');
  int? _preferredDay;
  TimeOfDay? _preferredStart;
  TimeOfDay? _preferredEnd;
  bool _saving = false;
  String? _academicYearId;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    ref.read(principalRepositoryProvider).getCurrentAcademicYearId(widget.schoolId).then((id) {
      if (mounted) setState(() => _academicYearId = id);
    });
  }

  @override
  void dispose() {
    _periodsController.dispose();
    super.dispose();
  }

  String? _fmtTime(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _save() async {
    if (_classId == null || _subjectId == null || _academicYearId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(principalRepositoryProvider).createAssignment(
            schoolId: widget.schoolId,
            academicYearId: _academicYearId!,
            teacherId: widget.teacherId,
            classId: _classId!,
            subjectId: _subjectId!,
            periodsPerWeek: int.tryParse(_periodsController.text) ?? 1,
            preferredDay: _preferredDay,
            preferredStartTime: _fmtTime(_preferredStart),
            preferredEndTime: _fmtTime(_preferredEnd),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(managedClassesProvider(widget.schoolId));
    final subjectsAsync = ref.watch(managedSubjectsProvider(widget.schoolId));
    final assignmentsAsync = _academicYearId == null
        ? null
        : ref.watch(teacherAssignmentsProvider((teacherId: widget.teacherId, academicYearId: _academicYearId!)));

    return AlertDialog(
      title: Text('Assign ${widget.teacherName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (assignmentsAsync != null)
                assignmentsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (existing) {
                    if (existing.isEmpty) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current assignments:', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          ...existing.map((a) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${a.subjectName} - ${a.className} (${a.periodsPerWeek}/wk)')),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Remove this assignment?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await ref.read(principalRepositoryProvider).deleteAssignment(a.id);
                                          ref.invalidate(teacherAssignmentsProvider((teacherId: widget.teacherId, academicYearId: _academicYearId!)));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              const Text('Add a new assignment:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              classesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (classes) => DropdownButtonFormField<String>(
                  initialValue: _classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
                  onChanged: (v) => setState(() => _classId = v),
                ),
              ),
              const SizedBox(height: 12),
              subjectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (subjects) => DropdownButtonFormField<String>(
                  initialValue: _subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.subjectName))).toList(),
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Periods per week'),
              ),
              const SizedBox(height: 16),
              Text('Preferred teaching time (optional)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                'Used later to help generate the school timetable automatically.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) => ChoiceChip(
                      label: Text(_weekdays[i]),
                      selected: _preferredDay == i + 1,
                      onSelected: (sel) => setState(() => _preferredDay = sel ? i + 1 : null),
                    )),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _preferredStart ?? const TimeOfDay(hour: 8, minute: 0));
                        if (picked != null) setState(() => _preferredStart = picked);
                      },
                      child: Text(_preferredStart == null ? 'Start time' : _preferredStart!.format(context)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _preferredEnd ?? const TimeOfDay(hour: 9, minute: 0));
                        if (picked != null) setState(() => _preferredEnd = picked);
                      },
                      child: Text(_preferredEnd == null ? 'End time' : _preferredEnd!.format(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        FilledButton(
          onPressed: _saving || _classId == null || _subjectId == null ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add Assignment'),
        ),
      ],
    );
  }
}
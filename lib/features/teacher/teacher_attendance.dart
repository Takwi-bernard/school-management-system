import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';
class TeacherAttendancePage extends ConsumerStatefulWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherAttendancePage({super.key, required this.profile, required this.assignment});

  @override
  ConsumerState<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends ConsumerState<TeacherAttendancePage> {
  DateTime _date = DateTime.now();
  final Map<String, String> _status = {}; // studentId -> present/absent/late/excused
  bool _saving = false;
  bool _loadedForDate = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _status.clear();
        _loadedForDate = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final entries = _status.entries
          .map((e) => AttendanceEntry(studentId: e.key, date: _date, status: e.value))
          .toList();

      await ref.read(teacherRepositoryProvider).saveAttendance(
            profile: widget.profile,
            classId: widget.assignment.classId,
            subjectId: widget.assignment.subjectId,
            academicYearId: widget.assignment.academicYearId,
            entries: entries,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save attendance. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rosterAsync = ref.watch(
      rosterProvider((classId: widget.assignment.classId, academicYearId: widget.assignment.academicYearId)),
    );
    final existingAsync = ref.watch(attendanceForDateProvider((
      classId: widget.assignment.classId,
      subjectId: widget.assignment.subjectId,
      date: _date,
    )));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.assignment.className} - Attendance')),
      body: rosterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (students) {
          return existingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (existing) {
              if (!_loadedForDate) {
                for (final s in students) {
                  final match = existing.where((a) => a.studentId == s.studentId);
                  _status[s.studentId] = match.isNotEmpty ? match.first.status : 'present';
                }
                _loadedForDate = true;
              }

              return Padding(
                padding: EdgeInsets.all(Responsive.pagePadding(context)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('Date: ${_fmt(_date)}',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: const Text('Change Date'),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.separated(
                            itemCount: students.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final s = students[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(s.fullName,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  ),
                                  DropdownButton<String>(
                                    value: _status[s.studentId] ?? 'present',
                                    items: const [
                                      DropdownMenuItem(value: 'present', child: Text('Present')),
                                      DropdownMenuItem(value: 'absent', child: Text('Absent')),
                                      DropdownMenuItem(value: 'late', child: Text('Late')),
                                      DropdownMenuItem(value: 'excused', child: Text('Excused')),
                                    ],
                                    onChanged: (v) => setState(() => _status[s.studentId] = v ?? 'present'),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save Attendance'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

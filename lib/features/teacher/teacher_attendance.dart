import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
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
  final Map<String, String> _status = {};
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

  Future<void> _save(AppStrings strings) async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.attendanceSavedMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.saveAttendanceError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final rosterAsync = ref.watch(
      rosterProvider((classId: widget.assignment.classId, academicYearId: widget.assignment.academicYearId)),
    );
    final existingAsync = ref.watch(attendanceForDateProvider((
      classId: widget.assignment.classId,
      subjectId: widget.assignment.subjectId,
      date: _date,
    )));

    final statusLabels = {
      'present': strings.statusPresent,
      'absent': strings.statusAbsent,
      'late': strings.statusLate,
      'excused': strings.statusExcused,
    };

    return Scaffold(
      appBar: AppBar(title: Text('${widget.assignment.className} - ${strings.attendanceLabel}')),
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
                        RevealOnScroll(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Text('${strings.dateLabel}: ${_fmt(_date)}',
                                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                              HoverLift(
                                liftPixels: 2,
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(strings.changeDate, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.separated(
                            itemCount: students.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final s = students[i];
                              return RevealOnScroll(
                                delay: Duration(milliseconds: (i * 25).clamp(0, 250)),
                                child: Container(
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
                                      underline: const SizedBox.shrink(),
                                      items: statusLabels.entries
                                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                          .toList(),
                                      onChanged: (v) => setState(() => _status[s.studentId] = v ?? 'present'),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : () => _save(strings),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(strings.saveAttendance),
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

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_navigation.dart';
import 'teacher_providers.dart';
import 'teacher_ui.dart';

/// Reached via pushTeacherContent, not Navigator.push - stays inside
/// TeacherShell so the sidebar/drawer is always still reachable.
class TeacherAttendancePage extends ConsumerStatefulWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherAttendancePage({super.key, required this.profile, required this.assignment});

  @override
  ConsumerState<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends ConsumerState<TeacherAttendancePage> {
  // Date only (no time of day) so the provider key is stable and the
  // cache/invalidate below actually match.
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _date = _today();
  final Map<String, String> _status = {};
  bool _saving = false;
  bool _loadedForDate = false;

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Attendance cannot be recorded for the future.
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
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

      // Re-read from the database next time this date is opened.
      ref.invalidate(attendanceForDateProvider((
        classId: widget.assignment.classId,
        subjectId: widget.assignment.subjectId,
        date: _date,
      )));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.attendanceSavedMessage)));
      }
    } catch (e) {
      debugPrint('[TeacherAttendance] save failed: $e');
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

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeacherBackHeader(
                title: '${widget.assignment.className} - ${strings.attendanceLabel}',
                onBack: () => popTeacherContent(ref),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: rosterAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => TeacherErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(rosterProvider((
                      classId: widget.assignment.classId,
                      academicYearId: widget.assignment.academicYearId,
                    ))),
                  ),
                  data: (students) {
                    return existingAsync.when(
                      skipLoadingOnReload: true,
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => TeacherErrorView(
                        error: e,
                        onRetry: () => ref.invalidate(attendanceForDateProvider((
                          classId: widget.assignment.classId,
                          subjectId: widget.assignment.subjectId,
                          date: _date,
                        ))),
                      ),
                      data: (existing) {
                        if (!_loadedForDate) {
                          for (final s in students) {
                            final match = existing.where((a) => a.studentId == s.studentId);
                            _status[s.studentId] = match.isNotEmpty ? match.first.status : 'present';
                          }
                          _loadedForDate = true;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TeacherCard(
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(strings.dateLabel,
                                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      const SizedBox(height: 2),
                                      Text(_fmt(_date), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                  label: Text(strings.changeDate),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final entry in statusLabels.entries)
                                  _countChip(
                                    theme,
                                    entry.value,
                                    _status.values.where((v) => v == entry.key).length,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TeacherCard(
                                padding: EdgeInsets.zero,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: students.length,
                                  separatorBuilder: (_, __) =>
                                      Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  itemBuilder: (context, i) {
                                    final s = students[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      child: Row(children: [
                                        Expanded(
                                          child: Text(s.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : () => _save(strings),
                                icon: const Icon(Icons.save_outlined),
                                label: Text(strings.saveAttendance),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countChip(ThemeData theme, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $count', style: theme.textTheme.labelMedium),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
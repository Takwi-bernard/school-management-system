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
class TeacherMarksEntryPage extends ConsumerStatefulWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherMarksEntryPage({super.key, required this.profile, required this.assignment});

  @override
  ConsumerState<TeacherMarksEntryPage> createState() => _TeacherMarksEntryPageState();
}

class _TeacherMarksEntryPageState extends ConsumerState<TeacherMarksEntryPage> {
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _remarkControllers = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    for (final c in _remarkControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _scoreFor(String studentId) =>
      _scoreControllers.putIfAbsent(studentId, () => TextEditingController());
  TextEditingController _remarkFor(String studentId) =>
      _remarkControllers.putIfAbsent(studentId, () => TextEditingController());

  Future<void> _save(String status, ExamPeriod period, String academicYearId, AppStrings strings) async {
    setState(() => _saving = true);
    try {
      final entries = _scoreControllers.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => MarkEntry(
                studentId: e.key,
                subjectId: widget.assignment.subjectId,
                classId: widget.assignment.classId,
                examPeriodId: period.id,
                score: double.tryParse(e.value.text.trim()) ?? 0,
                status: status,
                remarks: _remarkFor(e.key).text.trim().isEmpty ? null : _remarkFor(e.key).text.trim(),
              ))
          .toList();

      if (entries.isEmpty) return;

      await ref.read(teacherRepositoryProvider).saveMarks(
            profile: widget.profile,
            examPeriodId: period.id,
            academicYearId: academicYearId,
            entries: entries,
            status: status,
          );

      ref.invalidate(marksProvider((classId: widget.assignment.classId, subjectId: widget.assignment.subjectId)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'submitted' ? strings.marksSubmittedMessage : strings.draftSavedMessage),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.saveMarksError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final periodsAsync = ref.watch(examPeriodsProvider);
    final rosterAsync = ref.watch(
      rosterProvider((classId: widget.assignment.classId, academicYearId: widget.assignment.academicYearId)),
    );
    final marksAsync = ref.watch(
      marksProvider((classId: widget.assignment.classId, subjectId: widget.assignment.subjectId)),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TeacherBackHeader(
                  title: '${widget.assignment.subjectName} - ${strings.marksLabel}',
                  onBack: () => popTeacherContent(ref),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: periodsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (periods) {
                      final openPeriods = periods.where((p) => p.isOpen).toList();

                      if (openPeriods.isEmpty) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: TeacherEmptyState(
                              icon: Icons.lock_clock_outlined,
                              title: strings.marksLabel,
                              description: strings.marksNotOpenYet,
                            ),
                          ),
                        );
                      }

                      final currentPeriod = openPeriods.first;

                      return rosterAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (students) {
                          return marksAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('$e')),
                            data: (allMarks) {
                              for (final s in students) {
                                final existing = allMarks
                                    .where((m) => m.studentId == s.studentId && m.examPeriodId == currentPeriod.id)
                                    .toList();
                                if (existing.isNotEmpty && _scoreFor(s.studentId).text.isEmpty) {
                                  _scoreFor(s.studentId).text = existing.first.score.toString();
                                  if (existing.first.remarks != null) {
                                    _remarkFor(s.studentId).text = existing.first.remarks!;
                                  }
                                }
                              }

                              final otherPeriods = periods.where((p) => p.id != currentPeriod.id).toList();

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(currentPeriod.name,
                                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${strings.coefficientLabel} ${widget.assignment.coefficient}'
                                      '${currentPeriod.dueDate != null ? ' · ${strings.dueLabel} ${_fmt(currentPeriod.dueDate!)}' : ''}',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 20),
                                    TeacherCard(
                                      padding: EdgeInsets.zero,
                                      child: Column(
                                        children: [
                                          for (int i = 0; i < students.length; i++) ...[
                                            if (i > 0) Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                            Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(children: [
                                                    Expanded(
                                                      child: Text(students[i].fullName,
                                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                                    ),
                                                    for (final p in otherPeriods)
                                                      Builder(builder: (context) {
                                                        final prev = allMarks.where(
                                                            (m) => m.studentId == students[i].studentId && m.examPeriodId == p.id);
                                                        if (prev.isEmpty) return const SizedBox.shrink();
                                                        return Padding(
                                                          padding: const EdgeInsets.only(left: 8),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: theme.colorScheme.surfaceContainerHighest,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child:
                                                                Text('${p.name}: ${prev.first.score}', style: theme.textTheme.labelSmall),
                                                          ),
                                                        );
                                                      }),
                                                  ]),
                                                  const SizedBox(height: 8),
                                                  Row(children: [
                                                    SizedBox(
                                                      width: 110,
                                                      child: TextField(
                                                        controller: _scoreFor(students[i].studentId),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: InputDecoration(
                                                          labelText: strings.scoreLabel,
                                                          isDense: true,
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: _remarkFor(students[i].studentId),
                                                        decoration: InputDecoration(
                                                          labelText: strings.commentOptional,
                                                          isDense: true,
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                        ),
                                                      ),
                                                    ),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                      OutlinedButton(
                                        onPressed: _saving
                                            ? null
                                            : () => _save('draft', currentPeriod, widget.assignment.academicYearId, strings),
                                        child: Text(strings.saveDraft),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.icon(
                                        onPressed: _saving
                                            ? null
                                            : () => _save('submitted', currentPeriod, widget.assignment.academicYearId, strings),
                                        icon: const Icon(Icons.send_outlined),
                                        label: Text(strings.submitToPrincipal),
                                      ),
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
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
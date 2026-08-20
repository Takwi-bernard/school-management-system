import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

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

  Future<void> _save(String status, ExamPeriod period, String academicYearId) async {
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
          content: Text(status == 'submitted' ? 'Marks submitted to the Principal for review.' : 'Draft saved.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save marks. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periodsAsync = ref.watch(examPeriodsProvider);
    final rosterAsync = ref.watch(
      rosterProvider((classId: widget.assignment.classId, academicYearId: widget.assignment.academicYearId)),
    );
    final marksAsync = ref.watch(
      marksProvider((classId: widget.assignment.classId, subjectId: widget.assignment.subjectId)),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${widget.assignment.subjectName} - Marks')),
      body: periodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (periods) {
          final openPeriods = periods.where((p) => p.isOpen).toList();

          if (openPeriods.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'The Principal has not opened marks entry for any sequence yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Most schools only have one sequence open at a time - use
          // the first. If several are open, still show the first;
          // the teacher can only meaningfully fill one form here.
          final currentPeriod = openPeriods.first;

          return rosterAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (students) {
              return marksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (allMarks) {
                  // Pre-fill controllers from any existing draft/submitted
                  // mark for the CURRENT period only - past periods stay
                  // read-only reference data.
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
                    padding: EdgeInsets.all(Responsive.pagePadding(context)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(currentPeriod.name,
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Coefficient ${widget.assignment.coefficient}'
                                    '${currentPeriod.dueDate != null ? ' · Due ${_fmt(currentPeriod.dueDate!)}' : ''}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (final s in students)
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(s.fullName,
                                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                            ),
                                            for (final p in otherPeriods)
                                              Builder(builder: (context) {
                                                final prev = allMarks.where(
                                                    (m) => m.studentId == s.studentId && m.examPeriodId == p.id);
                                                if (prev.isEmpty) return const SizedBox.shrink();
                                                return Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: Chip(label: Text('${p.name}: ${prev.first.score}')),
                                                );
                                              }),
                                          ]),
                                          const SizedBox(height: 8),
                                          Row(children: [
                                            SizedBox(
                                              width: 110,
                                              child: TextField(
                                                controller: _scoreFor(s.studentId),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(labelText: 'Score (0-20)', isDense: true),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: _remarkFor(s.studentId),
                                                decoration: const InputDecoration(labelText: 'Comment (optional)', isDense: true),
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              OutlinedButton(
                                onPressed: _saving ? null : () => _save('draft', currentPeriod, widget.assignment.academicYearId),
                                child: const Text('Save Draft'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _save('submitted', currentPeriod, widget.assignment.academicYearId),
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Submit to Principal'),
                              ),
                            ]),
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
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

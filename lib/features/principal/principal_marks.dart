import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// MARKS ENTRY WINDOW - open/close per exam period
// ============================================================

class MarksWindowPage extends ConsumerWidget {
  final String schoolId;
  const MarksWindowPage({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final yearIdAsync = ref.watch(principalCurrentAcademicYearIdProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Marks Entry Window', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Teachers can only enter or submit marks for a sequence while it is open here. Closing a sequence does not delete any marks already entered.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: yearIdAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (yearId) {
                if (yearId == null) return const Text('No current academic year set.');
                return Consumer(
                  builder: (context, ref, _) {
                    final periodsAsync = ref.watch(examPeriodsProvider(yearId));
                    return periodsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('$e'),
                      data: (periods) => ListView.separated(
                        itemCount: periods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = periods[i];
                          return _PeriodRow(period: p, onChanged: () => ref.invalidate(examPeriodsProvider(yearId)));
                        },
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

class _PeriodRow extends ConsumerWidget {
  final ExamPeriodOption period;
  final VoidCallback onChanged;
  const _PeriodRow({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(period.periodName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  period.marksDueDate == null
                      ? 'No due date set'
                      : 'Due: ${period.marksDueDate!.day}/${period.marksDueDate!.month}/${period.marksDueDate!.year}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: period.marksDueDate ?? DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                await ref.read(principalRepositoryProvider).setExamPeriodOpen(examPeriodId: period.id, isOpen: period.isOpen, marksDueDate: picked);
                onChanged();
              }
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: const Text('Set Due Date'),
          ),
          const SizedBox(width: 8),
          Switch(
            value: period.isOpen,
            onChanged: (v) async {
              await ref.read(principalRepositoryProvider).setExamPeriodOpen(examPeriodId: period.id, isOpen: v);
              onChanged();
            },
          ),
          Text(period.isOpen ? 'Open' : 'Closed', style: TextStyle(color: period.isOpen ? Colors.green : theme.colorScheme.outline, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// MARKS REVIEW
// ============================================================

class MarksReviewPage extends ConsumerStatefulWidget {
  final String schoolId;
  const MarksReviewPage({super.key, required this.schoolId});

  @override
  ConsumerState<MarksReviewPage> createState() => _MarksReviewPageState();
}

class _MarksReviewPageState extends ConsumerState<MarksReviewPage> {
  String? _periodId;
  String? _classId;
  String? _className;
  String? _subjectId;
  String? _subjectName;
  final Set<String> _selectedMarkIds = {};

  void _resetTo({String? periodId, String? classId, String? className, String? subjectId, String? subjectName}) {
    setState(() {
      _periodId = periodId ?? _periodId;
      _classId = classId;
      _className = className;
      _subjectId = subjectId;
      _subjectName = subjectName;
      _selectedMarkIds.clear();
    });
  }

   Future<void> _approveMarks(List<String> markIds, {required bool isWholeClass}) async {
    if (markIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isWholeClass ? 'Approve all ${markIds.length} marks?' : 'Approve this mark?'),
        content: const Text('Approved marks become official. Report cards are NOT generated or published automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final principal = await ref.read(principalProfileProvider.future);
      if (principal == null) {
        throw Exception('Could not load your principal profile. Please sign out and back in, then try again.');
      }

      await ref.read(principalRepositoryProvider).approveMarks(markIds, principal.principalId);
      _selectedMarkIds.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${markIds.length} mark${markIds.length == 1 ? '' : 's'} approved.')),
        );
      }
    } catch (e) {
      // Every failure now surfaces something visible instead of
      // silently doing nothing - this was the actual bug.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
      }
      return;
    }

    ref.invalidate(marksForClassSubjectProvider((examPeriodId: _periodId!, classId: _classId!, subjectId: _subjectId!)));
    ref.invalidate(subjectsWithSubmittedMarksProvider((examPeriodId: _periodId!, classId: _classId!)));
    ref.invalidate(classesWithSubmittedMarksProvider(_periodId!));
  }
  Future<void> _sendBack(SubmittedMark mark) async {
    final feedbackController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Send back ${mark.studentName}\'s mark?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${mark.teacherName} will see this and can resubmit.'),
            const SizedBox(height: 12),
            TextField(controller: feedbackController, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'What needs to be corrected?')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send Back')),
        ],
      ),
    );
    if (confirmed != true || feedbackController.text.trim().isEmpty) return;
    await ref.read(principalRepositoryProvider).sendBackMarks([mark.id], feedbackController.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent back to teacher.')));
    ref.invalidate(marksForClassSubjectProvider((examPeriodId: _periodId!, classId: _classId!, subjectId: _subjectId!)));
  }

  Future<void> _discard(SubmittedMark mark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard this mark?'),
        content: Text('${mark.studentName}\'s ${mark.subjectName} mark will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Discard Permanently')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).discardMark(mark.id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mark discarded.')));
    ref.invalidate(marksForClassSubjectProvider((examPeriodId: _periodId!, classId: _classId!, subjectId: _subjectId!)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yearIdAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Marks Review', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Pick a sequence, then a class, then a subject - marks are always reviewed one subject at a time.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),
          yearIdAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (yearId) {
              if (yearId == null) return const Text('No current academic year set.');
              final periodsAsync = ref.watch(examPeriodsProvider(yearId));
              return periodsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (periods) => DropdownButtonFormField<String>(
                  initialValue: _periodId,
                  decoration: const InputDecoration(labelText: '1. Sequence', border: OutlineInputBorder()),
                  items: periods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.periodName))).toList(),
                  onChanged: (v) => _resetTo(periodId: v),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_periodId != null && _classId == null)
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final classesAsync = ref.watch(classesWithSubmittedMarksProvider(_periodId!));
                  return classesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (classes) {
                      if (classes.isEmpty) return Center(child: Text('No classes have submitted marks for this sequence yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)));
                      return ListView.separated(
                        itemCount: classes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = classes[i];
                          return Material(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _resetTo(classId: c['id'] as String, className: c['name'] as String),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Expanded(child: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  const Icon(Icons.chevron_right_rounded),
                                ]),
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
          if (_periodId != null && _classId != null && _subjectId == null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _resetTo(classId: null)),
                    Text(_className!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final subjectsAsync = ref.watch(subjectsWithSubmittedMarksProvider((examPeriodId: _periodId!, classId: _classId!)));
                        return subjectsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('$e'),
                          data: (subjects) => ListView.separated(
                            itemCount: subjects.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final s = subjects[i];
                              return Material(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() { _subjectId = s['id'] as String; _subjectName = s['name'] as String; }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(children: [
                                      Expanded(child: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
                                      const Icon(Icons.chevron_right_rounded),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (_periodId != null && _classId != null && _subjectId != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() { _subjectId = null; _subjectName = null; })),
                    Expanded(child: Text('$_className - $_subjectName', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  ]),
                  Consumer(
                    builder: (context, ref, _) {
                      final marksAsync = ref.watch(marksForClassSubjectProvider((examPeriodId: _periodId!, classId: _classId!, subjectId: _subjectId!)));
                      return marksAsync.when(
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                        data: (marks) => marks.isEmpty
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(children: [
                                  Text('${marks.length} student${marks.length == 1 ? '' : 's'} submitted', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: () => _approveMarks(marks.map((m) => m.id).toList(), isWholeClass: true),
                                    icon: const Icon(Icons.done_all_rounded, size: 18),
                                    label: const Text('Approve Whole Class'),
                                  ),
                                ]),
                              ),
                      );
                    },
                  ),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final marksAsync = ref.watch(marksForClassSubjectProvider((examPeriodId: _periodId!, classId: _classId!, subjectId: _subjectId!)));
                        return marksAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('$e'),
                          data: (marks) {
                            if (marks.isEmpty) return Center(child: Text('All marks here have been reviewed.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)));
                            return ListView.separated(
                              itemCount: marks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final m = marks[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(m.studentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            Text('Score: ${m.score} (Coef. ${m.coefficient})', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                            if (m.remarks != null && m.remarks!.isNotEmpty) Text('Note: ${m.remarks}', style: theme.textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                      IconButton(icon: const Icon(Icons.check_circle_outline_rounded), color: Colors.green, tooltip: 'Approve', onPressed: () => _approveMarks([m.id], isWholeClass: false)),
                                      IconButton(icon: const Icon(Icons.reply_rounded), tooltip: 'Send back', onPressed: () => _sendBack(m)),
                                      IconButton(icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error), tooltip: 'Discard', onPressed: () => _discard(m)),
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
        ],
      ),
    );
  }
}
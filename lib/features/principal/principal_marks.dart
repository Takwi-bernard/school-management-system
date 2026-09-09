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
  String? _selectedPeriodId;
  final Set<String> _selectedMarkIds = {};

  Future<void> _bulkApprove() async {
    if (_selectedMarkIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve ${_selectedMarkIds.length} mark(s)?'),
        content: const Text('Approved marks become official. Report cards are NOT published automatically - you\'ll publish them separately when ready.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    final principal = await ref.read(principalProfileProvider.future);
    if (principal == null) return;
    await ref.read(principalRepositoryProvider).approveMarks(_selectedMarkIds.toList(), principal.principalId);
    setState(() => _selectedMarkIds.clear());
    ref.invalidate(submittedMarksProvider(_selectedPeriodId!));
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
            Text('Explain what needs to be checked or corrected. ${mark.teacherName} will see this and can resubmit.'),
            const SizedBox(height: 12),
            TextField(controller: feedbackController, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. Please verify this score - it seems inconsistent with the rest of the class.')),
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
    ref.invalidate(submittedMarksProvider(_selectedPeriodId!));
  }

  Future<void> _discard(SubmittedMark mark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard this mark?'),
        content: Text('${mark.studentName}\'s ${mark.subjectName} mark will be permanently deleted from the database. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).discardMark(mark.id);
    ref.invalidate(submittedMarksProvider(_selectedPeriodId!));
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
          Text(
            'Review marks submitted by teachers before they become official. Approving does not publish report cards automatically.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          yearIdAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (yearId) {
              if (yearId == null) return const Text('No current academic year set.');
              return Consumer(
                builder: (context, ref, _) {
                  final periodsAsync = ref.watch(examPeriodsProvider(yearId));
                  return periodsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (periods) {
                      _selectedPeriodId ??= periods.isNotEmpty ? periods.first.id : null;
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedPeriodId,
                        decoration: const InputDecoration(labelText: 'Exam period', border: OutlineInputBorder()),
                        items: periods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.periodName))).toList(),
                        onChanged: (v) => setState(() { _selectedPeriodId = v; _selectedMarkIds.clear(); }),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedMarkIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text('${_selectedMarkIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilledButton.icon(onPressed: _bulkApprove, icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Approve Selected')),
                ],
              ),
            ),
          if (_selectedPeriodId != null)
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final marksAsync = ref.watch(submittedMarksProvider(_selectedPeriodId!));
                  return marksAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (marks) {
                      if (marks.isEmpty) {
                        return Center(child: Text('No marks waiting for review in this period.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)));
                      }
                      return ListView.separated(
                        itemCount: marks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = marks[i];
                          final selected = _selectedMarkIds.contains(m.id);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (v) => setState(() => v == true ? _selectedMarkIds.add(m.id) : _selectedMarkIds.remove(m.id)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${m.studentName} - ${m.subjectName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('${m.className} · Teacher: ${m.teacherName} · Score: ${m.score} (Coef. ${m.coefficient})',
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                      if (m.remarks != null && m.remarks!.isNotEmpty)
                                        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Teacher note: ${m.remarks}', style: theme.textTheme.bodySmall)),
                                    ],
                                  ),
                                ),
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
    );
  }
}
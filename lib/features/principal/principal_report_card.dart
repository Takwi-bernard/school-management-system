import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

class ReportCardManagementPage extends ConsumerStatefulWidget {
  final String schoolId;
  const ReportCardManagementPage({super.key, required this.schoolId});

  @override
  ConsumerState<ReportCardManagementPage> createState() => _ReportCardManagementPageState();
}

class _ReportCardManagementPageState extends ConsumerState<ReportCardManagementPage> {
  ManagedClass? _selectedClass;
  String? _selectedTermId;

  Future<void> _generate(ReportCardStatus student, String yearId) async {
    try {
      await ref.read(principalRepositoryProvider).generateReportCard(
            schoolId: widget.schoolId,
            studentId: student.studentId,
            classId: _selectedClass!.id,
            termId: _selectedTermId!,
            academicYearId: yearId,
          );
      _refresh(yearId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _publish(ReportCardStatus student) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Publish ${student.studentName}\'s report card?'),
        content: const Text('Once published, the parent will be able to see and download it immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'schedule'), child: const Text('Schedule for later')),
          FilledButton(onPressed: () => Navigator.pop(context, 'now'), child: const Text('Publish Now')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;

    final principal = await ref.read(principalProfileProvider.future);
    if (principal == null) return;

    DateTime? scheduledDate;
    if (choice == 'schedule') {
      scheduledDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
      );
      if (scheduledDate == null) return;
    }

    await ref.read(principalRepositoryProvider).publishReportCard(
          student.reportCardId!,
          principal.principalId,
          publishAt: scheduledDate,
        );
    final yearId = await ref.read(principalCurrentAcademicYearIdProvider(widget.schoolId).future);
    _refresh(yearId);
  }

  Future<void> _unpublish(ReportCardStatus student) async {
    await ref.read(principalRepositoryProvider).unpublishReportCard(student.reportCardId!);
    final yearId = await ref.read(principalCurrentAcademicYearIdProvider(widget.schoolId).future);
    _refresh(yearId);
  }

  void _refresh(String? yearId) {
    if (yearId == null || _selectedClass == null || _selectedTermId == null) return;
    ref.invalidate(reportCardStatusProvider((classId: _selectedClass!.id, termId: _selectedTermId!, academicYearId: yearId)));
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
          Text('Report Card Management', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Generate a report card from approved marks, then publish it whenever you\'re ready - publishing is a separate, deliberate step, and can be scheduled for a later date.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          classesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (classes) => DropdownButtonFormField<ManagedClass>(
              initialValue: _selectedClass,
              decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
              items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c.className))).toList(),
              onChanged: (v) => setState(() => _selectedClass = v),
            ),
          ),
                   const SizedBox(height: 12),
          yearIdAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (yearId) {
              if (yearId == null) return const SizedBox();
              final termsAsync = ref.watch(principalTermsForYearProvider(yearId));
              return termsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (terms) {
                  _selectedTermId ??= terms.firstWhere((t) => t.isCurrent, orElse: () => terms.isNotEmpty ? terms.first : const AcademicTermOption(id: '', termName: '', isCurrent: false)).id;
                  if (_selectedTermId!.isEmpty) return const Text('No academic terms configured yet.');
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedTermId,
                    decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                    items: terms.map((t) => DropdownMenuItem(value: t.id, child: Text(t.termName))).toList(),
                    onChanged: (v) => setState(() => _selectedTermId = v),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedClass != null && _selectedTermId != null)
            Expanded(
              child: yearIdAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (yearId) {
                  if (yearId == null) return const Text('No current academic year set.');
                  final statusAsync = ref.watch(reportCardStatusProvider((classId: _selectedClass!.id, termId: _selectedTermId!, academicYearId: yearId)));
                  return statusAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (students) => ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = students[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(child: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (!s.exists)
                                OutlinedButton(onPressed: () => _generate(s, yearId), child: const Text('Generate'))
                              else if (!s.isPublished) ...[
                                Text(s.publishAt != null ? 'Scheduled: ${s.publishAt!.day}/${s.publishAt!.month}' : 'Not published',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                const SizedBox(width: 8),
                                FilledButton(onPressed: () => _publish(s), child: const Text('Publish')),
                              ] else ...[
                                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                const SizedBox(width: 6),
                                const Text('Published', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                TextButton(onPressed: () => _unpublish(s), child: const Text('Unpublish')),
                              ],
                            ],
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
    );
  }
}
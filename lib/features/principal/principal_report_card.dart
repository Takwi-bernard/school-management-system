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
                   if (_selectedClass != null && _selectedTermId != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: yearIdAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (yearId) {
                  if (yearId == null) return const SizedBox();
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await ref.read(principalRepositoryProvider).generateReportCardsForClass(
                                  schoolId: widget.schoolId, classId: _selectedClass!.id, termId: _selectedTermId!, academicYearId: yearId,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Generated ${result['succeeded']} of ${result['total']} (${result['skipped']} had no approved marks yet).')),
                              );
                            }
                            _refresh(yearId);
                          },
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Generate All for This Class'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final choice = await showDialog<String>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Publish all report cards for ${_selectedClass!.className}?'),
                                content: const Text('Every generated report card in this class will become visible to parents at once.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
                                  OutlinedButton(onPressed: () => Navigator.pop(context, 'schedule'), child: const Text('Schedule for later')),
                                  FilledButton(onPressed: () => Navigator.pop(context, 'now'), child: const Text('Publish Now')),
                                ],
                              ),
                            );
                            if (choice == null || choice == 'cancel') return;

                            DateTime? scheduledDate;
                            if (choice == 'schedule') {
                              scheduledDate = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                              if (scheduledDate == null) return;
                            }

                            final principal = await ref.read(principalProfileProvider.future);
                            if (principal == null) return;

                            final count = await ref.read(principalRepositoryProvider).publishReportCardsForClass(
                                  classId: _selectedClass!.id, termId: _selectedTermId!, principalId: principal.principalId, publishAt: scheduledDate,
                                );
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count report card(s) published for ${_selectedClass!.className}.')));
                            _refresh(yearId);
                          },
                          icon: const Icon(Icons.publish_rounded),
                          label: const Text('Publish Whole Class'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
         
        ],
      ),
    );
  }
}
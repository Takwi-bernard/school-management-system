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
  String? _yearId;
  String? _termId;
  String? _termName;
  DepartmentFull? _department;
  ManagedClass? _class;

  void _resetFrom(String level) {
    setState(() {
      if (level == 'year') { _termId = null; _termName = null; _department = null; _class = null; }
      if (level == 'term') { _department = null; _class = null; }
      if (level == 'department') { _class = null; }
    });
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
          Text('Report Card Management', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Year → Department → Class → Students, following exactly where marks actually exist.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 16),

          // STEP 1: YEAR (school only has one "current" year today, but
          // this is deliberately its own explicit step, not silently
          // assumed - the Principal SEES which year they're working in)
          yearIdAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (yearId) {
              if (yearId == null) return const Text('No academic year is currently open for this school.');
              _yearId ??= yearId;
              return _Breadcrumb(label: 'Academic Year: Current', onTap: null);
            },
          ),
          const SizedBox(height: 10),

          // STEP 2: TERM/SEQUENCE
          if (_yearId != null)
            Consumer(
              builder: (context, ref, _) {
                final termsAsync = ref.watch(principalTermsForYearProvider(_yearId!));
                return termsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (terms) {
                    if (terms.isEmpty) return const Text('No terms configured for this year.');
                    return DropdownButtonFormField<String>(
                      initialValue: _termId,
                      decoration: const InputDecoration(labelText: 'Term / Sequence', border: OutlineInputBorder()),
                      items: terms.map((t) => DropdownMenuItem(value: t.id, child: Text(t.termName))).toList(),
                      onChanged: (v) {
                        final term = terms.firstWhere((t) => t.id == v);
                        setState(() { _termId = v; _termName = term.termName; });
                        _resetFrom('term');
                      },
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 16),

          // STEP 3+: DEPARTMENT -> CLASS -> STUDENTS
          if (_termId != null)
            Expanded(child: _buildBody(theme))
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_class != null) {
      return _ClassReportCardsPane(
        schoolId: widget.schoolId,
        yearId: _yearId!,
        termId: _termId!,
        termName: _termName!,
        classInfo: _class!,
        onBack: () => setState(() => _class = null),
      );
    }

    if (_department != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Breadcrumb(label: _department!.departmentName, onTap: () => setState(() { _department = null; })),
          const SizedBox(height: 8),
          Text('Choose a class:', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final classesAsync = ref.watch(classesWithMarksForDeptProvider((schoolId: widget.schoolId, termId: _termId!, departmentId: _department!.id)));
                return classesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (classes) {
                    if (classes.isEmpty) return const Center(child: Text('No classes in this department have approved marks for this term yet.'));
                    return ListView.separated(
                      itemCount: classes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = classes[i];
                        return _DrillTile(
                          // Class name alone can repeat across
                          // departments (e.g. "Form 1A" in both General
                          // and Technical) - always show the department
                          // alongside it so it's never ambiguous.
                          title: '${c.className}  ·  ${_department!.departmentName}',
                          onTap: () => setState(() => _class = c),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    // Department list (top of this drill-down)
    return Consumer(
      builder: (context, ref, _) {
        final deptsAsync = ref.watch(departmentsWithMarksProvider((schoolId: widget.schoolId, termId: _termId!)));
        return deptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (departments) {
            if (departments.isEmpty) return const Center(child: Text('No department has approved marks for this term yet.'));
            return ListView.separated(
              itemCount: departments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _DrillTile(title: departments[i].departmentName, onTap: () => setState(() => _department = departments[i])),
            );
          },
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Breadcrumb({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onTap != null) IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onTap),
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DrillTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _DrillTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded)]),
        ),
      ),
    );
  }
}

// ============================================================
// CLASS LEVEL: generate/publish for not-yet-generated students,
// PLUS a separate section for already-generated report cards
// ============================================================

class _ClassReportCardsPane extends ConsumerWidget {
  final String schoolId;
  final String yearId;
  final String termId;
  final String termName;
  final ManagedClass classInfo;
  final VoidCallback onBack;

  const _ClassReportCardsPane({
    required this.schoolId,
    required this.yearId,
    required this.termId,
    required this.termName,
    required this.classInfo,
    required this.onBack,
  });

  Future<void> _generate(BuildContext context, WidgetRef ref, ReportCardStatus student) async {
    try {
      await ref.read(principalRepositoryProvider).generateReportCard(
            schoolId: schoolId, studentId: student.studentId, classId: classInfo.id, termId: termId, academicYearId: yearId,
          );
      _refresh(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _generateAll(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(principalRepositoryProvider).generateReportCardsForClass(
          schoolId: schoolId, classId: classInfo.id, termId: termId, academicYearId: yearId,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated ${result['succeeded']} of ${result['total']} (${result['skipped']} had no approved marks).')));
    }
    _refresh(ref);
  }

  Future<void> _publishAll(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Publish all report cards for ${classInfo.className}?'),
        content: const Text('Every generated report card in this class becomes visible to parents.'),
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
    if (principal == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load your principal profile.')));
      return;
    }

    final count = await ref.read(principalRepositoryProvider).publishReportCardsForClass(classId: classInfo.id, termId: termId, principalId: principal.principalId, publishAt: scheduledDate);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count report card(s) published.')));
    _refresh(ref);
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, ReportCardStatus rc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${rc.studentName}\'s report card?'),
        content: Text(rc.isPublished
            ? 'This report card is currently published and visible to the parent. Deleting it removes it immediately and permanently.'
            : 'This report card will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Delete Permanently')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(principalRepositoryProvider).deleteReportCard(rc.reportCardId!);
    _refresh(ref);
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(reportCardStatusProvider((classId: classInfo.id, termId: termId, academicYearId: yearId)));
    ref.invalidate(generatedReportCardsProvider((classId: classInfo.id, termId: termId)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eligibleAsync = ref.watch(reportCardStatusProvider((classId: classInfo.id, termId: termId, academicYearId: yearId)));
    final generatedAsync = ref.watch(generatedReportCardsProvider((classId: classInfo.id, termId: termId)));

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Breadcrumb(label: '${classInfo.className} - $termName', onTap: onBack),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(onPressed: () => _generateAll(context, ref), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Generate All')),
            const SizedBox(width: 10),
            FilledButton.icon(onPressed: () => _publishAll(context, ref), icon: const Icon(Icons.publish_rounded), label: const Text('Publish Whole Class')),
          ]),
          const SizedBox(height: 12),
          const TabBar(tabs: [Tab(text: 'Not Yet Generated'), Tab(text: 'Already Generated')]),
          Expanded(
            child: TabBarView(
              children: [
                // --- NOT YET GENERATED ---
                eligibleAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (students) {
                    final pending = students.where((s) => !s.exists).toList();
                    if (pending.isEmpty) return const Center(child: Text('Every enrolled student already has a report card for this term.'));
                    return ListView.separated(
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = pending[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Expanded(child: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w700))),
                            OutlinedButton(onPressed: () => _generate(context, ref, s), child: const Text('Generate')),
                          ]),
                        );
                      },
                    );
                  },
                ),
                // --- ALREADY GENERATED - its own clearly separate section ---
                generatedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (generated) {
                    if (generated.isEmpty) return const Center(child: Text('No report cards generated for this class yet.'));
                    return ListView.separated(
                      itemCount: generated.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final rc = generated[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(child: Text(rc.studentName, style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (rc.isPublished)
                                const Chip(label: Text('Published'), backgroundColor: Color(0x1A4CAF50), labelStyle: TextStyle(color: Colors.green))
                              else
                                Chip(label: Text(rc.publishAt != null ? 'Scheduled' : 'Draft'), backgroundColor: theme.colorScheme.surfaceContainerHigh),
                              IconButton(icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error), tooltip: 'Delete', onPressed: () => _discard(context, ref, rc)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
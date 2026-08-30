import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_state.dart';
import '../../core/export/export_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

class TeacherClassListPage extends ConsumerWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherClassListPage({super.key, required this.profile, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final schoolName = ref.watch(landingProvider).value?.schoolName ?? '';
    final rosterAsync = ref.watch(
      rosterProvider((classId: assignment.classId, academicYearId: assignment.academicYearId)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(strings.classListLabel)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: rosterAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorStateView(
                  onRetry: () => ref.invalidate(
                    rosterProvider((classId: assignment.classId, academicYearId: assignment.academicYearId)),
                  ),
                ),
                data: (students) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RevealOnScroll(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: LayoutBuilder(builder: (context, constraints) {
                            final compact = constraints.maxWidth < 500;
                            final info = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assignment.className,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(assignment.subjectName, style: const TextStyle(color: Colors.white70)),
                              ],
                            );
                            final count = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                              child: Column(children: [
                                Text('${students.length}',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                                Text(strings.studentsLabel, style: theme.textTheme.labelSmall),
                              ]),
                            );
                            return compact
                                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 16), count])
                                : Row(children: [Expanded(child: info), count]);
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(child: Text(strings.studentsLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                        IconButton(
                          icon: const Icon(Icons.table_view_outlined),
                          tooltip: 'Excel',
                          onPressed: students.isEmpty ? null : () => _exportExcel(students, schoolName),
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          tooltip: 'PDF',
                          onPressed: students.isEmpty ? null : () => _exportPdf(students, schoolName),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      if (students.isEmpty)
                        _EmptyState(theme: theme, message: strings.noStudentsEnrolled)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final s = students[i];
                            return RevealOnScroll(
                              delay: Duration(milliseconds: (i * 30).clamp(0, 300)),
                              child: HoverLift(
                                liftPixels: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 26,
                                      child: Text('${i + 1}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                                    ),
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null,
                                      child: s.photoUrl == null
                                          ? Icon(Icons.person_outline, color: theme.colorScheme.primary)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(s.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                        Text(s.admissionNumber, style: theme.textTheme.bodySmall),
                                      ]),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(10)),
                                      child: Text(s.gender, style: theme.textTheme.labelSmall),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _exportExcel(List<RosterStudent> students, String schoolName) {
    ExportService.exportExcel(
      fileName: '${assignment.className}_${assignment.subjectName}_class_list.xlsx',
      headers: const ['#', 'Full Name', 'Admission No.', 'Gender'],
      rows: [
        for (var i = 0; i < students.length; i++)
          [
            '${i + 1}',
            students[i].fullName,
            students[i].admissionNumber,
            students[i].gender,
          ],
      ],
    );
  }

  Future<void> _exportPdf(List<RosterStudent> students, String schoolName) async {
    await ExportService.exportPdf(
      fileName: '${assignment.className}_${assignment.subjectName}_class_list.pdf',
      title: '$schoolName - ${assignment.className}',
      subtitle: '${assignment.subjectName} - Class List (${students.length} students)',
      headers: const ['#', 'Full Name', 'Admission No.', 'Gender'],
      rows: [
        for (var i = 0; i < students.length; i++)
          [
            '${i + 1}',
            students[i].fullName,
            students[i].admissionNumber,
            students[i].gender,
          ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  final String message;
  const _EmptyState({required this.theme, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Icon(Icons.groups_outlined, size: 44, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        Text(message, style: theme.textTheme.bodyMedium),
      ]),
    );
  }
}
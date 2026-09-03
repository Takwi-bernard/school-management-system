import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_state.dart';
import '../../core/export/export_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';
import 'teacher_ui.dart';

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
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assignment.className,
                                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                                const SizedBox(height: 2),
                                Text(assignment.subjectName,
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(children: [
                              Text('${students.length}',
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                              Text(strings.studentsLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: Text(strings.studentsLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
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
                      const SizedBox(height: 8),
                      if (students.isEmpty)
                        TeacherEmptyState(
                          icon: Icons.groups_outlined,
                          title: strings.studentsLabel,
                          description: strings.noStudentsEnrolled,
                        )
                      else
                        TeacherCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (int i = 0; i < students.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 26,
                                      child: Text('${i + 1}',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
                                    ),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      backgroundImage: students[i].photoUrl != null ? NetworkImage(students[i].photoUrl!) : null,
                                      child: students[i].photoUrl == null
                                          ? Icon(Icons.person_outline, color: theme.colorScheme.primary, size: 18)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(students[i].fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                        Text(students[i].admissionNumber,
                                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      ]),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(students[i].gender, style: theme.textTheme.labelSmall),
                                    ),
                                  ]),
                                ),
                              ],
                            ],
                          ),
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
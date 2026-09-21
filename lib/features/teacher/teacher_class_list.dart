import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../core/error_state.dart';
import '../../core/export/export_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_navigation.dart';
import 'teacher_providers.dart';
import 'teacher_strings.dart';
import 'teacher_ui.dart';

/// Reached via pushTeacherContent, not Navigator.push - stays inside
/// TeacherShell so the sidebar/drawer is always still reachable.
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: rosterAsync.when(
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeacherBackHeader(title: assignment.className, subtitle: assignment.subjectName, onBack: () => popTeacherContent(ref)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
              error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeacherBackHeader(title: assignment.className, subtitle: assignment.subjectName, onBack: () => popTeacherContent(ref)),
                  const SizedBox(height: 20),
                  ErrorStateView(
                    error: e,
                    onRetry: () => ref.invalidate(
                      rosterProvider((classId: assignment.classId, academicYearId: assignment.academicYearId)),
                    ),
                  ),
                ],
              ),
              data: (students) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeacherBackHeader(
                      title: assignment.className,
                      subtitle: assignment.subjectName,
                      onBack: () => popTeacherContent(ref),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(children: [
                          Text('${students.length}',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                          Text(strings.studentsLabel, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: Text(strings.studentsLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.table_view_outlined),
                        tooltip: 'Excel',
                        onPressed: students.isEmpty ? null : () => _exportExcel(students, strings),
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'PDF',
                        onPressed: students.isEmpty ? null : () => _exportPdf(ref, students, schoolName, theme.colorScheme.primary, strings),
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
                                    onBackgroundImageError: students[i].photoUrl != null ? (_, __) {} : null,
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
                                    child: Text(strings.tGenderLabel(students[i].gender), style: theme.textTheme.labelSmall),
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
    );
  }

  // Keeps letters, digits, underscore and dash so the file name is safe
  // on every operating system.
  String _safeName(String value) => value.replaceAll(RegExp(r'[^\w\-]+'), '_');

  String get _baseFileName => '${_safeName(assignment.className)}_${_safeName(assignment.subjectName)}_class_list';

  List<String> _headers(AppStrings strings) => ['#', strings.fullName, strings.tAdmissionNo, strings.tGender];

  List<List<String>> _rows(List<RosterStudent> students, AppStrings strings) => [
        for (var i = 0; i < students.length; i++)
          [
            '${i + 1}',
            students[i].fullName,
            students[i].admissionNumber,
            strings.tGenderLabel(students[i].gender),
          ],
      ];

  void _exportExcel(List<RosterStudent> students, AppStrings strings) {
    ExportService.exportExcel(
      fileName: '$_baseFileName.xlsx',
      headers: _headers(strings),
      rows: _rows(students, strings),
    );
  }

  Future<void> _exportPdf(
    WidgetRef ref,
    List<RosterStudent> students,
    String schoolName,
    Color primary,
    AppStrings strings,
  ) async {
    // The school's letterhead, if one has been uploaded. Any failure
    // here just means the PDF uses the plain title layout instead.
    OfficialBranding? branding;
    try {
      final assets = await ref.read(teacherBrandingAssetsProvider(profile.schoolId).future);
      branding = await OfficialBranding.fetch(assets);
    } catch (_) {
      branding = null;
    }
    final hasLetterhead = branding != null && branding.letterhead != null;

    await ExportService.exportPdf(
      fileName: '$_baseFileName.pdf',
      // The letterhead already carries the school's name.
      title: hasLetterhead ? assignment.className : '$schoolName - ${assignment.className}',
      subtitle: '${assignment.subjectName} - ${strings.tClassListTitle} (${students.length} ${strings.studentsLabel})',
      headers: _headers(strings),
      accentColor: PdfColor.fromInt(primary.toARGB32()),
      rows: _rows(students, strings),
      branding: branding,
    );
  }
}

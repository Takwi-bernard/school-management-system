import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_attendance.dart';
import 'teacher_class_list.dart';
import 'teacher_marks_entry.dart';
import 'teacher_models.dart';
import 'teacher_ui.dart';

class TeacherAssignmentDetailPage extends ConsumerWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherAssignmentDetailPage({super.key, required this.profile, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final columns = isMobile ? 1 : (isTablet ? 2 : 3);
    final strings = AppStrings(ref.watch(activeLocaleProvider));

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(assignment.subjectName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(assignment.subjectName,
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text(assignment.className,
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _Badge(label: '${strings.coefficientLabel} ${assignment.coefficient}'),
                              _Badge(label: '${assignment.periodsPerWeek} ${strings.periodsPerWeekLabel}'),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(strings.whatWouldYouLikeToDo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isMobile ? 3.2 : (isTablet ? 1.9 : 1.5),
                    children: [
                      _ActionCard(
                        icon: Icons.groups_outlined,
                        label: strings.classListLabel,
                        description: strings.viewEnrolledStudents,
                        // Re-applying `theme` (already captured above via
                        // Theme.of(context), which correctly sees the
                        // school-seeded theme) because Navigator.push lands
                        // the new page in a sibling Overlay entry, not a
                        // descendant of this tree - without this it would
                        // silently fall back to the app's default theme.
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Theme(
                              data: theme,
                              child: TeacherClassListPage(profile: profile, assignment: assignment),
                            ),
                          ),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.edit_note_outlined,
                        label: strings.marksLabel,
                        description: strings.enterSubmitMarks,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Theme(
                              data: theme,
                              child: TeacherMarksEntryPage(profile: profile, assignment: assignment),
                            ),
                          ),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.fact_check_outlined,
                        label: strings.attendanceLabel,
                        description: strings.recordDailyAttendance,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Theme(
                              data: theme,
                              child: TeacherAttendancePage(profile: profile, assignment: assignment),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TeacherCard(
      padding: EdgeInsets.zero,
      child: TeacherPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
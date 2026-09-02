import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_attendance.dart';
import 'teacher_class_list.dart';
import 'teacher_marks_entry.dart';
import 'teacher_models.dart';

class TeacherAssignmentDetailPage extends ConsumerWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherAssignmentDetailPage({super.key, required this.profile, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    // FLAG (fixed): this used to jump straight from 1 column on
    // mobile to 3 on anything else, so on a tablet-width window the
    // three action cards got squeezed uncomfortably narrow. Now steps
    // through 1 / 2 / 3 in line with Responsive's own breakpoints.
    final columns = isMobile ? 1 : (isTablet ? 2 : 3);
    final aspect = isMobile ? 3.2 : (isTablet ? 1.7 : 1.3);
    final strings = AppStrings(ref.watch(activeLocaleProvider));

    return Scaffold(
      appBar: AppBar(title: Text(assignment.subjectName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RevealOnScroll(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.menu_book_outlined, color: Colors.white, size: 26),
                          ),
                          const SizedBox(height: 16),
                          Text(assignment.subjectName,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(assignment.className,
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            _Badge(label: '${strings.coefficientLabel} ${assignment.coefficient}'),
                            _Badge(label: '${assignment.periodsPerWeek} ${strings.periodsPerWeekLabel}'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(strings.whatWouldYouLikeToDo, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: aspect,
                    children: [
                      _ActionCard(
                        icon: Icons.groups_outlined,
                        label: strings.classListLabel,
                        description: strings.viewEnrolledStudents,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => TeacherClassListPage(profile: profile, assignment: assignment))),
                      ),
                      _ActionCard(
                        icon: Icons.edit_note_outlined,
                        label: strings.marksLabel,
                        description: strings.enterSubmitMarks,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => TeacherMarksEntryPage(profile: profile, assignment: assignment))),
                      ),
                      _ActionCard(
                        icon: Icons.fact_check_outlined,
                        label: strings.attendanceLabel,
                        description: strings.recordDailyAttendance,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => TeacherAttendancePage(profile: profile, assignment: assignment))),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
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
    return RevealOnScroll(
      child: HoverLift(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 14),
              Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
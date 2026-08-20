import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import 'teacher_attendance.dart';
import 'teacher_class_list.dart';
import 'teacher_marks_entry.dart';
import 'teacher_models.dart';

/// The "Mathematics -> Form 2A" screen - overview + entry points into
/// class list, marks, and attendance for this one assignment.
class TeacherAssignmentDetailPage extends StatelessWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherAssignmentDetailPage({super.key, required this.profile, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)]),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(assignment.subjectName,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(assignment.className,
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary)),
                        const SizedBox(height: 14),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          _Badge(label: 'Coefficient ${assignment.coefficient}'),
                          _Badge(label: '${assignment.periodsPerWeek} periods/week'),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Actions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _ActionCard(
                      icon: Icons.groups_outlined,
                      label: 'Class List',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => TeacherClassListPage(profile: profile, assignment: assignment))),
                    ),
                    _ActionCard(
                      icon: Icons.edit_note_outlined,
                      label: 'Marks',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => TeacherMarksEntryPage(profile: profile, assignment: assignment))),
                    ),
                    _ActionCard(
                      icon: Icons.fact_check_outlined,
                      label: 'Attendance',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => TeacherAttendancePage(profile: profile, assignment: assignment))),
                    ),
                  ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverLift(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, size: 30, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

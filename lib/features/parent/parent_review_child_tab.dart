import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

/// Migrated from ReviewChildPage - no own Scaffold/AppBar/Theme wrap
/// anymore, ParentShell provides all three. The child is now passed
/// in directly (already picked by ParentShell's child-picker flow
/// before this is ever built) instead of being a widget field on a
/// standalone pushed page.
class ParentReviewChildTab extends ConsumerWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentReviewChildTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final yearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));
    final commentsAsync = ref.watch(approvedCommentsProvider(child.studentId));

    return yearIdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (yearId) {
        if (yearId == null) return Center(child: Text(strings.academicYearNotSet));
        final attendanceAsync = ref.watch(attendanceSummaryProvider((studentId: child.studentId, academicYearId: yearId)));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.reviewMyChild, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text(child.fullName, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(strings.attendanceSummary, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              strings.isFrench
                  ? 'Ce résumé montre combien de fois votre enfant a été présent, absent ou en retard cette année.'
                  : 'This summary shows how many times your child has been present, absent, or late this year.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (summary) => Row(
                children: [
                  _AttendanceStat(label: strings.present, value: summary.present, color: Colors.green),
                  _AttendanceStat(label: strings.absent, value: summary.absent, color: Colors.red),
                  _AttendanceStat(label: strings.late, value: summary.late, color: Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(strings.schoolComments, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              strings.isFrench
                  ? 'Ces commentaires sont écrits par les enseignants et approuvés par le Directeur avant d\'apparaître ici.'
                  : 'These comments are written by teachers and approved by the Principal before appearing here.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (comments) {
                if (comments.isEmpty) {
                  return Text(strings.noCommentYet, style: TextStyle(color: theme.colorScheme.outline));
                }
                return Column(
                  children: comments
                      .map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(c.teacherName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(c.examPeriodName, style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(c.comment),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _AttendanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
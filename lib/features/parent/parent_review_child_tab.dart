import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

/// "Review My Child": a snapshot of how the child is doing this year -
/// attendance and the comments teachers have written (only after the
/// Principal has approved them). Same visual language as the rest of
/// the module: brand-color tints for structure, and the shared status
/// colors only where a number genuinely means good / bad / needs
/// attention (present / absent / late).
class ParentReviewChildTab extends ConsumerWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentReviewChildTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final yearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));
    final commentsAsync = ref.watch(approvedCommentsProvider(child.studentId));

    return yearIdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(
        error: e,
        onRetry: () => ref.invalidate(currentAcademicYearIdProvider(child.schoolId)),
      ),
      data: (yearId) {
        if (yearId == null) {
          return _InfoState(icon: Icons.event_busy_rounded, message: strings.academicYearNotSet);
        }
        final attendanceKey = (studentId: child.studentId, academicYearId: yearId);
        final attendanceAsync = ref.watch(attendanceSummaryProvider(attendanceKey));
        final hasPhoto = child.photoUrl != null && child.photoUrl!.isNotEmpty;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(strings.reviewMyChild, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              strings.isFrench
                  ? 'Un aperçu de la présence et des commentaires des enseignants pour ${child.firstName} cette année.'
                  : 'A look at ${child.firstName}\'s attendance and teacher comments this year.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    backgroundImage: hasPhoto ? NetworkImage(child.photoUrl!) : null,
                    onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : '?',
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          child.className == null || child.className!.isEmpty
                              ? child.admissionNumber
                              : '${child.className} \u00b7 ${child.admissionNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            Text(strings.attendanceSummary, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              strings.isFrench
                  ? 'Combien de fois votre enfant a été présent, absent ou en retard cette année.'
                  : 'How many times your child has been present, absent, or late this year.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            attendanceAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => ErrorStateView(
                error: e,
                onRetry: () => ref.invalidate(attendanceSummaryProvider(attendanceKey)),
              ),
              data: (summary) {
                final total = summary.present + summary.absent + summary.late;
                if (total == 0) {
                  return _InfoCard(
                    icon: Icons.fact_check_outlined,
                    message: strings.isFrench
                        ? 'Aucune présence n\'a encore été enregistrée cette année.'
                        : 'No attendance has been recorded yet this year.',
                  );
                }
                final rate = (summary.present / total).clamp(0.0, 1.0);
                return Column(
                  children: [
                    Row(
                      children: [
                        _AttendanceStat(label: strings.present, value: summary.present, color: kSettled),
                        const SizedBox(width: 10),
                        _AttendanceStat(label: strings.absent, value: summary.absent, color: kOverdue),
                        const SizedBox(width: 10),
                        _AttendanceStat(label: strings.late, value: summary.late, color: kPending),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  strings.isFrench ? 'Taux de présence' : 'Attendance rate',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('${(rate * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: rate,
                              minHeight: 8,
                              backgroundColor: scheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),

            Text(strings.schoolComments, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              strings.isFrench
                  ? 'Ces commentaires sont écrits par les enseignants et approuvés par le Directeur avant d\'apparaître ici.'
                  : 'Teachers write these comments, and the Principal approves them before they appear here.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            commentsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => ErrorStateView(error: e, onRetry: () => ref.invalidate(approvedCommentsProvider(child.studentId))),
              data: (comments) {
                if (comments.isEmpty) {
                  return _InfoCard(icon: Icons.chat_bubble_outline_rounded, message: strings.noCommentYet);
                }
                return Column(
                  children: [
                    for (final c in comments)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                                  child: Text(
                                    c.teacherName.isNotEmpty ? c.teacherName[0].toUpperCase() : '?',
                                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(c.teacherName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                Text(c.examPeriodName, style: TextStyle(color: scheme.outline, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(c.comment, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                  ],
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

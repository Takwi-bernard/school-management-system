import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../landing/landing_model.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_shell.dart' show ParentChildAvatar;
import 'parent_ui.dart';

/// "Review My Child": attendance this year and the teacher comments the
/// Principal has approved.
class ParentReviewChildTab extends ConsumerWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentReviewChildTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fr = strings.isFrench;
    final yearAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));
    final commentsAsync = ref.watch(approvedCommentsProvider(child.studentId));

    Widget attendance;
    if (yearAsync.isLoading && !yearAsync.hasValue) {
      attendance = const PaSkeletonList(rows: 2, height: 90);
    } else if (yearAsync.hasError) {
      attendance = PaError(error: yearAsync.error!, strings: strings, onRetry: () => ref.invalidate(currentAcademicYearIdProvider(child.schoolId)));
    } else if (yearAsync.valueOrNull == null) {
      attendance = PrCard(child: PaEmpty(icon: Icons.event_busy_rounded, title: strings.academicYearNotSet));
    } else {
      final key = (studentId: child.studentId, academicYearId: yearAsync.valueOrNull!);
      attendance = PaAsync<AttendanceSummary>(
        value: ref.watch(attendanceSummaryProvider(key)),
        strings: strings,
        onRetry: () => ref.invalidate(attendanceSummaryProvider(key)),
        rows: 2,
        rowHeight: 90,
        isEmpty: (s) => s.present + s.absent + s.late == 0,
        empty: PaEmpty(
          icon: Icons.fact_check_outlined,
          title: fr ? 'Aucune présence n\'a encore été enregistrée cette année.' : 'No attendance has been recorded yet this year.',
        ),
        builder: (s) {
          final total = s.present + s.absent + s.late;
          final rate = (s.present / total).clamp(0.0, 1.0).toDouble();
          return Column(children: [
            Row(children: [
              _Stat(label: strings.present, value: s.present, color: kSettled),
              const SizedBox(width: 10),
              _Stat(label: strings.absent, value: s.absent, color: kOverdue),
              const SizedBox(width: 10),
              _Stat(label: strings.late, value: s.late, color: kPending),
            ]),
            const SizedBox(height: 12),
            PrReveal(
              index: 3,
              child: PrCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(fr ? 'Taux de présence' : 'Attendance rate', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                    Text('${(rate * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 8),
                  PrProgressBar(value: rate),
                ]),
              ),
            ),
          ]);
        },
      );
    }

    return PrPage(
      maxWidth: 820,
      onRefresh: () async {
        ref.invalidate(approvedCommentsProvider(child.studentId));
        ref.invalidate(currentAcademicYearIdProvider(child.schoolId));
      },
      children: [
        PaHero(
          leading: ParentChildAvatar(child: child, radius: 30),
          eyebrow: strings.reviewMyChild,
          title: child.fullName,
          subtitle: child.className == null || child.className!.isEmpty ? child.admissionNumber : '${child.className} · ${child.admissionNumber}',
        ),
        const SizedBox(height: 24),
        PrSectionTitle(
          title: strings.attendanceSummary,
          subtitle: fr ? 'Présences, absences et retards cette année.' : 'Present, absent and late days this year.',
        ),
        const SizedBox(height: 12),
        attendance,
        const SizedBox(height: 26),
        PrSectionTitle(
          title: strings.schoolComments,
          subtitle: fr
              ? 'Écrits par les enseignants et approuvés par le Directeur avant d\'apparaître ici.'
              : 'Teachers write these comments, and the Principal approves them before they appear here.',
        ),
        const SizedBox(height: 12),
        PaAsync<List<TeacherComment>>(
          value: commentsAsync,
          strings: strings,
          onRetry: () => ref.invalidate(approvedCommentsProvider(child.studentId)),
          rows: 2,
          rowHeight: 110,
          isEmpty: (l) => l.isEmpty,
          empty: PaEmpty(icon: Icons.chat_bubble_outline_rounded, title: strings.noCommentYet),
          builder: (comments) => Column(children: [
            for (var i = 0; i < comments.length; i++)
              PrReveal(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PrCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        PrAvatar(name: comments[i].teacherName, radius: 15),
                        const SizedBox(width: 10),
                        Expanded(child: Text(comments[i].teacherName, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(comments[i].examPeriodName, style: TextStyle(color: cs.outline, fontSize: 12)),
                      ]),
                      const SizedBox(height: 10),
                      Text(comments[i].comment, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PrReveal(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(v.round().toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

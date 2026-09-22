import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_assignment_detail.dart';
import 'teacher_attendance.dart';
import 'teacher_marks_entry.dart';
import 'teacher_models.dart';
import 'teacher_navigation.dart';
import 'teacher_overview.dart';
import 'teacher_providers.dart';
import 'teacher_strings.dart';
import 'teacher_ui.dart';

/// The dashboard now answers three questions in order: what's happening
/// right now (today's classes), what needs my attention (marks waiting
/// on me), and what am I teaching overall (the class grid). Everything
/// here reads from providers only - no writes happen on this screen,
/// so it is always safe to pull-to-refresh.
class TeacherDashboardTab extends ConsumerWidget {
  final TeacherProfile profile;
  const TeacherDashboardTab({super.key, required this.profile});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(teacherAssignmentsProvider);
    ref.invalidate(teacherTimetableProvider);
    ref.invalidate(teacherClassSizesProvider);
    ref.invalidate(teacherActiveExamPeriodProvider);
    ref.invalidate(teacherMarksProgressProvider);
    ref.invalidate(teacherAttendanceTodayProvider);
    // Give the providers a beat to actually start refetching before the
    // RefreshIndicator's spinner is allowed to stop.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final pad = Responsive.pagePadding(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TeacherPageHeader(
                  title: '${strings.welcomeBack} ${profile.fullName}',
                  subtitle: strings.greetingForHour(DateTime.now().hour),
                ),
                const SizedBox(height: 24),
                assignmentsAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => TeacherErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(teacherAssignmentsProvider),
                  ),
                  data: (assignments) {
                    if (assignments.isEmpty) {
                      return TeacherEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: strings.noAssignmentsTitle,
                        description: strings.noAssignmentsDescription,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TodaysClassesSection(profile: profile, strings: strings),
                        const SizedBox(height: 28),
                        _MarksToDoSection(profile: profile, assignments: assignments, strings: strings),
                        const SizedBox(height: 28),
                        _MyClassesSection(profile: profile, assignments: assignments, strings: strings),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      ),
    );
  }
}

// =========================================================================
// Today's classes
// =========================================================================

class _TodaysClassesSection extends ConsumerWidget {
  final TeacherProfile profile;
  final AppStrings strings;
  const _TodaysClassesSection({required this.profile, required this.strings});

  int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(teacherTimetableProvider);
    final takenAsync = ref.watch(teacherAttendanceTodayProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: strings.tTodaysClasses),
        timetableAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _InlineLoading(),
          error: (e, _) => TeacherErrorView(error: e, onRetry: () => ref.invalidate(teacherTimetableProvider)),
          data: (entries) {
            final now = DateTime.now();
            final today = entries.where((e) => e.dayOfWeek == now.weekday).toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

            if (today.isEmpty) {
              return TeacherCard(
                child: Row(
                  children: [
                    Icon(Icons.beach_access_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(strings.tNoClassesToday)),
                  ],
                ),
              );
            }

            final nowMinutes = now.hour * 60 + now.minute;
            final taken = takenAsync.valueOrNull ?? const <String>{};
            final assignments = assignmentsAsync.valueOrNull ?? const <TeachingAssignment>[];

            return Column(
              children: [
                for (int i = 0; i < today.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TodayClassCard(
                    entry: today[i],
                    isCurrent: nowMinutes >= _minutesOf(today[i].startTime) && nowMinutes < _minutesOf(today[i].endTime),
                    isPast: nowMinutes >= _minutesOf(today[i].endTime),
                    attendanceTaken: taken.contains(
                      assignmentKey(_classIdFor(today[i], assignments), _subjectIdFor(today[i], assignments)),
                    ),
                    matchingAssignment: _assignmentFor(today[i], assignments),
                    profile: profile,
                    strings: strings,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // The timetable entry only carries names (for display), so it's matched
  // back to the teacher's actual assignment (for ids) by subject+class name.
  TeachingAssignment? _assignmentFor(TeacherTimetableEntry entry, List<TeachingAssignment> assignments) {
    for (final a in assignments) {
      if (a.subjectName == entry.subjectName && a.className == entry.className) return a;
    }
    return null;
  }

  String _classIdFor(TeacherTimetableEntry entry, List<TeachingAssignment> assignments) =>
      _assignmentFor(entry, assignments)?.classId ?? '';

  String _subjectIdFor(TeacherTimetableEntry entry, List<TeachingAssignment> assignments) =>
      _assignmentFor(entry, assignments)?.subjectId ?? '';
}

class _TodayClassCard extends StatelessWidget {
  final TeacherTimetableEntry entry;
  final bool isCurrent;
  final bool isPast;
  final bool attendanceTaken;
  final TeachingAssignment? matchingAssignment;
  final TeacherProfile profile;
  final AppStrings strings;

  const _TodayClassCard({
    required this.entry,
    required this.isCurrent,
    required this.isPast,
    required this.attendanceTaken,
    required this.matchingAssignment,
    required this.profile,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = isCurrent ? scheme.primary : scheme.outlineVariant;

    return Consumer(
      builder: (context, ref, _) {
        return TeacherPressable(
          onTap: matchingAssignment == null
              ? null
              : () => pushTeacherContent(
                    ref,
                    TeacherContentPage(
                      title: '${matchingAssignment!.className} - ${strings.attendanceLabel}',
                      builder: (context) =>
                          TeacherAttendancePage(profile: profile, assignment: matchingAssignment!),
                    ),
                  ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 4, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.startTime, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                Text(entry.endTime, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        entry.subjectName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 8),
                                      _badge(theme, strings.tNowLabel, scheme.primary),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.roomName == null || entry.roomName!.isEmpty
                                      ? entry.className
                                      : '${entry.className} · ${entry.roomName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (matchingAssignment != null) _attendanceControl(context, theme, scheme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _attendanceControl(BuildContext context, ThemeData theme, ColorScheme scheme) {
    if (attendanceTaken) {
      return _badge(theme, strings.tAttendanceDone, scheme.tertiary, icon: Icons.check_circle_rounded);
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: null, // the whole card is tappable; this is a visual affordance
      icon: const Icon(Icons.checklist_rounded, size: 16),
      label: Text(strings.tTakeAttendance, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _badge(ThemeData theme, String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
}

// =========================================================================
// Marks to-do
// =========================================================================

class _MarksToDoSection extends ConsumerWidget {
  final TeacherProfile profile;
  final List<TeachingAssignment> assignments;
  final AppStrings strings;
  const _MarksToDoSection({required this.profile, required this.assignments, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = ref.watch(teacherActiveExamPeriodProvider);
    final progressAsync = ref.watch(teacherMarksProgressProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: strings.tMarksToDo),
        periodAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _InlineLoading(),
          error: (e, _) => TeacherErrorView(error: e, onRetry: () => ref.invalidate(teacherActiveExamPeriodProvider)),
          data: (period) {
            if (period == null) {
              return TeacherCard(
                child: Row(
                  children: [
                    Icon(Icons.event_busy_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(strings.tNoOpenPeriod)),
                  ],
                ),
              );
            }

            return progressAsync.when(
              skipLoadingOnReload: true,
              loading: () => const _InlineLoading(),
              error: (e, _) => TeacherErrorView(error: e, onRetry: () => ref.invalidate(teacherMarksProgressProvider)),
              data: (progress) {
                final items = assignments
                    .map((a) => (a, progress[assignmentKey(a.classId, a.subjectId)]))
                    .where((pair) => pair.$2 != null && pair.$2!.needsAction)
                    .toList()
                  ..sort((p1, p2) => _priority(p1.$2!.status).compareTo(_priority(p2.$2!.status)));

                if (items.isEmpty) {
                  return TeacherEmptyState(
                    icon: Icons.task_alt_rounded,
                    title: strings.tMarksAllCaughtUpTitle,
                    description: strings.tMarksAllCaughtUpBody,
                  );
                }

                int? dueInDays;
                if (period.dueDate != null) {
                  final today = DateTime.now();
                  dueInDays = period.dueDate!.difference(DateTime(today.year, today.month, today.day)).inDays;
                }

                return TeacherCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(period.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            if (dueInDays != null)
                              Text(
                                strings.tDueInDays(dueInDays),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: dueInDays < 0
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      for (int i = 0; i < items.length; i++) ...[
                        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        _MarksToDoRow(
                          assignment: items[i].$1,
                          progress: items[i].$2!,
                          profile: profile,
                          strings: strings,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  int _priority(MarksStatus status) {
    switch (status) {
      case MarksStatus.rejected:
        return 0;
      case MarksStatus.draft:
        return 1;
      case MarksStatus.notStarted:
        return 2;
      case MarksStatus.submitted:
      case MarksStatus.approved:
        return 3;
    }
  }
}

class _MarksToDoRow extends StatelessWidget {
  final TeachingAssignment assignment;
  final MarksProgress progress;
  final TeacherProfile profile;
  final AppStrings strings;

  const _MarksToDoRow({required this.assignment, required this.progress, required this.profile, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chip = _chip(theme, scheme);

    return Consumer(
      builder: (context, ref, _) => TeacherPressable(
        onTap: () => pushTeacherContent(
          ref,
          TeacherContentPage(
            title: '${assignment.subjectName} - ${strings.marksLabel}',
            builder: (context) => TeacherMarksEntryPage(profile: profile, assignment: assignment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${assignment.subjectName} · ${assignment.className}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (progress.status == MarksStatus.rejected && progress.feedback != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        progress.feedback!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ] else if (progress.total > 0) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: progress.fraction,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              chip,
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, ColorScheme scheme) {
    Color color;
    String label;
    switch (progress.status) {
      case MarksStatus.rejected:
        color = scheme.error;
        label = strings.tStatusRejected;
        break;
      case MarksStatus.draft:
        color = scheme.primary;
        label = strings.tMarksProgress(progress.entered, progress.total);
        break;
      case MarksStatus.notStarted:
        color = scheme.onSurfaceVariant;
        label = strings.tMarksStatusNotStarted;
        break;
      case MarksStatus.submitted:
        color = scheme.primary;
        label = strings.tStatusSubmitted;
        break;
      case MarksStatus.approved:
        color = scheme.tertiary;
        label = strings.tStatusApproved;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// =========================================================================
// My classes
// =========================================================================

class _MyClassesSection extends ConsumerWidget {
  final TeacherProfile profile;
  final List<TeachingAssignment> assignments;
  final AppStrings strings;
  const _MyClassesSection({required this.profile, required this.assignments, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizesAsync = ref.watch(teacherClassSizesProvider);
    final progressAsync = ref.watch(teacherMarksProgressProvider);
    final sizes = sizesAsync.valueOrNull ?? const <String, int>{};
    final progress = progressAsync.valueOrNull ?? const <String, MarksProgress>{};

    // Two columns once there's room for it AND enough cards that one
    // column would leave a lot of empty space below the fold; a single
    // very wide card for one or two assignments reads better than a
    // half-empty grid.
    final isMobile = Responsive.isMobile(context);
    final columns = (!isMobile && assignments.length > 1) ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: strings.tMyClasses),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 5.2 : 2.7,
          ),
          itemCount: assignments.length,
          itemBuilder: (context, i) {
            final a = assignments[i];
            return _ClassCard(
              profile: profile,
              assignment: a,
              studentCount: sizes[a.classId],
              progress: progress[assignmentKey(a.classId, a.subjectId)],
              strings: strings,
            );
          },
        ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;
  final int? studentCount;
  final MarksProgress? progress;
  final AppStrings strings;

  const _ClassCard({
    required this.profile,
    required this.assignment,
    required this.studentCount,
    required this.progress,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Consumer(
      builder: (context, ref, _) => TeacherPressable(
        onTap: () => pushTeacherContent(
          ref,
          TeacherContentPage(
            title: assignment.className,
            builder: (context) => TeacherAssignmentDetailPage(profile: profile, assignment: assignment),
          ),
        ),
        child: TeacherCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_outlined, color: scheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(assignment.subjectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      studentCount == null
                          ? assignment.className
                          : '${assignment.className} · ${strings.tStudentsCount(studentCount!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (progress != null && progress!.needsAction) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: progress!.status == MarksStatus.rejected ? scheme.error : scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

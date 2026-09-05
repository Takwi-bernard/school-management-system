import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_assignment_detail.dart';
import 'teacher_models.dart';
import 'teacher_navigation.dart';
import 'teacher_providers.dart';
import 'teacher_ui.dart';

class TeacherDashboardTab extends ConsumerWidget {
  final TeacherProfile profile;
  const TeacherDashboardTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final isMobile = Responsive.isMobile(context);
    final pad = Responsive.pagePadding(context);
    final statColumns = isMobile ? 2 : 3;

    return SafeArea(
      child: SingleChildScrollView(
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
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Center(child: Text('$e')),
                data: (assignments) {
                  final subjectCount = assignments.map((a) => a.subjectId).toSet().length;
                  final classCount = assignments.map((a) => a.classId).toSet().length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: statColumns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isMobile ? 1.6 : 2.6,
                        children: [
                          TeacherStatCard(
                            icon: Icons.menu_book_outlined,
                            tint: theme.colorScheme.primary,
                            value: '$subjectCount',
                            label: strings.subjectsLabel,
                          ),
                          TeacherStatCard(
                            icon: Icons.class_outlined,
                            tint: theme.colorScheme.secondary,
                            value: '$classCount',
                            label: strings.classesLabel,
                          ),
                          TeacherStatCard(
                            icon: Icons.assignment_outlined,
                            tint: theme.colorScheme.tertiary,
                            value: '${assignments.length}',
                            label: strings.assignmentsLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(strings.myTeaching, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      if (assignments.isEmpty)
                        TeacherEmptyState(
                          icon: Icons.assignment_late_outlined,
                          title: strings.noAssignmentsTitle,
                          description: strings.noAssignmentsDescription,
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assignments.length,
                          // 2 columns at every breakpoint now (was 1 on
                          // mobile) - the card content below switches to a
                          // compact vertical layout on mobile instead of
                          // just shrinking the old horizontal row into a
                          // too-narrow box.
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: isMobile ? 1.05 : 3.4,
                          ),
                          itemBuilder: (context, i) {
                            final a = assignments[i];
                            return TeacherCard(
                              padding: EdgeInsets.zero,
                              child: TeacherPressable(
                                onTap: () => pushTeacherContent(
                                  ref,
                                  TeacherContentPage(
                                    title: a.subjectName,
                                    builder: (context) => TeacherAssignmentDetailPage(profile: profile, assignment: a),
                                  ),
                                ),
                                child: isMobile
                                    ? _CompactAssignmentCard(a: a, strings: strings)
                                    : _RowAssignmentCard(a: a, strings: strings),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop/tablet: icon + name/class + coefficient + chevron, all in
/// one row - there's room for it at 2 columns on wider screens.
class _RowAssignmentCard extends StatelessWidget {
  final TeachingAssignment a;
  final AppStrings strings;
  const _RowAssignmentCard({required this.a, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.subjectName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(a.className, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
        Text('${strings.coefficientShort} ${a.coefficient}',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.outline),
      ]),
    );
  }
}

/// Mobile, 2 per row: a narrow (~150px) card can't fit the row layout
/// above without truncating everything, so this stacks icon on top,
/// subject/class below, coefficient tucked into a small bottom row -
/// same information, laid out for the width it actually has.
class _CompactAssignmentCard extends StatelessWidget {
  final TeachingAssignment a;
  final AppStrings strings;
  const _CompactAssignmentCard({required this.a, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary, size: 17),
          ),
          const SizedBox(height: 10),
          Text(a.subjectName,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(a.className,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Row(children: [
            Text('${strings.coefficientShort} ${a.coefficient}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.outline),
          ]),
        ],
      ),
    );
  }
}
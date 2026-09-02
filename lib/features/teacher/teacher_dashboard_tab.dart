import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_assignment_detail.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

class TeacherDashboardTab extends ConsumerWidget {
  final TeacherProfile profile;
  const TeacherDashboardTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final assignmentColumns = isMobile ? 1 : 2;
    final pad = Responsive.pagePadding(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
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
                    Text(strings.welcomeBack, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                    Text(profile.fullName,
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
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
                    RevealOnScroll(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isMobile ? 0.95 : (isTablet ? 1.3 : 1.6),
                        children: [
                          _StatCard(icon: Icons.menu_book_outlined, label: strings.subjectsLabel, value: '$subjectCount'),
                          _StatCard(icon: Icons.class_outlined, label: strings.classesLabel, value: '$classCount'),
                          _StatCard(icon: Icons.assignment_outlined, label: strings.assignmentsLabel, value: '${assignments.length}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(strings.myTeaching, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    if (assignments.isEmpty)
                      RevealOnScroll(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                              child: Icon(Icons.assignment_late_outlined, size: 30, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(strings.noAssignmentsTitle,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                              strings.noAssignmentsDescription,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ]),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: assignments.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: assignmentColumns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isMobile ? 3.4 : 3.0,
                        ),
                        itemBuilder: (context, i) {
                          final a = assignments[i];
                          return RevealOnScroll(
                            delay: Duration(milliseconds: i * 60),
                            child: HoverLift(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TeacherAssignmentDetailPage(profile: profile, assignment: a)),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.menu_book_outlined, color: theme.colorScheme.onPrimary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(a.subjectName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      Text(a.className, style: theme.textTheme.bodySmall),
                                    ]),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                                    child: Text('${strings.coefficientShort} ${a.coefficient}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                ]),
                              ),
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
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
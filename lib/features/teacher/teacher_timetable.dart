import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';
import 'teacher_ui.dart';

/// Shell tab, not its own pushed page. Kept single-column even on
/// wide screens on purpose: day cards have variable height (1 period
/// some days, 6+ on others), so a fixed-aspect-ratio grid would clip
/// a busy day or leave gaps under a light one - centering with a
/// max-width gives a focused desktop read without that risk.
class TeacherTimetableTab extends ConsumerWidget {
  const TeacherTimetableTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final timetableAsync = ref.watch(teacherTimetableProvider);
    final days = strings.weekdays;
    final pad = Responsive.pagePadding(context);

    return SafeArea(
      child: timetableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TeacherPageHeader(title: strings.myTimetable),
                      const SizedBox(height: 20),
                      TeacherEmptyState(
                        icon: Icons.event_busy_outlined,
                        title: strings.myTimetable,
                        description: strings.timetableEmpty,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final grouped = <int, List<TeacherTimetableEntry>>{};
          for (final e in entries) {
            grouped.putIfAbsent(e.dayOfWeek, () => []).add(e);
          }
          final sortedDays = grouped.keys.toList()..sort();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
                children: [
                  TeacherPageHeader(title: strings.myTimetable),
                  const SizedBox(height: 20),
                  for (final day in sortedDays)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TeacherCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                              child: Text(days[day], style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                            for (final item in grouped[day]!)
                              ListTile(
                                dense: false,
                                leading: Container(
                                  width: 56,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(item.startTime,
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: theme.colorScheme.primary)),
                                      Text(item.endTime,
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                                    ],
                                  ),
                                ),
                                title: Text(item.subjectName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(item.className + (item.roomName != null ? ' · ${item.roomName}' : '')),
                              ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
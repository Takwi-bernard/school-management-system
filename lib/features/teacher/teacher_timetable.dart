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
///
/// The schedule itself is a weekly recurring pattern (dayOfWeek 1-7),
/// so "today's classes" is computed fresh from the device clock on
/// every render rather than stored - there's nothing to mark as
/// "done" in the data, the SAME Monday slot just stops being "today"
/// the moment it's no longer Monday, and starts being "in 6 days"
/// instead. That's what makes this feel alive instead of a static
/// weekly dump: reopen the tab tomorrow and "Up Next" has already
/// moved on by itself.
class TeacherTimetableTab extends ConsumerWidget {
  const TeacherTimetableTab({super.key});

  int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

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

          final now = DateTime.now();
          final todayWeekday = now.weekday; // 1=Mon..7=Sun, matches dayOfWeek
          final nowMinutes = now.hour * 60 + now.minute;

          // Today's classes that haven't ENDED yet (not just "today" -
          // a period that finished this morning shouldn't still be
          // billed as "up next" at 4pm).
          final remainingToday = (grouped[todayWeekday] ?? [])
              .where((e) => _minutesOf(e.endTime) > nowMinutes)
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          List<TeacherTimetableEntry> upNext = remainingToday;
          int upNextDay = todayWeekday;
          String upNextLabel = strings.todayLabel;

          if (upNext.isEmpty) {
            // Roll forward to the next day (tomorrow, then the day
            // after, ...) that actually has something scheduled -
            // wraps the week automatically.
            for (int offset = 1; offset <= 7; offset++) {
              final candidate = ((todayWeekday - 1 + offset) % 7) + 1;
              final candidateEntries = grouped[candidate] ?? [];
              if (candidateEntries.isNotEmpty) {
                upNext = List.of(candidateEntries)..sort((a, b) => a.startTime.compareTo(b.startTime));
                upNextDay = candidate;
                upNextLabel = offset == 1 ? strings.tomorrowLabel : days[candidate];
                break;
              }
            }
          }

          // Everything else, in chronological order starting from
          // today and wrapping the week - NOT alphabetical/Monday-
          // first, so the reference list below reads as "what's
          // coming after that" rather than a random-feeling dump.
          final restOfWeek = <int>[];
          for (int offset = 0; offset <= 6; offset++) {
            final candidate = ((todayWeekday - 1 + offset) % 7) + 1;
            if (candidate == upNextDay) continue;
            if ((grouped[candidate] ?? []).isNotEmpty) restOfWeek.add(candidate);
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
                children: [
                  TeacherPageHeader(title: strings.myTimetable),
                  const SizedBox(height: 20),
                  Text(strings.upNextLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (upNext.isEmpty)
                    TeacherEmptyState(
                      icon: Icons.event_available_outlined,
                      title: strings.upNextLabel,
                      description: strings.noUpcomingClasses,
                    )
                  else
                    _DayCard(
                      theme: theme,
                      label: upNextLabel,
                      highlighted: true,
                      entries: upNext,
                    ),
                  if (restOfWeek.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(strings.fullWeekLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    for (final day in restOfWeek)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DayCard(theme: theme, label: days[day], entries: grouped[day]!),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final List<TeacherTimetableEntry> entries;
  final bool highlighted;

  const _DayCard({required this.theme, required this.label, required this.entries, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return TeacherCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(children: [
              Text(label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highlighted ? theme.colorScheme.primary : null,
                  )),
              if (highlighted) ...[
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                ),
              ],
            ]),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          for (final item in entries)
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
                    Text(item.endTime, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
              title: Text(item.subjectName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(item.className + (item.roomName != null ? ' · ${item.roomName}' : '')),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

class TeacherTimetablePage extends ConsumerWidget {
  const TeacherTimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final timetableAsync = ref.watch(teacherTimetableProvider);
    final days = strings.weekdays;

    return Scaffold(
      appBar: AppBar(title: Text(strings.myTimetable)),
      body: timetableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_busy_outlined, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(strings.timetableEmpty, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                ]),
              ),
            );
          }

          final grouped = <int, List<TeacherTimetableEntry>>{};
          for (final e in entries) {
            grouped.putIfAbsent(e.dayOfWeek, () => []).add(e);
          }

          final sortedDays = grouped.keys.toList()..sort();

          return ListView(
            padding: EdgeInsets.all(Responsive.pagePadding(context)),
            children: [
              for (int idx = 0; idx < sortedDays.length; idx++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: RevealOnScroll(
                    delay: Duration(milliseconds: idx * 60),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                            ),
                            child: Text(days[sortedDays[idx]],
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                          for (final item in grouped[sortedDays[idx]]!)
                            ListTile(
                              leading: Container(
                                width: 58,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item.startTime, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                    Text(item.endTime, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              title: Text(item.subjectName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(item.className + (item.roomName != null ? ' · ${item.roomName}' : '')),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

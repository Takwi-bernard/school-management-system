import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

const _days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class TeacherTimetablePage extends ConsumerWidget {
  const TeacherTimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timetableAsync = ref.watch(teacherTimetableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Timetable')),
      body: timetableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Your timetable has not been configured yet.'));
          }

          final grouped = <int, List<TeacherTimetableEntry>>{};
          for (final e in entries) {
            grouped.putIfAbsent(e.dayOfWeek, () => []).add(e);
          }

          return ListView(
            padding: EdgeInsets.all(Responsive.pagePadding(context)),
            children: [
              for (final day in grouped.keys.toList()..sort())
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Text(_days[day], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        for (final item in grouped[day]!)
                          ListTile(
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.startTime, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(item.endTime, style: theme.textTheme.bodySmall),
                              ],
                            ),
                            title: Text(item.subjectName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(item.className + (item.roomName != null ? ' · ${item.roomName}' : '')),
                          ),
                      ],
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

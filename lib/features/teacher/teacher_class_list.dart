import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import 'teacher_models.dart';
import 'teacher_providers.dart';

class TeacherClassListPage extends ConsumerWidget {
  final TeacherProfile profile;
  final TeachingAssignment assignment;

  const TeacherClassListPage({super.key, required this.profile, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rosterAsync = ref.watch(
      rosterProvider((classId: assignment.classId, academicYearId: assignment.academicYearId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${assignment.className} - Class List'),
        actions: [
          // Export implementation intentionally deferred (needs an
          // xlsx/pdf package decision) - buttons wired to a clear
          // "not available yet" message rather than a silent no-op.
          IconButton(
            icon: const Icon(Icons.table_view_outlined),
            tooltip: 'Export Excel',
            onPressed: () => _notReady(context),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () => _notReady(context),
          ),
        ],
      ),
      body: rosterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (students) {
          if (students.isEmpty) {
            return const Center(child: Text('No students enrolled in this class yet.'));
          }
          return Padding(
            padding: EdgeInsets.all(Responsive.pagePadding(context)),
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = students[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Text('${i + 1}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 14),
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null,
                      child: s.photoUrl == null ? const Icon(Icons.person_outline) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.fullName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(s.admissionNumber, style: theme.textTheme.bodySmall),
                      ]),
                    ),
                    Text(s.gender, style: theme.textTheme.bodySmall),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export is not available yet - coming in a future update.')),
    );
  }
}

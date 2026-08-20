import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_providers.dart';
import 'teacher_models.dart';
import 'teacher_repository.dart';

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository(ref.watch(supabaseClientProvider));
});

final teacherProfileProvider = FutureProvider<TeacherProfile?>((ref) {
  return ref.watch(teacherRepositoryProvider).getProfile();
});

final teacherAssignmentsProvider = FutureProvider<List<TeachingAssignment>>((ref) async {
  final profile = await ref.watch(teacherProfileProvider.future);
  if (profile == null || !profile.isApproved) return [];
  return ref.watch(teacherRepositoryProvider).getAssignments(profile);
});

final teacherTimetableProvider = FutureProvider<List<TeacherTimetableEntry>>((ref) async {
  final profile = await ref.watch(teacherProfileProvider.future);
  if (profile == null || !profile.isApproved) return [];
  return ref.watch(teacherRepositoryProvider).getTimetable(profile);
});

/// Roster for one specific assignment - family-keyed so each
/// class/year combination is cached independently.
final rosterProvider = FutureProvider.family<List<RosterStudent>, ({String classId, String academicYearId})>(
  (ref, params) {
    return ref
        .watch(teacherRepositoryProvider)
        .getRoster(classId: params.classId, academicYearId: params.academicYearId);
  },
);

final examPeriodsProvider = FutureProvider<List<ExamPeriod>>((ref) async {
  final profile = await ref.watch(teacherProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(teacherRepositoryProvider).getExamPeriods(profile.schoolId);
});

final marksProvider = FutureProvider.family<List<MarkEntry>, ({String classId, String subjectId})>(
  (ref, params) {
    return ref
        .watch(teacherRepositoryProvider)
        .getMarks(classId: params.classId, subjectId: params.subjectId);
  },
);

final attendanceForDateProvider = FutureProvider.family<
    List<AttendanceEntry>,
    ({String classId, String subjectId, DateTime date})>((ref, params) {
  return ref.watch(teacherRepositoryProvider).getAttendance(
        classId: params.classId,
        subjectId: params.subjectId,
        date: params.date,
      );
});

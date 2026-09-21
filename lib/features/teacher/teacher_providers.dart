import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_providers.dart';
import '../auth/auth_gate.dart' show authStateChangesProvider;
import 'teacher_models.dart';
import 'teacher_repository.dart';

/// The id of whoever is signed in right now (null when signed out).
///
/// Every teacher provider below depends on this, so when a different
/// person signs in on the same browser tab, all cached teacher data
/// (profile, assignments, rosters, marks, attendance, open screens) is
/// discarded instead of leaking from the previous user. A Provider only
/// notifies its dependents when its VALUE changes, so a token refresh
/// for the same user does not reset anything.
final teacherUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository(ref.watch(supabaseClientProvider));
});

final teacherProfileProvider = FutureProvider<TeacherProfile?>((ref) {
  ref.watch(teacherUserIdProvider);
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
    ref.watch(teacherUserIdProvider);
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

final marksProvider = FutureProvider.family<List<MarkEntry>,
    ({String classId, String subjectId, String academicYearId})>(
  (ref, params) {
    ref.watch(teacherUserIdProvider);
    return ref.watch(teacherRepositoryProvider).getMarks(
          classId: params.classId,
          subjectId: params.subjectId,
          academicYearId: params.academicYearId,
        );
  },
);

final attendanceForDateProvider = FutureProvider.family<
    List<AttendanceEntry>,
    ({String classId, String subjectId, DateTime date})>((ref, params) {
  ref.watch(teacherUserIdProvider);
  return ref.watch(teacherRepositoryProvider).getAttendance(
        classId: params.classId,
        subjectId: params.subjectId,
        date: params.date,
      );
});

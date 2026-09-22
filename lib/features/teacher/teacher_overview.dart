import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'teacher_models.dart';
import 'teacher_providers.dart';
import 'teacher_repository.dart';

/// Everything the dashboard needs beyond the plain list of assignments:
/// class sizes, marks progress for the open exam period, and which
/// classes already had attendance taken today. Kept in its own file so
/// the core repository/providers stay small.

enum MarksStatus { notStarted, draft, submitted, approved, rejected }

class MarksProgress {
  final MarksStatus status;

  /// Students that already have a score saved for this period.
  final int entered;

  /// Students enrolled in the class (0 if it could not be read).
  final int total;

  /// The principal's comment when the marks were rejected.
  final String? feedback;

  const MarksProgress({
    required this.status,
    required this.entered,
    required this.total,
    this.feedback,
  });

  double get fraction => total <= 0 ? 0 : (entered / total).clamp(0.0, 1.0).toDouble();

  /// Needs the teacher to do something.
  bool get needsAction =>
      status == MarksStatus.notStarted || status == MarksStatus.draft || status == MarksStatus.rejected;
}

/// "classId|subjectId" - one key per teaching assignment.
String assignmentKey(String classId, String subjectId) => '$classId|$subjectId';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

extension TeacherOverviewQueries on TeacherRepository {
  /// Active enrolled students per class.
  Future<Map<String, int>> getClassSizes({
    required List<String> classIds,
    required String academicYearId,
  }) async {
    if (classIds.isEmpty) return {};
    final rows = await client
        .from('class_enrollments')
        .select('class_id')
        .inFilter('class_id', classIds)
        .eq('academic_year_id', academicYearId)
        .eq('enrollment_status', 'active');

    final sizes = <String, int>{};
    for (final row in rows) {
      final id = row['class_id'] as String?;
      if (id != null) sizes[id] = (sizes[id] ?? 0) + 1;
    }
    return sizes;
  }

  /// One row per saved mark for the period (RLS already limits this to
  /// the teacher's own class + subject pairs).
  Future<List<Map<String, dynamic>>> getMarkStatusRows({
    required String examPeriodId,
    required List<String> classIds,
  }) async {
    if (classIds.isEmpty) return [];
    final rows = await client
        .from('marks')
        .select('class_id, subject_id, status, principal_feedback')
        .eq('exam_period_id', examPeriodId)
        .inFilter('class_id', classIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// "classId|subjectId" pairs that have at least one attendance record today.
  Future<Set<String>> getAttendanceTakenOn({
    required DateTime date,
    required List<String> classIds,
    required String academicYearId,
  }) async {
    if (classIds.isEmpty) return {};
    final rows = await client
        .from('attendance')
        .select('class_id, subject_id')
        .eq('attendance_date', _isoDate(date))
        .eq('academic_year_id', academicYearId)
        .inFilter('class_id', classIds);

    final taken = <String>{};
    for (final row in rows) {
      final classId = row['class_id'] as String?;
      final subjectId = row['subject_id'] as String?;
      if (classId != null && subjectId != null) taken.add(assignmentKey(classId, subjectId));
    }
    return taken;
  }
}

final teacherClassSizesProvider = FutureProvider<Map<String, int>>((ref) async {
  final assignments = await ref.watch(teacherAssignmentsProvider.future);
  if (assignments.isEmpty) return {};
  return ref.watch(teacherRepositoryProvider).getClassSizes(
        classIds: assignments.map((a) => a.classId).toSet().toList(),
        academicYearId: assignments.first.academicYearId,
      );
});

/// The exam period the dashboard reports on: the first OPEN one (in
/// sequence order) of the current academic year, or null if none is open.
final teacherActiveExamPeriodProvider = FutureProvider<ExamPeriod?>((ref) async {
  final periods = await ref.watch(examPeriodsProvider.future);
  for (final period in periods) {
    if (period.isOpen) return period;
  }
  return null;
});

final teacherMarksProgressProvider = FutureProvider<Map<String, MarksProgress>>((ref) async {
  final period = await ref.watch(teacherActiveExamPeriodProvider.future);
  if (period == null) return {};
  final assignments = await ref.watch(teacherAssignmentsProvider.future);
  if (assignments.isEmpty) return {};
  final sizes = await ref.watch(teacherClassSizesProvider.future);

  final rows = await ref.watch(teacherRepositoryProvider).getMarkStatusRows(
        examPeriodId: period.id,
        classIds: assignments.map((a) => a.classId).toSet().toList(),
      );

  final byAssignment = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final classId = row['class_id'] as String?;
    final subjectId = row['subject_id'] as String?;
    if (classId == null || subjectId == null) continue;
    byAssignment.putIfAbsent(assignmentKey(classId, subjectId), () => []).add(row);
  }

  final result = <String, MarksProgress>{};
  for (final a in assignments) {
    final key = assignmentKey(a.classId, a.subjectId);
    final marks = byAssignment[key] ?? const <Map<String, dynamic>>[];
    final total = sizes[a.classId] ?? 0;
    final entered = marks.length;

    var hasDraft = false;
    var hasRejected = false;
    var allApproved = marks.isNotEmpty;
    String? feedback;
    for (final m in marks) {
      final markStatus = m['status'] as String? ?? 'draft';
      if (markStatus == 'draft') hasDraft = true;
      if (markStatus == 'rejected') {
        hasRejected = true;
        final text = (m['principal_feedback'] as String?)?.trim();
        if (feedback == null && text != null && text.isNotEmpty) feedback = text;
      }
      if (markStatus != 'approved') allApproved = false;
    }

    MarksStatus status;
    if (entered == 0) {
      status = MarksStatus.notStarted;
    } else if (hasRejected) {
      status = MarksStatus.rejected;
    } else if (allApproved && (total == 0 || entered >= total)) {
      status = MarksStatus.approved;
    } else if (!hasDraft && (total == 0 || entered >= total)) {
      status = MarksStatus.submitted;
    } else {
      status = MarksStatus.draft;
    }

    result[key] = MarksProgress(status: status, entered: entered, total: total, feedback: feedback);
  }
  return result;
});

final teacherAttendanceTodayProvider = FutureProvider<Set<String>>((ref) async {
  final assignments = await ref.watch(teacherAssignmentsProvider.future);
  if (assignments.isEmpty) return {};
  final now = DateTime.now();
  return ref.watch(teacherRepositoryProvider).getAttendanceTakenOn(
        date: DateTime(now.year, now.month, now.day),
        classIds: assignments.map((a) => a.classId).toSet().toList(),
        academicYearId: assignments.first.academicYearId,
      );
});

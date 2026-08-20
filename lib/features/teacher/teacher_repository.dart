import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_models.dart';

/// Single gateway between the Teacher UI and Supabase. RLS (Migration
/// 021) is the real security boundary - every query here trusts RLS
/// to scope results to the authenticated teacher, but queries are
/// still written to filter explicitly where practical (defense in
/// depth, and to avoid over-fetching).
class TeacherRepository {
  final SupabaseClient client;
  const TeacherRepository(this.client);

  Future<TeacherProfile?> getProfile() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await client.from('teachers').select().eq('user_id', uid).maybeSingle();
    if (row == null) return null;
    return TeacherProfile.fromMap(row);
  }

  Future<String?> _currentAcademicYearId(String schoolId) async {
    final row = await client
        .from('academic_years')
        .select('id')
        .eq('school_id', schoolId)
        .eq('is_current', true)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<List<TeachingAssignment>> getAssignments(TeacherProfile profile) async {
    final yearId = await _currentAcademicYearId(profile.schoolId);
    if (yearId == null) return [];

    final rows = await client
        .from('teacher_assignments')
        .select('*, subjects(subject_name), classes(class_name, department_id)')
        .eq('teacher_id', profile.teacherId)
        .eq('academic_year_id', yearId);

    if (rows.isEmpty) return [];

    // Resolve coefficients via subject_departments (subject_id +
    // department_id) - NOT a column on teacher_assignments.
    final pairs = <(String, String)>{
      for (final r in rows)
        (r['subject_id'] as String, (r['classes'] as Map)['department_id'] as String)
    };
    final subjectIds = pairs.map((p) => p.$1).toSet().toList();
    final coeffRows = await client
        .from('subject_departments')
        .select('subject_id, department_id, coefficient')
        .inFilter('subject_id', subjectIds);

    int coefficientFor(String subjectId, String departmentId) {
      for (final c in coeffRows) {
        if (c['subject_id'] == subjectId && c['department_id'] == departmentId) {
          return (c['coefficient'] as num).toInt();
        }
      }
      return 1;
    }

    return rows.map((r) {
      final departmentId = (r['classes'] as Map)['department_id'] as String;
      return TeachingAssignment.fromMap({
        ...r,
        '_coefficient': coefficientFor(r['subject_id'] as String, departmentId),
      });
    }).toList();
  }

  Future<List<RosterStudent>> getRoster({
    required String classId,
    required String academicYearId,
  }) async {
    final rows = await client
        .from('class_enrollments')
        .select('students(*)')
        .eq('class_id', classId)
        .eq('academic_year_id', academicYearId)
        .eq('enrollment_status', 'active');

    return rows.map((r) => RosterStudent.fromMap(r)).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<List<ExamPeriod>> getExamPeriods(String schoolId) async {
    final rows = await client
        .from('exam_periods')
        .select()
        .eq('school_id', schoolId)
        .order('sequence_order');
    return rows.map((r) => ExamPeriod.fromMap(r)).toList();
  }

  /// Marks for one class+subject across ALL exam periods, so the UI
  /// can show previous-sequence history alongside the current one.
  Future<List<MarkEntry>> getMarks({
    required String classId,
    required String subjectId,
  }) async {
    final rows = await client
        .from('marks')
        .select()
        .eq('class_id', classId)
        .eq('subject_id', subjectId);
    return rows.map((r) => MarkEntry.fromMap(r)).toList();
  }

  /// Upserts marks for the CURRENT exam period only. school_id and
  /// coefficient are auto-populated by the database trigger
  /// (Migration 005) - never sent from the client.
  Future<void> saveMarks({
    required TeacherProfile profile,
    required String examPeriodId,
    required String academicYearId,
    required List<MarkEntry> entries,
    required String status, // 'draft' or 'submitted'
  }) async {
    final rows = entries
        .map((e) => {
              'student_id': e.studentId,
              'subject_id': e.subjectId,
              'class_id': e.classId,
              'exam_period_id': examPeriodId,
              'academic_year_id': academicYearId,
              'teacher_id': profile.teacherId,
              'score': e.score,
              'status': status,
              'remarks': e.remarks,
            })
        .toList();

    await client.from('marks').upsert(rows, onConflict: 'student_id,subject_id,exam_period_id');
  }

  Future<List<AttendanceEntry>> getAttendance({
    required String classId,
    required String subjectId,
    required DateTime date,
  }) async {
    final dateStr = _dateOnly(date);
    final rows = await client
        .from('attendance')
        .select()
        .eq('class_id', classId)
        .eq('subject_id', subjectId)
        .eq('attendance_date', dateStr);

    return rows
        .map((r) => AttendanceEntry(
              studentId: r['student_id'] as String,
              date: date,
              status: r['status'] as String,
              remarks: r['remarks'] as String?,
            ))
        .toList();
  }

  Future<void> saveAttendance({
    required TeacherProfile profile,
    required String classId,
    required String subjectId,
    required String academicYearId,
    required List<AttendanceEntry> entries,
  }) async {
    final rows = entries
        .map((e) => {
              'student_id': e.studentId,
              'class_id': classId,
              'subject_id': subjectId,
              'academic_year_id': academicYearId,
              'attendance_date': _dateOnly(e.date),
              'status': e.status,
              'remarks': e.remarks,
              'recorded_by': profile.userId,
            })
        .toList();

    await client
        .from('attendance')
        .upsert(rows, onConflict: 'student_id,attendance_date,subject_id');
  }

  Future<List<TeacherTimetableEntry>> getTimetable(TeacherProfile profile) async {
    final rows = await client
        .from('timetable_items')
        .select(
            '*, teacher_assignments!inner(teacher_id, subjects(subject_name), classes(class_name))')
        .eq('teacher_assignments.teacher_id', profile.teacherId);

    return rows.map((r) => TeacherTimetableEntry.fromMap(r)).toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        return day != 0 ? day : a.startTime.compareTo(b.startTime);
      });
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

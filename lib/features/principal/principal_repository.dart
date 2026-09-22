import 'package:supabase_flutter/supabase_flutter.dart';
import 'principal_models.dart';
import 'dart:typed_data';
class PrincipalRepository {
  PrincipalRepository(this._client);
  final SupabaseClient _client;

  Future<PrincipalProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client.from('principals').select().eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    return PrincipalProfile.fromMap(row);
  }

// --------------------------------------------------
  // ACADEMIC YEARS
   // --------------------------------------------------
  Future<String?> getCurrentAcademicYearId(String schoolId) async {
    final row = await _client
        .from('academic_years')
        .select('id')
        .eq('school_id', schoolId)
        .eq('is_current', true)
        .maybeSingle();
    return row?['id'] as String?;
  }



  // --------------------------------------------------
  // TEACHER APPROVAL
  // --------------------------------------------------

  Future<List<PendingTeacher>> getPendingTeachers(String schoolId) async {
    final rows = await _client
        .from('teachers')
        .select('id, user_id, full_name, phone, created_at, users(email)')
        .eq('school_id', schoolId)
        .eq('is_approved', false)
        .order('created_at');
    return rows.map((r) => PendingTeacher.fromMap(r)).toList();
  }

  Future<void> approveTeacher(String teacherId, String principalId) async {
    await _client.from('teachers').update({
      'is_approved': true,
      'approval_status': 'approved',
      'approved_by': principalId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', teacherId);
  }

  Future<void> rejectTeacher(String teacherId, String principalId) async {
    await _client.from('teachers').update({
      'is_approved': false,
      'approval_status': 'rejected',
      'approved_by': principalId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', teacherId);
  }

  // --------------------------------------------------
  // APPROVED TEACHERS + ASSIGNMENTS
  // --------------------------------------------------

  Future<List<ApprovedTeacher>> getApprovedTeachers(String schoolId) async {
    final rows = await _client
        .from('teachers')
        .select('id, full_name, phone, teacher_assignments(id)')
        .eq('school_id', schoolId)
        .eq('is_approved', true)
        .order('full_name');

    return rows
        .map((r) => ApprovedTeacher(
              teacherId: r['id'] as String,
              fullName: r['full_name'] as String? ?? '',
              phone: r['phone'] as String?,
              assignmentCount: (r['teacher_assignments'] as List).length,
            ))
        .toList();
  }
// --------------------------------------------------
  // TEACHER ASSIGNMENTS
  // --------------------------------------------------
  Future<List<TeacherAssignmentInfo>> getAssignmentsForTeacher(String teacherId, String academicYearId) async {
    final rows = await _client
        .from('teacher_assignments')
        .select('id, periods_per_week, classes(class_name), subjects(subject_name)')
        .eq('teacher_id', teacherId)
        .eq('academic_year_id', academicYearId);
    return rows.map((r) => TeacherAssignmentInfo.fromMap(r)).toList();
  }

    Future<void> createAssignment({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
    required String classId,
    required String subjectId,
    required int periodsPerWeek,
    List<int>? preferredDays,
    String? preferredStartTime,
    String? preferredEndTime,
  }) async {
    final inserted = await _client
        .from('teacher_assignments')
        .insert({
          'school_id': schoolId,
          'academic_year_id': academicYearId,
          'teacher_id': teacherId,
          'class_id': classId,
          'subject_id': subjectId,
          'periods_per_week': periodsPerWeek,
        })
        .select()
        .single();

    // One preference row per selected day - the schema already
    // supports this, the old UI just never let a teacher pick more
    // than one at a time.
    if (preferredDays != null && preferredDays.isNotEmpty) {
      await _client.from('teacher_period_preferences').insert([
        for (final day in preferredDays)
          {
            'school_id': schoolId,
            'teacher_assignment_id': inserted['id'],
            'preferred_day': day,
            'preferred_start_time': preferredStartTime,
            'preferred_end_time': preferredEndTime,
          },
      ]);
    }
  }

  Future<void> approveAndAssign({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
    required bool wasAlreadyApproved,
    required String principalId,
    required String classId,
    required String subjectId,
    required int periodsPerWeek,
    List<int>? preferredDays,
    String? preferredStartTime,
    String? preferredEndTime,
  }) async {
    if (!wasAlreadyApproved) {
      await approveTeacher(teacherId, principalId);
    }
    await createAssignment(
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
      classId: classId,
      subjectId: subjectId,
      periodsPerWeek: periodsPerWeek,
      preferredDays: preferredDays,
      preferredStartTime: preferredStartTime,
      preferredEndTime: preferredEndTime,
    );
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _client.from('teacher_assignments').delete().eq('id', assignmentId);
  }

    // --------------------------------------------------
  // AI TIMETABLE GENERATION
  // --------------------------------------------------

  Future<Map<String, dynamic>> generateTimetable({
    required String schoolId,
    required String scopeType, // 'school' | 'department' | 'class'
    String? departmentId,
    String? classId,
    String? principalNote,
  }) async {
    final response = await _client.functions.invoke('generate-timetable', body: {
      'school_id': schoolId,
      'scope_type': scopeType,
      if (departmentId != null) 'department_id': departmentId,
      if (classId != null) 'class_id': classId,
      if (principalNote != null && principalNote.trim().isNotEmpty) 'principal_note': principalNote.trim(),
    });

    final data = response.data as Map;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Timetable generation failed.');
    }
    return Map<String, dynamic>.from(data);
  }



  Future<List<TimetableGenerationRecord>> getTimetableGenerationHistory(String schoolId) async {
    final rows = await _client
        .from('timetable_generations')
        .select('*, classes(class_name), departments(department_name)')
        .eq('school_id', schoolId)
        .order('generated_at', ascending: false);
    return rows.map((r) => TimetableGenerationRecord.fromMap(r)).toList();
  }
  Future<List<TimetableSlot>> getTimetableForClass(String classId, String academicYearId) async {
    final grouped = await getTimetableForClasses([classId], academicYearId);
    return grouped[classId] ?? [];
  }
  Future<TimetableSettings> getTimetableSettings(String schoolId) async {
    final row = await _client.from('school_timetable_settings').select().eq('school_id', schoolId).maybeSingle();
    if (row == null) {
      // Sensible Cameroon-school defaults, matching what you described
      return const TimetableSettings(
        periodDurationMinutes: 55, dayStartTime: '07:30', dayEndTime: '15:30',
        breakPeriods: [], workingDays: [1, 2, 3, 4, 5],
      );
    }
    return TimetableSettings.fromMap(row);
  }

  Future<void> saveTimetableSettings({
    required String schoolId,
    required int periodDurationMinutes,
    required String dayStartTime,
    required String dayEndTime,
    required List<Map<String, String>> breakPeriods,
    required List<int> workingDays,
  }) async {
    await _client.from('school_timetable_settings').upsert({
      'school_id': schoolId,
      'period_duration_minutes': periodDurationMinutes,
      'day_start_time': dayStartTime,
      'day_end_time': dayEndTime,
      'break_periods': breakPeriods,
      'working_days': workingDays,
    });
  }
  /// Fetches timetables for MULTIPLE classes in one query - used by
  /// department and whole-school views/downloads, not just a single
  /// class. Correctly scoped by academic year via the timetables join,
  /// which the earlier single-class version was missing entirely.
  Future<Map<String, List<TimetableSlot>>> getTimetableForClasses(List<String> classIds, String academicYearId) async {
    if (classIds.isEmpty) return {};
    final rows = await _client
        .from('timetable_items')
        .select('''
          class_id, day_of_week, start_time, end_time, room_name, needs_teacher,
          teacher_assignments ( subjects(subject_name), teachers(full_name) ),
          subjects ( subject_name ),
          timetables!inner(academic_year_id)
        ''')
        .inFilter('class_id', classIds)
        .eq('timetables.academic_year_id', academicYearId);

    final grouped = <String, List<TimetableSlot>>{};
    for (final r in rows) {
      final classId = r['class_id'] as String;
      grouped.putIfAbsent(classId, () => []).add(TimetableSlot.fromMap(r));
    }
    return grouped;
  }
    // --------------------------------------------------
  // MARKS WINDOW (per exam period)
  // --------------------------------------------------

  Future<List<ExamPeriodOption>> getExamPeriods(String academicYearId) async {
    final rows = await _client
        .from('exam_periods')
        .select('id, period_name, is_open, marks_due_date')
        .eq('academic_year_id', academicYearId)
        .order('sequence_order');
    return rows.map((r) => ExamPeriodOption.fromMap(r)).toList();
  }

  Future<void> setExamPeriodOpen({
    required String examPeriodId,
    required bool isOpen,
    DateTime? marksDueDate,
  }) async {
    await _client.from('exam_periods').update({
      'is_open': isOpen,
      if (marksDueDate != null) 'marks_due_date': marksDueDate.toIso8601String().split('T').first,
    }).eq('id', examPeriodId);
  }

  // --------------------------------------------------
  // MARKS REVIEW
  // --------------------------------------------------

  Future<List<SubmittedMark>> getSubmittedMarks({
    required String examPeriodId,
    String status = 'submitted',
  }) async {
    final rows = await _client
        .from('marks')
        .select('*, students(first_name, last_name), subjects(subject_name), classes(class_name), teachers(full_name)')
        .eq('exam_period_id', examPeriodId)
        .eq('status', status)
        .order('created_at');
    return rows.map((r) => SubmittedMark.fromMap(r)).toList();
  }

    Future<void> approveMarks(List<String> markIds, String principalId) async {
    final updated = await _client.from('marks').update({
      'status': 'approved',
      'approved_by': principalId,
      'approved_at': DateTime.now().toIso8601String(),
      'principal_feedback': null,
    }).inFilter('id', markIds).select();

    // If RLS silently blocks the update, Supabase returns success
    // with an empty result instead of an error - checking the actual
    // row count is what turns that silence into a real, visible error.
    if ((updated as List).length != markIds.length) {
      throw Exception(
        'Only ${updated.length} of ${markIds.length} marks were updated. This usually means a permissions rule is blocking the rest — check the marks RLS policies.',
      );
    }
  }

  Future<void> sendBackMarks(List<String> markIds, String feedback) async {
    await _client.from('marks').update({
      'status': 'rejected',
      'principal_feedback': feedback,
    }).inFilter('id', markIds);
  }

  Future<void> discardMark(String markId) async {
    await _client.from('marks').delete().eq('id', markId);
  }
// --------------------------------------------------
  // ACADEMIC TERMS 

  Future<List<AcademicTermOption>> getTermsForYear(String academicYearId) async {
    final rows = await _client
        .from('academic_terms')
        .select('id, term_name, term_order, is_current')
        .eq('academic_year_id', academicYearId)
        .order('term_order');
    return rows.map((r) => AcademicTermOption.fromMap(r)).toList();
  }
    // --------------------------------------------------
  // REPORT CARD GENERATION + PUBLISHING
  // --------------------------------------------------

  Future<List<ReportCardStatus>> getReportCardStatusForClass({
    required String classId,
    required String termId,
    required String academicYearId,
  }) async {
    final enrolledRows = await _client
        .from('class_enrollments')
        .select('student_id, students(first_name, last_name)')
        .eq('class_id', classId)
        .eq('academic_year_id', academicYearId)
        .eq('enrollment_status', 'active');

    final existingRows = await _client
        .from('report_cards')
        .select('id, student_id, is_published, publish_at')
        .eq('term_id', termId)
        .inFilter('student_id', enrolledRows.map((r) => r['student_id']).toList());

    final existingMap = {for (final r in existingRows) r['student_id'] as String: r};

    return enrolledRows.map((r) {
      final studentId = r['student_id'] as String;
      final student = r['students'] as Map?;
      final existing = existingMap[studentId];
      return ReportCardStatus(
        studentId: studentId,
        studentName: '${student?['first_name'] ?? ''} ${student?['last_name'] ?? ''}'.trim(),
        reportCardId: existing?['id'] as String?,
        exists: existing != null,
        isPublished: existing?['is_published'] as bool? ?? false,
        publishAt: DateTime.tryParse(existing?['publish_at'] as String? ?? ''),
      );
    }).toList();
  }

  /// Computes ONE student's report card from their currently-approved
  /// marks for this term. Does NOT publish it - is_published stays
  /// false until a separate, explicit publish action.
    // --------------------------------------------------
  // REPORT CARD GENERATION - sequence OR term scope, principal chooses
  // --------------------------------------------------

  Future<List<DepartmentFull>> getDepartmentsWithMarksForPeriod(String schoolId, String examPeriodId) async {
    final rows = await _client
        .from('marks')
        .select('classes(department_id, departments(id, department_name, department_type))')
        .eq('school_id', schoolId)
        .eq('exam_period_id', examPeriodId)
        .eq('status', 'approved');
    final seen = <String, DepartmentFull>{};
    for (final r in rows) {
      final dept = (r['classes'] as Map?)?['departments'] as Map?;
      if (dept != null) {
        final id = dept['id'] as String;
        seen[id] = DepartmentFull(id: id, departmentName: dept['department_name'] as String? ?? '', departmentType: dept['department_type'] as String?);
      }
    }
    return seen.values.toList()..sort((a, b) => a.departmentName.compareTo(b.departmentName));
  }

  Future<List<ManagedClass>> getClassesWithMarksForPeriod(String schoolId, String examPeriodId, String departmentId) async {
    final rows = await _client
        .from('marks')
        .select('classes(id, class_name, class_code, department_id, level_order, max_students, is_active, departments(department_name))')
        .eq('school_id', schoolId)
        .eq('exam_period_id', examPeriodId)
        .eq('status', 'approved');
    final seen = <String, ManagedClass>{};
    for (final r in rows) {
      final cls = r['classes'] as Map?;
      if (cls != null && cls['department_id'] == departmentId) {
        final classMap = Map<String, dynamic>.from(cls);
        seen[classMap['id'] as String] = ManagedClass.fromMap(classMap);
      }
    }
    return seen.values.toList()..sort((a, b) => a.className.compareTo(b.className));
  }

  /// Generates (or regenerates) the report_cards ROW and subject_results
  /// summary for one student. For sequence scope: one row per subject
  /// from that sequence's marks. For term scope: one row per subject,
  /// with score = the AVERAGE across that subject's sequences in the
  /// term (the detailed per-sequence breakdown is read fresh from
  /// `marks` at PDF-build time, not duplicated into subject_results).
  Future<String> generateReportCard({
    required String schoolId,
    required String studentId,
    required String classId,
    required String academicYearId,
    required String termId,
    required String reportScope, // 'sequence' | 'term'
    String? examPeriodId, // required when reportScope == 'sequence'
  }) async {
    List<String> periodIds;
    if (reportScope == 'sequence') {
      if (examPeriodId == null) throw Exception('An exam period is required for a sequence report.');
      periodIds = [examPeriodId];
    } else {
      periodIds = await _examPeriodIdsForTerm(termId);
    }

    final marksRows = await _client
        .from('marks')
        .select('score, coefficient, subject_id')
        .eq('student_id', studentId)
        .inFilter('exam_period_id', periodIds)
        .eq('status', 'approved');

    if (marksRows.isEmpty) {
      throw Exception('No approved marks found for this student in this ${reportScope == 'sequence' ? 'sequence' : 'term'}.');
    }

    final bySubject = <String, List<Map<String, dynamic>>>{};
    for (final m in marksRows) {
      bySubject.putIfAbsent(m['subject_id'] as String, () => []).add(m);
    }

    double totalWeighted = 0;
    int totalCoefficient = 0;
    final subjectPayload = <Map<String, dynamic>>[];
    bySubject.forEach((subjectId, rows) {
      final coefficient = rows.first['coefficient'] as int;
      final avgScore = rows.map((r) => (r['score'] as num).toDouble()).reduce((a, b) => a + b) / rows.length;
      totalWeighted += avgScore * coefficient;
      totalCoefficient += coefficient;
      subjectPayload.add({'subject_id': subjectId, 'score': avgScore, 'coefficient': coefficient, 'weighted_score': avgScore * coefficient});
    });
    final average = totalCoefficient == 0 ? 0.0 : totalWeighted / totalCoefficient;

    // Check-then-insert-or-update explicitly - the partial unique
    // indexes above can't be targeted by upsert()'s ON CONFLICT
    // shorthand, same limitation we hit with subject_offerings earlier.
    Map<String, dynamic>? existing;
    if (reportScope == 'sequence') {
      existing = await _client.from('report_cards').select('id').eq('student_id', studentId).eq('exam_period_id', examPeriodId!).eq('report_scope', 'sequence').maybeSingle();
    } else {
      existing = await _client.from('report_cards').select('id').eq('student_id', studentId).eq('term_id', termId).eq('report_scope', 'term').maybeSingle();
    }

    final payload = {
      'school_id': schoolId,
      'student_id': studentId,
      'class_id': classId,
      'term_id': termId,
      'academic_year_id': academicYearId,
      'exam_period_id': reportScope == 'sequence' ? examPeriodId : null,
      'report_scope': reportScope,
      'overall_average': average,
      'generated_at': DateTime.now().toIso8601String(),
    };

    String reportCardId;
    if (existing == null) {
      final inserted = await _client.from('report_cards').insert(payload).select('id').single();
      reportCardId = inserted['id'] as String;
    } else {
      reportCardId = existing['id'] as String;
      await _client.from('report_cards').update(payload).eq('id', reportCardId);
    }

    await _client.from('subject_results').delete().eq('report_card_id', reportCardId);
    await _client.from('subject_results').insert([
      for (final s in subjectPayload) {'report_card_id': reportCardId, ...s},
    ]);

    return reportCardId;
  }

  /// Everything needed to render the actual PDF - including the
  /// per-sequence column breakdown for a term report, read fresh from
  /// `marks` rather than from the flattened subject_results average.
  Future<ReportCardPdfData> getReportCardPdfData(String reportCardId) async {
    final rc = await _client
        .from('report_cards')
        .select('*, students(first_name, last_name, student_photo_url), classes(class_name), academic_terms(term_name), exam_periods(period_name)')
        .eq('id', reportCardId)
        .single();

    final student = rc['students'] as Map;
    final cls = rc['classes'] as Map?;
    final scope = rc['report_scope'] as String;
    final studentId = rc['student_id'] as String;

    List<({String id, String name})> periodColumns;
    List<String> periodIdsForMarks;

    if (scope == 'sequence') {
      final period = rc['exam_periods'] as Map;
      periodColumns = [(id: rc['exam_period_id'] as String, name: period['period_name'] as String? ?? '')];
      periodIdsForMarks = [rc['exam_period_id'] as String];
    } else {
      final periodRows = await _client
          .from('exam_periods')
          .select('id, period_name')
          .eq('academic_term_id', rc['term_id'])
          .order('sequence_order');
      periodColumns = periodRows.map<({String id, String name})>((p) => (id: p['id'] as String, name: p['period_name'] as String? ?? '')).toList();
      periodIdsForMarks = periodColumns.map((p) => p.id).toList();
    }

    final marksRows = await _client
        .from('marks')
        .select('score, coefficient, exam_period_id, subjects(subject_name)')
        .eq('student_id', studentId)
        .inFilter('exam_period_id', periodIdsForMarks)
        .eq('status', 'approved');

    final bySubjectName = <String, List<Map<String, dynamic>>>{};
    for (final m in marksRows) {
      final name = (m['subjects'] as Map?)?['subject_name'] as String? ?? '';
      bySubjectName.putIfAbsent(name, () => []).add(m);
    }

    final subjectRows = bySubjectName.entries.map((entry) {
      final scoresByPeriod = <String, double>{};
      int coefficient = 1;
      for (final row in entry.value) {
        scoresByPeriod[row['exam_period_id'] as String] = (row['score'] as num).toDouble();
        coefficient = row['coefficient'] as int;
      }
      final avg = scoresByPeriod.values.isEmpty ? 0.0 : scoresByPeriod.values.reduce((a, b) => a + b) / scoresByPeriod.length;
      return ReportCardPdfSubjectRow(subjectName: entry.key, coefficient: coefficient, scoresByPeriod: scoresByPeriod, average: avg);
    }).toList()
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));

    final term = rc['academic_terms'] as Map?;
    final label = scope == 'sequence' ? periodColumns.first.name : (term?['term_name'] as String? ?? 'Term Report');

    return ReportCardPdfData(
      studentName: '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
      studentPhotoUrl: student['student_photo_url'] as String?,
      className: cls?['class_name'] as String? ?? '',
      reportLabel: label,
      periodColumns: periodColumns,
      subjects: subjectRows,
      overallAverage: (rc['overall_average'] as num?)?.toDouble() ?? 0.0,
      classRank: rc['class_rank'] as int?,
      totalStudents: rc['total_students'] as int?,
      principalComment: rc['principal_comment'] as String?,
    );
  }

  Future<void> savePdfUrlOnReportCard(String reportCardId, String pdfUrl) async {
    await _client.from('report_cards').update({'pdf_url': pdfUrl}).eq('id', reportCardId);
  }

  Future<String> getTermIdForExamPeriod(String examPeriodId) async {
    final row = await _client.from('exam_periods').select('academic_term_id').eq('id', examPeriodId).single();
    return row['academic_term_id'] as String;
  }

  /// Report cards already generated for this class+scope, straight
  /// from the report_cards table itself - so even if a whole-class
  /// batch is interrupted partway, whatever DID succeed is always
  /// visible and downloadable here, exactly like the ID card batches.
  Future<List<ReportCardStatus>> getGeneratedReportCardsForClassScope({
    required String classId,
    required String reportScope,
    String? termId,
    String? examPeriodId,
  }) async {
    var query = _client
        .from('report_cards')
        .select('id, student_id, is_published, publish_at, pdf_url, students(first_name, last_name)')
        .eq('class_id', classId)
        .eq('report_scope', reportScope);

    query = reportScope == 'sequence' ? query.eq('exam_period_id', examPeriodId!) : query.eq('term_id', termId!);

    final rows = await query;
    return rows.map((r) {
      final student = r['students'] as Map?;
      return ReportCardStatus(
        studentId: r['student_id'] as String,
        studentName: '${student?['first_name'] ?? ''} ${student?['last_name'] ?? ''}'.trim(),
        reportCardId: r['id'] as String,
        exists: true,
        isPublished: r['is_published'] as bool? ?? false,
        publishAt: DateTime.tryParse(r['publish_at'] as String? ?? ''),
      );
    }).toList()
      ..sort((a, b) => a.studentName.compareTo(b.studentName));
  }
// --------------------------------------------------
  // BULK REPORT CARD GENERATION + PUBLISHING
  // --------------------------------------------------
 Future<Map<String, dynamic>> generateReportCardsForClass({
    required String schoolId,
    required String classId,
    required String termId,
    required String academicYearId,
  }) async {
    final students = await getReportCardStatusForClass(classId: classId, termId: termId, academicYearId: academicYearId);
    var succeeded = 0;
    var skipped = 0;
    for (final s in students) {
      try {
        await generateReportCard(
          schoolId: schoolId,
          studentId: s.studentId,
          classId: classId,
          termId: termId,
          academicYearId: academicYearId,
          reportScope: 'term',
        );
        succeeded++;
      } catch (_) {
        skipped++; // e.g. this student has no approved marks yet - not fatal, continue with the rest
      }
    }
    return {'succeeded': succeeded, 'skipped': skipped, 'total': students.length};
  }

  Future<List<String>> _examPeriodIdsForTerm(String termId) async {
    final rows = await _client.from('exam_periods').select('id').eq('academic_term_id', termId);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> publishReportCard(String reportCardId, String principalId, {DateTime? publishAt}) async {
    await _client.from('report_cards').update({
      'is_published': publishAt == null,
      'publish_at': publishAt?.toIso8601String(),
      'published_by': principalId,
    }).eq('id', reportCardId);
  }

  Future<void> unpublishReportCard(String reportCardId) async {
    await _client.from('report_cards').update({'is_published': false, 'publish_at': null}).eq('id', reportCardId);
  }
  // --------------------------------------------------
  // DEPARTMENTS
  // --------------------------------------------------

  Future<List<DepartmentOption>> getDepartments(String schoolId) async {
    final rows = await _client.from('departments').select('id, department_name').eq('school_id', schoolId);
    return rows.map((r) => DepartmentOption.fromMap(r)).toList();
  }

  // --------------------------------------------------
  // CLASSES
  // --------------------------------------------------

  Future<List<ManagedClass>> getClasses(String schoolId, {bool includeInactive = false}) async {
    var query = _client.from('classes').select('*, departments(department_name)').eq('school_id', schoolId);
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('level_order');
    return rows.map((r) => ManagedClass.fromMap(r)).toList();
  }

    Future<ManagedClass> createClass({
    required String schoolId,
    required String className,
    String? classCode,
    required String departmentId,
    required int levelOrder,
    required int maxStudents,
  }) async {
    final inserted = await _client
        .from('classes')
        .insert({
          'school_id': schoolId,
          'class_name': className,
          'class_code': classCode,
          'department_id': departmentId,
          'level_order': levelOrder,
          'max_students': maxStudents,
        })
        .select('*, departments(department_name)')
        .single();
    return ManagedClass.fromMap(inserted);
  }
  Future<void> updateClass({
    required String classId,
    required String className,
    String? classCode,
    required String departmentId,
    required int levelOrder,
    required int maxStudents,
  }) async {
    await _client.from('classes').update({
      'class_name': className,
      'class_code': classCode,
      'department_id': departmentId,
      'level_order': levelOrder,
      'max_students': maxStudents,
    }).eq('id', classId);
  }

  Future<void> setClassActive(String classId, bool isActive) async {
    await _client.from('classes').update({'is_active': isActive}).eq('id', classId);
  }
// --------------------------------------------------
  // FEE CONFIGURATION (per class)  
// --------------------------------------------------
  Future<Map<String, List<TeacherAssignmentInfo>>> _getAssignmentsGroupedBySchool(String schoolId, String academicYearId) async {
    final rows = await _client
        .from('teacher_assignments')
        .select('id, teacher_id, periods_per_week, classes(class_name), subjects(subject_name)')
        .eq('school_id', schoolId)
        .eq('academic_year_id', academicYearId);

    final map = <String, List<TeacherAssignmentInfo>>{};
    for (final r in rows) {
      final teacherId = r['teacher_id'] as String;
      map.putIfAbsent(teacherId, () => []).add(TeacherAssignmentInfo.fromMap(r));
    }
    return map;
  }

  /// Every teacher who's signed up at this school - approved or
  /// pending - with their current assignments, so the Principal can
  /// see at a glance who is fully utilized and who has nothing yet.
  Future<List<TeacherOverviewInfo>> getTeacherOverview(String schoolId, String academicYearId) async {
    final teachers = await getAllTeachers(schoolId);
    final assignmentsMap = await _getAssignmentsGroupedBySchool(schoolId, academicYearId);
    return teachers.map((t) => TeacherOverviewInfo(profile: t, assignments: assignmentsMap[t.teacherId] ?? [])).toList();
  }
  // --------------------------------------------------
  // SUBJECTS (school-wide list)
  // --------------------------------------------------

  Future<List<ManagedSubject>> getSubjects(String schoolId) async {
    final rows = await _client.from('subjects').select().eq('school_id', schoolId).order('subject_name');
    return rows.map((r) => ManagedSubject.fromMap(r)).toList();
  }

  Future<void> createSubject({required String schoolId, required String subjectCode, required String subjectName}) async {
    await _client.from('subjects').insert({'school_id': schoolId, 'subject_code': subjectCode, 'subject_name': subjectName});
  }

  // --------------------------------------------------
  // SUBJECT OFFERINGS - per class
  // --------------------------------------------------

  Future<List<SubjectOfferingRow>> getSubjectOfferingsForClass(String schoolId, String classId) async {
    final allSubjects = await getSubjects(schoolId);
    final offeredRows = await _client.from('subject_offerings').select('subject_id, is_compulsory').eq('class_id', classId);

    final offeredMap = {for (final r in offeredRows) r['subject_id'] as String: r['is_compulsory'] as bool};

    return allSubjects
        .map((s) => SubjectOfferingRow(
              subjectId: s.id,
              subjectName: s.subjectName,
              isOffered: offeredMap.containsKey(s.id),
              isCompulsory: offeredMap[s.id] ?? false,
            ))
        .toList();
  }
  Future<void> setSubjectOffering({
    required String classId,
    required String subjectId,
    required bool isOffered,
    required bool isCompulsory,
  }) async {
    if (!isOffered) {
      await _client.from('subject_offerings').delete().eq('class_id', classId).eq('subject_id', subjectId);
      return;
    }

    // subject_offerings' unique index is PARTIAL (WHERE class_id IS
    // NOT NULL), which PostgREST's upsert()/ON CONFLICT shorthand
    // can't target directly - so we check-then-insert-or-update
    // explicitly instead of relying on upsert().
    final existing = await _client
        .from('subject_offerings')
        .select('id')
        .eq('class_id', classId)
        .eq('subject_id', subjectId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('subject_offerings').insert({
        'class_id': classId,
        'subject_id': subjectId,
        'is_compulsory': isCompulsory,
        'is_selectable': true,
      });
    } else {
      await _client.from('subject_offerings').update({
        'is_compulsory': isCompulsory,
        'is_selectable': true,
      }).eq('id', existing['id']);
    }
  }



  Future<List<Map<String, dynamic>>> getClassesWithSubmittedMarks(String examPeriodId) async {
    final rows = await _client
        .from('marks')
        .select('class_id, classes(class_name)')
        .eq('exam_period_id', examPeriodId)
        .eq('status', 'submitted');

    final seen = <String, String>{};
    for (final r in rows) {
      final classId = r['class_id'] as String;
      final className = (r['classes'] as Map?)?['class_name'] as String? ?? '';
      seen[classId] = className;
    }
    return seen.entries.map((e) => {'id': e.key, 'name': e.value}).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

    // --------------------------------------------------
  // COMMENT REVIEW / PUBLISHING
  // --------------------------------------------------

  Future<List<PendingComment>> getPendingComments(String schoolId) async {
    final rows = await _client
        .from('class_comments')
        .select('*, students(first_name, last_name), classes(class_name), teachers(full_name), exam_periods(period_name)')
        .eq('school_id', schoolId)
        .eq('status', 'draft')
        .order('created_at');
    return rows.map((r) => PendingComment.fromMap(r)).toList();
  }

  Future<void> approveComment(String commentId, {String? editedText}) async {
    await _client.from('class_comments').update({
      'status': 'approved',
      if (editedText != null) 'comment': editedText,
    }).eq('id', commentId);
  }

  Future<void> discardComment(String commentId) async {
    await _client.from('class_comments').delete().eq('id', commentId);
  }

  Future<int> publishReportCardsForClass({
    required String classId,
    required String termId,
    required String principalId,
    DateTime? publishAt,
  }) async {
    final rows = await _client
        .from('report_cards')
        .update({
          'is_published': publishAt == null,
          'publish_at': publishAt?.toIso8601String(),
          'published_by': principalId,
        })
        .eq('class_id', classId)
        .eq('term_id', termId)
        .select();
    return (rows as List).length;
  }
// -------------------------------------------------
  // SUBJECTS WITH SUBMITTED MARKS (per class)
  // -------------------------------------------------
  Future<List<Map<String, dynamic>>> getSubjectsWithSubmittedMarks(String examPeriodId, String classId) async {
    final rows = await _client
        .from('marks')
        .select('subject_id, subjects(subject_name)')
        .eq('exam_period_id', examPeriodId)
        .eq('class_id', classId)
        .eq('status', 'submitted');

    final seen = <String, String>{};
    for (final r in rows) {
      final subjectId = r['subject_id'] as String;
      final subjectName = (r['subjects'] as Map?)?['subject_name'] as String? ?? '';
      seen[subjectId] = subjectName;
    }
    return seen.entries.map((e) => {'id': e.key, 'name': e.value}).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  Future<List<SubmittedMark>> getMarksForClassSubject({
    required String examPeriodId,
    required String classId,
    required String subjectId,
  }) async {
    final rows = await _client
        .from('marks')
        .select('*, students(first_name, last_name), subjects(subject_name), classes(class_name), teachers(full_name)')
        .eq('exam_period_id', examPeriodId)
        .eq('class_id', classId)
        .eq('subject_id', subjectId)
        .eq('status', 'submitted')
        .order('created_at');
    return rows.map((r) => SubmittedMark.fromMap(r)).toList();
  }
    // --------------------------------------------------
  // DEPARTMENTS
  // --------------------------------------------------

  Future<List<DepartmentFull>> getDepartmentsFull(String schoolId) async {
    final rows = await _client.from('departments').select().eq('school_id', schoolId).order('department_name');
    return rows.map((r) => DepartmentFull.fromMap(r)).toList();
  }

  Future<void> createDepartment({required String schoolId, required String name, String? type}) async {
    await _client.from('departments').insert({'school_id': schoolId, 'department_name': name, 'department_type': type});
  }

  Future<void> updateDepartment({required String departmentId, required String name, String? type}) async {
    await _client.from('departments').update({'department_name': name, 'department_type': type}).eq('id', departmentId);
  }

  // --------------------------------------------------
  // SUBJECTS + COEFFICIENT (per department)
  // --------------------------------------------------

  Future<List<SubjectWithCoefficient>> getSubjectsForDepartment(String departmentId) async {
    final rows = await _client
        .from('subject_departments')
        .select('coefficient, subjects(id, subject_code, subject_name)')
        .eq('department_id', departmentId);

    return rows.map((r) {
      final subj = r['subjects'] as Map;
      return SubjectWithCoefficient(
        subjectId: subj['id'] as String,
        subjectCode: subj['subject_code'] as String? ?? '',
        subjectName: subj['subject_name'] as String? ?? '',
        coefficient: r['coefficient'] as int? ?? 1,
      );
    }).toList();
  }

  Future<void> createSubjectInDepartment({
    required String schoolId,
    required String departmentId,
    required String subjectCode,
    required String subjectName,
    required int coefficient,
  }) async {
    final subject = await _client
        .from('subjects')
        .insert({'school_id': schoolId, 'subject_code': subjectCode, 'subject_name': subjectName})
        .select()
        .single();

    await _client.from('subject_departments').insert({
      'subject_id': subject['id'],
      'department_id': departmentId,
      'coefficient': coefficient,
    });
  }

  /// Attaches an EXISTING school subject to another department with
  /// its own coefficient - same subject, different weight per
  /// department, exactly matching how subject_departments is designed.
  Future<void> attachExistingSubjectToDepartment({
    required String subjectId,
    required String departmentId,
    required int coefficient,
  }) async {
    final existing = await _client
        .from('subject_departments')
        .select('subject_id')
        .eq('subject_id', subjectId)
        .eq('department_id', departmentId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('subject_departments').insert({
        'subject_id': subjectId,
        'department_id': departmentId,
        'coefficient': coefficient,
      });
    } else {
      await _client
          .from('subject_departments')
          .update({'coefficient': coefficient})
          .eq('subject_id', subjectId)
          .eq('department_id', departmentId);
    }
  }

  Future<void> updateSubjectCoefficient({required String subjectId, required String departmentId, required int coefficient}) async {
    await _client.from('subject_departments').update({'coefficient': coefficient}).eq('subject_id', subjectId).eq('department_id', departmentId);
  }

  Future<List<ManagedSubject>> getAllSchoolSubjects(String schoolId) => getSubjects(schoolId);

  // --------------------------------------------------
  // SUBJECT BROWSE / REVIEW LIST
  // --------------------------------------------------

  Future<List<SubjectBrowseItem>> getSubjectBrowseList(String schoolId, String academicYearId) async {
    final deptSubjects = await _client
        .from('subject_departments')
        .select('coefficient, subjects(id, subject_name), departments!inner(department_name, school_id)')
        .eq('departments.school_id', schoolId);

    final result = <SubjectBrowseItem>[];
    for (final row in deptSubjects) {
      final subj = row['subjects'] as Map;
      final dept = row['departments'] as Map;
      final subjectId = subj['id'] as String;

      final offeringRows = await _client
          .from('subject_offerings')
          .select('classes(class_name)')
          .eq('subject_id', subjectId)
          .not('class_id', 'is', null);
      final classNames = offeringRows.map((r) => (r['classes'] as Map?)?['class_name'] as String? ?? '').where((n) => n.isNotEmpty).toList();

      final teacherRows = await _client
          .from('teacher_assignments')
          .select('teachers(full_name)')
          .eq('subject_id', subjectId)
          .eq('academic_year_id', academicYearId);
      final teacherNames = teacherRows.map((r) => (r['teachers'] as Map?)?['full_name'] as String? ?? '').where((n) => n.isNotEmpty).toSet().toList();

      result.add(SubjectBrowseItem(
        subjectId: subjectId,
        subjectName: subj['subject_name'] as String? ?? '',
        departmentName: dept['department_name'] as String? ?? '',
        coefficient: row['coefficient'] as int? ?? 1,
        classesOffering: classNames,
        teachersAssigned: teacherNames,
      ));
    }
    return result;
  }


  // --------------------------------------------------
  // ADMISSIONS AWAITING REVIEW (status = 'under_review', i.e.
  // registration fee already paid - see the parent module's payment
  // webhook, which moves a request here rather than auto-approving)
  // --------------------------------------------------

  Future<List<PendingAdmissionReview>> getAdmissionsForReview(String schoolId) async {
    final rows = await _client
        .from('admission_requests')
        .select('*, classes(class_name), admission_request_subjects(subjects(subject_name))')
        .eq('school_id', schoolId)
        .eq('status', 'under_review')
        .order('created_at');

    return rows.map((r) {
      final cls = r['classes'] as Map?;
      final subjectRows = r['admission_request_subjects'] as List? ?? [];
      final subjectNames = subjectRows.map((s) => (s['subjects'] as Map?)?['subject_name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
      return PendingAdmissionReview(
        id: r['id'] as String,
        firstName: r['first_name'] as String? ?? '',
        lastName: r['last_name'] as String? ?? '',
        photoUrl: r['photo_url'] as String?,
        requestedClassName: cls?['class_name'] as String? ?? '',
        guardianName: r['guardian_name'] as String?,
        emergencyContactName: r['emergency_contact_name'] as String?,
        emergencyContactPhone: r['emergency_contact_phone'] as String?,
        address: r['address'] as String?,
        dateOfBirth: DateTime.tryParse(r['date_of_birth'] as String? ?? ''),
        selectedSubjectNames: subjectNames,
      );
    }).toList();
  }

  /// Calls the SAME SQL function built during the parent module work -
  /// no new backend logic, just a Principal-facing trigger for it.
  Future<void> approveAdmission(String admissionRequestId) async {
    await _client.rpc('approve_admission_request', params: {'p_admission_request_id': admissionRequestId});
  }

  Future<void> rejectAdmission(String admissionRequestId, String reason) async {
    await _client.from('admission_requests').update({
      'status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', admissionRequestId);
  }

  // --------------------------------------------------
  // ALL STUDENTS AT THE SCHOOL (school-wide, not department-filtered
  // by default - Principal sees everyone; department filter is a
  // client-side toggle on top of this same list)
  // --------------------------------------------------

  Future<List<SchoolStudent>> getAllStudents(String schoolId) async {
    final rows = await _client
        .from('students')
        .select('''
          id, admission_number, first_name, last_name, student_photo_url, current_status,
          class_enrollments!inner (
            enrollment_status,
            classes ( class_name, departments ( department_name ) )
          )
        ''')
        .eq('school_id', schoolId)
        .eq('class_enrollments.enrollment_status', 'active')
        .order('first_name');
    return rows.map((r) => SchoolStudent.fromMap(r)).toList();
  }

    // --------------------------------------------------
  // ADMISSIONS - now drilled down Department -> Class, same fix
  // pattern as Report Cards, to avoid two "Form 1A"s in different
  // departments being ambiguous
  // --------------------------------------------------

  Future<List<DepartmentFull>> getDepartmentsWithPendingAdmissions(String schoolId) async {
    final rows = await _client
        .from('admission_requests')
        .select('classes(department_id, departments(id, department_name, department_type))')
        .eq('school_id', schoolId)
        .eq('status', 'under_review');

    final seen = <String, DepartmentFull>{};
    for (final r in rows) {
      final cls = r['classes'] as Map?;
      final dept = cls?['departments'] as Map?;
      if (dept != null) {
        final id = dept['id'] as String;
        seen[id] = DepartmentFull(id: id, departmentName: dept['department_name'] as String? ?? '', departmentType: dept['department_type'] as String?);
      }
    }
    return seen.values.toList()..sort((a, b) => a.departmentName.compareTo(b.departmentName));
  }

Future<List<ManagedClass>> getClassesWithPendingAdmissions(String schoolId, String departmentId) async {
    final rows = await _client
        .from('admission_requests')
        .select('classes!inner(id, class_name, class_code, department_id, level_order, max_students, is_active, departments(department_name))')
        .eq('school_id', schoolId)
        .eq('status', 'under_review')
        .eq('classes.department_id', departmentId);

    final seen = <String, ManagedClass>{};
    for (final r in rows) {
      final cls = (r['classes'] as Map).cast<String, dynamic>();
      seen[cls['id'] as String] = ManagedClass.fromMap(cls);
    }
    return seen.values.toList()..sort((a, b) => a.className.compareTo(b.className));
  }

  Future<List<PendingAdmissionReview>> getAdmissionsForClass(String schoolId, String classId) async {
    final rows = await _client
        .from('admission_requests')
        .select('*, classes(class_name), admission_request_subjects(subjects(subject_name))')
        .eq('school_id', schoolId)
        .eq('status', 'under_review')
        .eq('requested_class_id', classId)
        .order('created_at');

    return rows.map((r) {
      final cls = r['classes'] as Map?;
      final subjectRows = r['admission_request_subjects'] as List? ?? [];
      final subjectNames = subjectRows.map((s) => (s['subjects'] as Map?)?['subject_name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
      return PendingAdmissionReview(
        id: r['id'] as String,
        firstName: r['first_name'] as String? ?? '',
        lastName: r['last_name'] as String? ?? '',
        photoUrl: r['photo_url'] as String?,
        requestedClassName: cls?['class_name'] as String? ?? '',
        guardianName: r['guardian_name'] as String?,
        emergencyContactName: r['emergency_contact_name'] as String?,
        emergencyContactPhone: r['emergency_contact_phone'] as String?,
        address: r['address'] as String?,
        dateOfBirth: DateTime.tryParse(r['date_of_birth'] as String? ?? ''),
        selectedSubjectNames: subjectNames,
      );
    }).toList();
  }



  Future<void> recordIdCardGeneration({
    required String schoolId,
    required String classId,
    required String label,
    required int studentCount,
    required String pdfUrl,
    required String principalId,
  }) async {
    await _client.from('id_card_generations').insert({
      'school_id': schoolId,
      'class_id': classId,
      'label': label,
      'student_count': studentCount,
      'pdf_url': pdfUrl,
      'generated_by': principalId,
    });
  }

  Future<List<IdCardBatch>> getGeneratedIdCardBatches(String classId) async {
    final rows = await _client
        .from('id_card_generations')
        .select('id, label, student_count, pdf_url, generated_at')
        .eq('class_id', classId)
        .order('generated_at', ascending: false);
    return rows.map((r) => IdCardBatch.fromMap(r)).toList();
  }

  Future<void> deleteIdCardBatch(String batchId, String pdfUrl) async {
    // Extract the storage path from the public/signed URL's tail -
    // matches the {school_id}/{filename} layout used when uploading.
    final uri = Uri.parse(pdfUrl);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('generated-documents');
    if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
      final path = segments.sublist(bucketIndex + 1).join('/');
      await _client.storage.from('generated-documents').remove([path]);
    }
    await _client.from('id_card_generations').delete().eq('id', batchId);
  }

  Future<String> uploadGeneratedPdf({
    required String schoolId,
    required Uint8List bytes,
    required String filenamePrefix,
  }) async {
    final path = '$schoolId/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _client.storage.from('generated-documents').uploadBinary(path, bytes);
    // Private bucket - createSignedUrl, generous 1-year expiry (same
    // tradeoff already used for staff photos before that bucket was
    // made public; documented there for future re-signing if needed).
    return await _client.storage.from('generated-documents').createSignedUrl(path, 60 * 60 * 24 * 365);
  }
  // --------------------------------------------------
  // OFFICIAL DOCUMENT BRANDING - same school_assets table/pattern
  // already used in the parent module for receipts and report cards.
  // --------------------------------------------------

  Future<Map<String, String>> getOfficialBranding(String schoolId) async {
    final rows = await _client
        .from('school_assets')
        .select()
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .inFilter('asset_type', ['letterhead', 'principal_stamp', 'proprietor_stamp', 'discipline_master_stamp']);

    final result = <String, String>{};
    for (final row in rows) {
      final type = row['asset_type'] as String?;
      final url = row['file_url'] as String?;
      if (type != null && url != null) result[type] = url;
    }
    return result;
  }

  // --------------------------------------------------
  // ID CARDS - reuses the same Department -> Class drill-down as
  // Report Cards and Admissions
  // --------------------------------------------------

  Future<List<SchoolStudent>> getStudentsForClass(String classId) async {
    final rows = await _client
        .from('class_enrollments')
        .select('students(id, admission_number, first_name, last_name, student_photo_url, current_status, class_enrollments(enrollment_status, classes(class_name, departments(department_name))))')
        .eq('class_id', classId)
        .eq('enrollment_status', 'active');
    return rows.map((r) => SchoolStudent.fromMap(r['students'] as Map<String, dynamic>)).toList();
  }

  Future<IdCardStudentData> getIdCardData(String studentId) async {
    final studentRow = await _client
        .from('students')
        .select('''
          id, admission_number, first_name, last_name, student_photo_url, date_of_birth, admission_date,
          class_enrollments ( enrollment_status, classes ( class_name ) )
        ''')
        .eq('id', studentId)
        .single();

    final guardianRow = await _client
        .from('student_guardians')
        .select('guardians(full_name, phone)')
        .eq('student_id', studentId)
        .eq('is_primary', true)
        .maybeSingle();

    final enrollments = studentRow['class_enrollments'] as List?;
    final className = (enrollments?.isNotEmpty == true ? (enrollments!.first as Map)['classes'] as Map? : null)?['class_name'] as String? ?? 'Unassigned';
    final guardian = guardianRow?['guardians'] as Map?;

    return IdCardStudentData(
      studentId: studentRow['id'] as String,
      admissionNumber: studentRow['admission_number'] as String? ?? '',
      firstName: studentRow['first_name'] as String? ?? '',
      lastName: studentRow['last_name'] as String? ?? '',
      photoUrl: studentRow['student_photo_url'] as String?,
      dateOfBirth: DateTime.tryParse(studentRow['date_of_birth'] as String? ?? ''),
      admissionDate: DateTime.tryParse(studentRow['admission_date'] as String? ?? ''),
      className: className,
      guardianName: guardian?['full_name'] as String?,
      guardianPhone: guardian?['phone'] as String?,
    );
  }

   /// Fetches ID card data for an ENTIRE class in two queries total,
  /// instead of calling getIdCardData once per student - that
  /// per-student pattern was multiplying RLS evaluation cost by
  /// class size and was the main contributor to the timeout.
  Future<List<IdCardStudentData>> getIdCardDataForClass(String classId) async {
    final studentRows = await _client
        .from('students')
        .select('''
          id, admission_number, first_name, last_name, student_photo_url, date_of_birth, admission_date,
          class_enrollments!inner ( enrollment_status, classes ( class_name ) )
        ''')
        .eq('class_enrollments.class_id', classId)
        .eq('class_enrollments.enrollment_status', 'active');

    final studentIds = studentRows.map((r) => r['id'] as String).toList();
    if (studentIds.isEmpty) return [];

    final guardianRows = await _client
        .from('student_guardians')
        .select('student_id, guardians(full_name, phone)')
        .inFilter('student_id', studentIds)
        .eq('is_primary', true);

    final guardianByStudent = {for (final g in guardianRows) g['student_id'] as String: g['guardians'] as Map?};

    return studentRows.map((r) {
      final enrollments = r['class_enrollments'] as List?;
      final className = (enrollments?.isNotEmpty == true ? (enrollments!.first as Map)['classes'] as Map? : null)?['class_name'] as String? ?? 'Unassigned';
      final guardian = guardianByStudent[r['id']];

      return IdCardStudentData(
        studentId: r['id'] as String,
        admissionNumber: r['admission_number'] as String? ?? '',
        firstName: r['first_name'] as String? ?? '',
        lastName: r['last_name'] as String? ?? '',
        photoUrl: r['student_photo_url'] as String?,
        dateOfBirth: DateTime.tryParse(r['date_of_birth'] as String? ?? ''),
        admissionDate: DateTime.tryParse(r['admission_date'] as String? ?? ''),
        className: className,
        guardianName: guardian?['full_name'] as String?,
        guardianPhone: guardian?['phone'] as String?,
      );
    }).toList();
  }

  Future<List<IdCardGenerationRecord>> getGeneratedIdCardsForClass(String classId) async {
    final rows = await _client
        .from('id_card_generations')
        .select('generated_at, students!inner(first_name, last_name, class_enrollments!inner(class_id))')
        .eq('students.class_enrollments.class_id', classId)
        .order('generated_at', ascending: false);

    return rows.map((r) {
      final student = r['students'] as Map;
      return IdCardGenerationRecord(
        studentId: student['id'] as String? ?? '',
        studentName: '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
        generatedAt: DateTime.tryParse(r['generated_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }
  // --------------------------------------------------
  // STUDENT DETAIL - tap a student to see full info + guardians
  // --------------------------------------------------

  Future<StudentDetail> getStudentDetail(String studentId) async {
    final studentRow = await _client
        .from('students')
        .select('''
          id, admission_number, first_name, last_name, student_photo_url, current_status,
          class_enrollments ( enrollment_status, classes ( class_name, departments ( department_name ) ) )
        ''')
        .eq('id', studentId)
        .single();

    final guardianRows = await _client
        .from('student_guardians')
        .select('is_primary, is_emergency_contact, guardians(full_name, relationship_type, phone, email)')
        .eq('student_id', studentId);

    return StudentDetail(
      student: SchoolStudent.fromMap(studentRow),
      guardians: guardianRows.map((r) => GuardianInfo.fromMap(r)).toList(),
    );
  }

  // --------------------------------------------------
  // PRINCIPAL-INITIATED ENROLLMENT ("on behalf of a lazy parent")
  // Goes through the EXACT SAME pipeline as a parent-created request -
  // created_by_staff_user_id marks who initiated it, but payment,
  // review, and approval all work identically. It will simply appear
  // on the SELECTED parent's own dashboard as "Registration fee
  // pending" - no separate payment handling needed here.
  // --------------------------------------------------

  Future<List<ParentSearchResult>> searchParents(String schoolId, String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await _client
        .from('parents')
        .select('id, full_name, phone, users(email)')
        .eq('school_id', schoolId)
        .ilike('full_name', '%${query.trim()}%')
        .limit(10);
    return rows.map((r) => ParentSearchResult.fromMap(r)).toList();
  }

  Future<void> createAdmissionOnBehalfOfParent({
    required String schoolId,
    required String parentId,
    required String requestedClassId,
    required String academicYearId,
    required String principalUserId,
    required String firstName,
    required String lastName,
    String? gender,
    DateTime? dateOfBirth,
    String? guardianName,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? address,
    required List<String> selectedSubjectIds,
  }) async {
    final request = await _client
        .from('admission_requests')
        .insert({
          'school_id': schoolId,
          'parent_id': parentId,
          'created_by_staff_user_id': principalUserId,
          'requested_class_id': requestedClassId,
          'academic_year_id': academicYearId,
          'first_name': firstName,
          'last_name': lastName,
          'gender': gender,
          'date_of_birth': dateOfBirth?.toIso8601String(),
          'guardian_name': guardianName,
          'emergency_contact_name': emergencyContactName,
          'emergency_contact_phone': emergencyContactPhone,
          'address': address,
          'status': 'awaiting_payment',
        })
        .select()
        .single();

    if (selectedSubjectIds.isNotEmpty) {
      await _client.from('admission_request_subjects').insert([
        for (final subjectId in selectedSubjectIds) {'admission_request_id': request['id'], 'subject_id': subjectId},
      ]);
    }
  }
  // --------------------------------------------------
  // ALL TEACHERS (for slot-filling - includes pending ones)
  // --------------------------------------------------

  Future<List<AllTeacherProfile>> getAllTeachers(String schoolId) async {
    final rows = await _client
        .from('teachers')
        .select('id, user_id, full_name, phone, is_approved, users(email)')
        .eq('school_id', schoolId)
        .order('full_name');
    return rows.map((r) => AllTeacherProfile.fromMap(r)).toList();
  }

  

/// Only departments/classes that actually have marks for this term
/// - mirrors the marks-review drill-down, so the Principal only
/// ever sees paths that lead somewhere real.
Future<List<DepartmentFull>> getDepartmentsWithMarksForTerm(
  String schoolId,
  String termId,
) async {
  final rows = await _client
      .from('marks')
      .select(
        'classes(department_id, departments(id, department_name, department_type))',
      )
      .eq('school_id', schoolId)
      .inFilter(
        'exam_period_id',
        await _examPeriodIdsForTerm(termId),
      )
      .eq('status', 'approved');

  final seen = <String, DepartmentFull>{};

  for (final r in rows) {
    final cls = r['classes'] is Map
        ? Map<String, dynamic>.from(r['classes'] as Map)
        : null;

    final dept = cls?['departments'] is Map
        ? Map<String, dynamic>.from(cls!['departments'] as Map)
        : null;

    if (dept != null) {
      final id = dept['id'] as String;

      seen[id] = DepartmentFull(
        id: id,
        departmentName: dept['department_name'] as String? ?? '',
        departmentType: dept['department_type'] as String?,
      );
    }
  }

  return seen.values.toList()
    ..sort(
      (a, b) => a.departmentName.compareTo(b.departmentName),
    );
}


Future<List<ManagedClass>> getClassesWithMarksForTerm(
  String schoolId,
  String termId,
  String departmentId,
) async {
  final rows = await _client
      .from('marks')
      .select(
        'classes('
        'id, '
        'class_name, '
        'class_code, '
        'department_id, '
        'level_order, '
        'max_students, '
        'is_active, '
        'departments(department_name)'
        ')',
      )
      .eq('school_id', schoolId)
      .inFilter(
        'exam_period_id',
        await _examPeriodIdsForTerm(termId),
      )
      .eq('status', 'approved');

  final seen = <String, ManagedClass>{};

  for (final r in rows) {
    final cls = r['classes'] is Map
        ? Map<String, dynamic>.from(r['classes'] as Map)
        : null;

    if (cls != null && cls['department_id'] == departmentId) {
      final id = cls['id'] as String;

      seen[id] = ManagedClass.fromMap(cls);
    }
  }

  return seen.values.toList()
    ..sort(
      (a, b) => a.className.compareTo(b.className),
    );
}


/// Every report card already generated for a class+term, regardless
/// of publish state - a distinct list from "students eligible for
/// generation," so the Principal can see what already exists and
/// discard it if needed, separate from the generate/publish flow.
Future<List<ReportCardStatus>> getGeneratedReportCards(
  String classId,
  String termId,
) async {
  final rows = await _client
      .from('report_cards')
      .select(
        'id, '
        'student_id, '
        'is_published, '
        'publish_at, '
        'students(first_name, last_name)',
      )
      .eq('class_id', classId)
      .eq('term_id', termId);

  return rows.map((r) {
    final student = r['students'] is Map
        ? Map<String, dynamic>.from(r['students'] as Map)
        : null;

    return ReportCardStatus(
      studentId: r['student_id'] as String,
      studentName:
          '${student?['first_name'] ?? ''} '
          '${student?['last_name'] ?? ''}'.trim(),
      reportCardId: r['id'] as String,
      exists: true,
      isPublished: r['is_published'] as bool? ?? false,
      publishAt: DateTime.tryParse(
        r['publish_at'] as String? ?? '',
      ),
    );
  }).toList()
    ..sort(
      (a, b) => a.studentName.compareTo(b.studentName),
    );
}


Future<void> deleteReportCard(String reportCardId) async {
  await _client
      .from('subject_results')
      .delete()
      .eq('report_card_id', reportCardId);

  await _client
      .from('report_cards')
      .delete()
      .eq('id', reportCardId);
}
  
  // --------------------------------------------------
  // FEES + INSTALLMENTS - per class, per academic year
  // --------------------------------------------------

  Future<ManagedFeeConfig> getFeeConfig({required String classId, required String academicYearId}) async {
    final feeRow = await _client
        .from('fees')
        .select('id, registration_fee, total_school_fee, installments(id, installment_name, amount, due_date, display_order)')
        .eq('class_id', classId)
        .eq('academic_year_id', academicYearId)
        .maybeSingle();

    if (feeRow == null) return ManagedFeeConfig.empty();
    return ManagedFeeConfig.fromMap(feeRow, feeRow['installments'] as List);
  }

  Future<void> saveFeeConfig({
    required String schoolId,
    required String classId,
    required String academicYearId,
    required ManagedFeeConfig config,
  }) async {
    String feeId;
    if (config.feeId == null) {
      final inserted = await _client
          .from('fees')
          .insert({
            'school_id': schoolId,
            'class_id': classId,
            'academic_year_id': academicYearId,
            'registration_fee': config.registrationFee,
            'total_school_fee': config.totalSchoolFee,
          })
          .select()
          .single();
      feeId = inserted['id'] as String;
    } else {
      feeId = config.feeId!;
      await _client.from('fees').update({
        'registration_fee': config.registrationFee,
        'total_school_fee': config.totalSchoolFee,
      }).eq('id', feeId);
    }

    // Replace installments wholesale - simpler and safer than diffing
    // individual rows for a form that's edited as a whole each time.
    await _client.from('installments').delete().eq('fee_id', feeId);
    if (config.installments.isNotEmpty) {
      await _client.from('installments').insert([
        for (var i = 0; i < config.installments.length; i++)
          {
            'fee_id': feeId,
            'installment_name': config.installments[i].name,
            'amount': config.installments[i].amount,
            'due_date': config.installments[i].dueDate?.toIso8601String(),
            'display_order': i + 1,
          },
      ]);
    }
  }
}
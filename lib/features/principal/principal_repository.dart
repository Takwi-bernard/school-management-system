import 'package:supabase_flutter/supabase_flutter.dart';
import 'principal_models.dart';

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
    int? preferredDay,
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

    if (preferredDay != null) {
      await _client.from('teacher_period_preferences').insert({
        'school_id': schoolId,
        'teacher_assignment_id': inserted['id'],
        'preferred_day': preferredDay,
        'preferred_start_time': preferredStartTime,
        'preferred_end_time': preferredEndTime,
      });
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _client.from('teacher_assignments').delete().eq('id', assignmentId);
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
  Future<void> generateReportCard({
    required String schoolId,
    required String studentId,
    required String classId,
    required String termId,
    required String academicYearId,
  }) async {
    final marksRows = await _client
        .from('marks')
        .select('score, coefficient, subject_id')
        .eq('student_id', studentId)
        .eq('academic_year_id', academicYearId)
        .eq('status', 'approved')
        .inFilter('exam_period_id', await _examPeriodIdsForTerm(termId));

    if (marksRows.isEmpty) {
      throw Exception('No approved marks found for this student in this term.');
    }

    double totalWeighted = 0;
    int totalCoefficient = 0;
    for (final m in marksRows) {
      final score = (m['score'] as num).toDouble();
      final coef = m['coefficient'] as int;
      totalWeighted += score * coef;
      totalCoefficient += coef;
    }
    final average = totalCoefficient == 0 ? 0.0 : totalWeighted / totalCoefficient;

    final reportCard = await _client
        .from('report_cards')
        .upsert({
          'school_id': schoolId,
          'student_id': studentId,
          'class_id': classId,
          'term_id': termId,
          'overall_average': average,
          'generated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'student_id, term_id')
        .select()
        .single();

    final reportCardId = reportCard['id'] as String;

    await _client.from('subject_results').delete().eq('report_card_id', reportCardId);
    await _client.from('subject_results').insert([
      for (final m in marksRows)
        {
          'report_card_id': reportCardId,
          'subject_id': m['subject_id'],
          'score': m['score'],
          'coefficient': m['coefficient'],
          'weighted_score': (m['score'] as num).toDouble() * (m['coefficient'] as int),
        },
    ]);
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
        await generateReportCard(schoolId: schoolId, studentId: s.studentId, classId: classId, termId: termId, academicYearId: academicYearId);
        succeeded++;
      } catch (_) {
        skipped++; // e.g. this student has no approved marks yet - not fatal, continue with the rest
      }
    }
    return {'succeeded': succeeded, 'skipped': skipped, 'total': students.length};
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

  /// Filling a slot with a pending teacher approves them as part of
  /// this same action - a separate silent auto-approve would hide
  /// what just happened; this makes the approval explicit in the
  /// same confirmation the UI already shows before calling it.
  Future<void> approveAndAssign({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
    required bool wasAlreadyApproved,
    required String principalId,
    required String classId,
    required String subjectId,
    required int periodsPerWeek,
    int? preferredDay,
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
      preferredDay: preferredDay,
      preferredStartTime: preferredStartTime,
      preferredEndTime: preferredEndTime,
    );
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
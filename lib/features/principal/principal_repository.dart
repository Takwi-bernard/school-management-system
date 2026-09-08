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

  Future<void> createClass({
    required String schoolId,
    required String className,
    String? classCode,
    required String departmentId,
    required int levelOrder,
    required int maxStudents,
  }) async {
    await _client.from('classes').insert({
      'school_id': schoolId,
      'class_name': className,
      'class_code': classCode,
      'department_id': departmentId,
      'level_order': levelOrder,
      'max_students': maxStudents,
    });
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
    await _client.from('subject_offerings').upsert({
      'class_id': classId,
      'subject_id': subjectId,
      'is_compulsory': isCompulsory,
      'is_selectable': true,
    }, onConflict: 'class_id, subject_id');
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
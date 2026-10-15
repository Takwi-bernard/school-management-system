import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'principal_core.dart' show pnIso;
import 'principal_hub_models.dart';
import 'principal_models.dart' show TimetableSlot;

/// Data access for the Principal's calendar, ranking, promotion, money
/// and overview features. Almost everything is a single database
/// function call, so a screen costs one round trip however large the
/// school is.
class PrincipalHubRepository {
  final SupabaseClient _client;
  PrincipalHubRepository(this._client);

  Future<Map<String, dynamic>> _map(String fn, [Map<String, dynamic>? params]) async {
    final res = await _client.rpc(fn, params: params);
    return pnMap(res);
  }

  Future<List<Map<String, dynamic>>> _list(String fn, [Map<String, dynamic>? params]) async {
    final res = await _client.rpc(fn, params: params);
    return pnList(res);
  }

  // ------------------------------------------------------------ overview

  Future<PnOverview> getOverview() async => PnOverview.fromMap(await _map('principal_overview'));

  // ------------------------------------------------------------ teachers

  /// Every teacher at the school with email, photo and the assignments of
  /// the given year (the current year when null).
  Future<List<PnTeacher>> getTeachers(String? yearId) async {
    final res = await _client.rpc('principal_teachers', params: {'p_year': yearId});
    return pnList(res).map(PnTeacher.fromMap).toList();
  }

  // ------------------------------------------------------------ analytics

  Future<PnAnalytics> getAnalytics(String? periodId) async =>
      PnAnalytics.fromMap(await _map('principal_analytics', {'p_period': periodId}));

  Future<PnAiReport?> getLatestAiReport(String schoolId) async {
    final row = await _client
        .from('principal_ai_reports')
        .select()
        .eq('school_id', schoolId)
        .order('generated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : PnAiReport.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> _invokeAi(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('analyze-principal-insights', body: body);
      final data = res.data;
      if (data is! Map) throw Exception('Bad response');
      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) throw Exception(map['message'] ?? 'Request failed');
      return map;
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map ? d['message'] : null;
      throw Exception(msg ?? 'Request failed (${e.status})');
    }
  }

  Future<PnAiReport> generateAiReport({required String lang, String? periodId}) async {
    final map = await _invokeAi({'mode': 'report', 'lang': lang, 'period_id': periodId});
    return PnAiReport.fromMap(Map<String, dynamic>.from(map['report'] as Map));
  }

  Future<String> askAi({required String lang, required String question, String? periodId}) async {
    final map = await _invokeAi({'mode': 'ask', 'lang': lang, 'question': question, 'period_id': periodId});
    return '${map['answer'] ?? ''}';
  }

  // ------------------------------------------------------------ settings

  Future<PnSettings> getSettings(String schoolId) async {
    final row = await _client.from('school_academic_settings').select().eq('school_id', schoolId).maybeSingle();
    return row == null ? PnSettings.defaults : PnSettings.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> saveSettings(String schoolId, PnSettings s) async {
    await _client.from('school_academic_settings').upsert({
      'school_id': schoolId,
      'pass_mark': s.passMark,
      'borderline_margin': s.margin,
      'payment_approval_threshold': s.threshold,
      'balance_classes': s.balance,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'school_id');
  }

  // ------------------------------------------------------------ calendar

  Future<List<PnYear>> getCalendar() async {
    final m = await _map('principal_calendar');
    return pnList(m['years']).map(PnYear.fromMap).toList();
  }

  Future<String> createYear({
    required String name,
    required DateTime start,
    required DateTime end,
    required List<PnTermDraft> terms,
    required bool makeCurrent,
    String? copyFeesFrom,
  }) async {
    final res = await _client.rpc('principal_create_academic_year', params: {
      'p_year_name': name,
      'p_start': pnIso(start),
      'p_end': pnIso(end),
      'p_terms': [for (final t in terms) t.toJson(pnIso)],
      'p_make_current': makeCurrent,
      'p_copy_fees_from': copyFeesFrom,
    });
    return '$res';
  }

  Future<void> updateYear({required String id, required String name, required DateTime start, required DateTime end}) async {
    await _client.rpc('principal_update_academic_year', params: {
      'p_year_id': id,
      'p_year_name': name,
      'p_start': pnIso(start),
      'p_end': pnIso(end),
    });
  }

  Future<void> setCurrentYear(String yearId) async {
    await _client.rpc('principal_set_current_year', params: {'p_year_id': yearId});
  }

  Future<void> setCurrentTerm(String termId) async {
    await _client.rpc('principal_set_current_term', params: {'p_term_id': termId});
  }

  Future<void> upsertTerm({required String yearId, String? termId, required String name, DateTime? start, DateTime? end}) async {
    await _client.rpc('principal_upsert_term', params: {
      'p_year_id': yearId,
      'p_term_id': termId,
      'p_name': name,
      'p_start': start == null ? null : pnIso(start),
      'p_end': end == null ? null : pnIso(end),
    });
  }

  Future<void> deleteTerm(String termId) async {
    await _client.rpc('principal_delete_term', params: {'p_term_id': termId});
  }

  Future<void> upsertSequence({
    required String termId,
    String? periodId,
    required String name,
    DateTime? start,
    DateTime? end,
    DateTime? marksDue,
  }) async {
    await _client.rpc('principal_upsert_sequence', params: {
      'p_term_id': termId,
      'p_period_id': periodId,
      'p_name': name,
      'p_start': start == null ? null : pnIso(start),
      'p_end': end == null ? null : pnIso(end),
      'p_marks_due': marksDue == null ? null : pnIso(marksDue),
    });
  }

  Future<void> deleteSequence(String periodId) async {
    await _client.rpc('principal_delete_sequence', params: {'p_period_id': periodId});
  }

  Future<void> setSequenceOpen(String periodId, bool open) async {
    await _client.from('exam_periods').update({'is_open': open}).eq('id', periodId);
  }

  // ------------------------------------------------------------ classes

  Future<List<PnClass>> getClasses(String schoolId) async {
    final rows = await _client
        .from('classes')
        .select('id, class_name, level_order, max_students, department_id, departments(department_name)')
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('level_order')
        .order('class_name');
    return rows.map((r) => PnClass.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  // ------------------------------------------------------------ report cards

  Future<PnBoard> getBoard({
    required String classId,
    required String scope,
    required String yearId,
    String? termId,
    String? periodId,
  }) async {
    final m = await _map('principal_report_card_board', {
      'p_class_id': classId,
      'p_scope': scope,
      'p_academic_year_id': yearId,
      'p_term_id': termId,
      'p_exam_period_id': periodId,
    });
    return PnBoard.fromMap(m);
  }

  Future<Map<String, dynamic>> generateCards({
    required String classId,
    required String scope,
    required String yearId,
    String? termId,
    String? periodId,
    String? studentId,
  }) {
    return _map('principal_generate_report_cards', {
      'p_class_id': classId,
      'p_scope': scope,
      'p_academic_year_id': yearId,
      'p_term_id': termId,
      'p_exam_period_id': periodId,
      'p_student_id': studentId,
    });
  }

  Future<Map<String, dynamic>> generateCardsBulk({
    required List<String> classIds,
    required String scope,
    required String yearId,
    String? termId,
    String? periodId,
  }) {
    return _map('principal_generate_report_cards_bulk', {
      'p_class_ids': classIds,
      'p_scope': scope,
      'p_academic_year_id': yearId,
      'p_term_id': termId,
      'p_exam_period_id': periodId,
    });
  }

  Future<int> publishCards(List<String> cardIds, bool publish, {DateTime? at}) async {
    final res = await _client.rpc('principal_publish_report_cards', params: {
      'p_card_ids': cardIds,
      'p_publish': publish,
      'p_publish_at': at?.toUtc().toIso8601String(),
    });
    return res is num ? res.toInt() : 0;
  }

  Future<void> setCardComment(String cardId, String? comment) async {
    await _client.from('report_cards').update({
      'principal_comment': (comment == null || comment.trim().isEmpty) ? null : comment.trim(),
      'pdf_url': null, // the PDF is rebuilt with the new remark
    }).eq('id', cardId);
  }

  Future<String> uploadGeneratedPdf({required String schoolId, required Uint8List bytes, required String prefix}) async {
    final path = '$schoolId/${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _client.storage.from('generated-documents').uploadBinary(path, bytes);
    return _client.storage.from('generated-documents').createSignedUrl(path, 60 * 60 * 24 * 365);
  }

  Future<void> savePdfUrl(String cardId, String url) async {
    await _client.from('report_cards').update({'pdf_url': url}).eq('id', cardId);
  }

  /// Everything the PDF of one report card needs, for any scope. The
  /// per-column breakdown comes from the approved marks (sequence and
  /// term) or from the term cards (year).
  Future<PnCardPdfData> getCardPdfData(String cardId, {required String yearLabelFallback}) async {
    final rc = await _client
        .from('report_cards')
        .select('*, students(first_name, last_name, student_photo_url, admission_number), classes(class_name), academic_terms(term_name), exam_periods(period_name)')
        .eq('id', cardId)
        .single();

    final student = pnMap(rc['students']);
    final cls = pnMap(rc['classes']);
    final scope = pnS(rc['report_scope']);
    final studentId = pnS(rc['student_id']);
    final yearId = pnS(rc['academic_year_id']);

    List<String> columns;
    List<String> columnIds;
    String label;

    if (scope == 'sequence') {
      final p = pnS(pnMap(rc['exam_periods'])['period_name']);
      columns = [p];
      columnIds = [pnS(rc['exam_period_id'])];
      label = p;
    } else if (scope == 'term') {
      final rows = await _client.from('exam_periods').select('id, period_name').eq('academic_term_id', rc['term_id']).order('sequence_order');
      columns = rows.map((r) => pnS(r['period_name'])).toList();
      columnIds = rows.map((r) => pnS(r['id'])).toList();
      label = pnS(pnMap(rc['academic_terms'])['term_name']);
    } else {
      final rows = await _client.from('academic_terms').select('id, term_name').eq('academic_year_id', yearId).order('term_order');
      columns = rows.map((r) => pnS(r['term_name'])).toList();
      columnIds = rows.map((r) => pnS(r['id'])).toList();
      final y = await _client.from('academic_years').select('year_name').eq('id', yearId).maybeSingle();
      label = y == null ? yearLabelFallback : pnS(y['year_name']);
    }

    // subject name -> (coefficient, scores per column)
    final byName = <String, Map<String, dynamic>>{};

    if (scope == 'year') {
      final cards = await _client
          .from('report_cards')
          .select('term_id, subject_results(subject_id, score, coefficient)')
          .eq('student_id', studentId)
          .eq('academic_year_id', yearId)
          .eq('report_scope', 'term');
      final subjectIds = <String>{};
      for (final c in cards) {
        for (final sr in pnList(c['subject_results'])) {
          subjectIds.add(pnS(sr['subject_id']));
        }
      }
      final names = <String, String>{};
      if (subjectIds.isNotEmpty) {
        final subs = await _client.from('subjects').select('id, subject_name').inFilter('id', subjectIds.toList());
        for (final s in subs) {
          names[pnS(s['id'])] = pnS(s['subject_name']);
        }
      }
      for (final c in cards) {
        final col = columnIds.indexOf(pnS(c['term_id']));
        if (col < 0) continue;
        for (final sr in pnList(c['subject_results'])) {
          final name = names[pnS(sr['subject_id'])] ?? '';
          final entry = byName.putIfAbsent(name, () => {'coef': pnI(sr['coefficient']), 'scores': List<double?>.filled(columns.length, null)});
          (entry['scores'] as List<double?>)[col] = pnDn(sr['score']);
        }
      }
    } else {
      final marks = await _client
          .from('marks')
          .select('score, coefficient, exam_period_id, subjects(subject_name)')
          .eq('student_id', studentId)
          .inFilter('exam_period_id', columnIds)
          .eq('status', 'approved');
      for (final m in marks) {
        final name = pnS(pnMap(m['subjects'])['subject_name']);
        final col = columnIds.indexOf(pnS(m['exam_period_id']));
        if (col < 0) continue;
        final entry = byName.putIfAbsent(name, () => {'coef': pnI(m['coefficient']), 'scores': List<double?>.filled(columns.length, null)});
        (entry['scores'] as List<double?>)[col] = pnDn(m['score']);
      }
    }

    final subjects = byName.entries.map((e) {
      final scores = e.value['scores'] as List<double?>;
      final present = scores.whereType<double>().toList();
      final avg = present.isEmpty ? 0.0 : present.reduce((a, b) => a + b) / present.length;
      return PnPdfSubject(name: e.key, coefficient: e.value['coef'] as int, scores: scores, average: avg);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return PnCardPdfData(
      studentName: '${pnS(student['first_name'])} ${pnS(student['last_name'])}'.trim(),
      studentPhotoUrl: pnSn(student['student_photo_url']),
      admissionNumber: pnSn(student['admission_number']),
      className: pnS(cls['class_name']),
      reportLabel: label,
      scope: scope,
      columns: columns,
      subjects: subjects,
      overallAverage: pnD(rc['overall_average']),
      rank: pnIn(rc['class_rank']),
      total: pnIn(rc['total_students']),
      principalComment: pnSn(rc['principal_comment']),
    );
  }

  // ------------------------------------------------------------ promotion

  Future<PnPromoData> getPromotionData(String fromYear, String toYear) async {
    final m = await _map('principal_promotion_candidates', {'p_from_year': fromYear, 'p_to_year': toYear});
    return PnPromoData.fromMap(m);
  }

  Future<Map<String, dynamic>> applyPromotion({
    required String fromYear,
    required String toYear,
    required double passMark,
    required List<Map<String, dynamic>> decisions,
    String? note,
  }) {
    return _map('principal_promotion_apply', {
      'p_from_year': fromYear,
      'p_to_year': toYear,
      'p_pass_mark': passMark,
      'p_decisions': decisions,
      'p_note': note,
    });
  }

  Future<void> undoPromotion(String runId) async {
    await _client.rpc('principal_promotion_undo', params: {'p_run_id': runId});
  }

  Future<List<PnPromotionRun>> getPromotionHistory() async {
    final res = await _client.rpc('principal_promotion_history');
    return pnList(res).map(PnPromotionRun.fromMap).toList();
  }

  // ------------------------------------------------------------ students

  Future<PnStudentPage> getStudents({required String yearId, String? search, String? classId, int limit = 40, int offset = 0}) async {
    final m = await _map('principal_students_page', {
      'p_year': yearId,
      'p_search': (search == null || search.trim().isEmpty) ? null : search.trim(),
      'p_class': classId,
      'p_limit': limit,
      'p_offset': offset,
    });
    return PnStudentPage(total: pnI(m['total']), rows: pnList(m['rows']).map(PnStudentRow.fromMap).toList());
  }

  Future<void> moveStudent({required String studentId, required String yearId, required String toClassId, String? reason}) async {
    await _client.rpc('principal_move_student', params: {'p_student': studentId, 'p_year': yearId, 'p_to_class': toClassId, 'p_reason': reason});
  }

  Future<void> setStudentStatus({required String studentId, required String status, String? reason}) async {
    await _client.rpc('principal_set_student_status', params: {'p_student': studentId, 'p_status': status, 'p_reason': reason});
  }

  // ------------------------------------------------------------ money

  Future<List<PnTeacherPay>> getTeacherPay({required String yearId, required DateTime month}) async {
    final rows = await _list('principal_teacher_pay_overview', {'p_year': yearId, 'p_month': pnIso(DateTime(month.year, month.month, 1))});
    return rows.map(PnTeacherPay.fromMap).toList();
  }

  Future<({int total, List<PnTeacherPayment> rows})> getTeacherPayments({int limit = 40, int offset = 0, String? teacherId}) async {
    final m = await _map('principal_teacher_payments', {'p_limit': limit, 'p_offset': offset, 'p_teacher': teacherId});
    return (total: pnI(m['total']), rows: pnList(m['rows']).map(PnTeacherPayment.fromMap).toList());
  }

  Future<void> saveTeacherPayProfile({
    required String schoolId,
    required String teacherId,
    required String payType,
    required double monthlyAmount,
    required double hourlyRate,
    required double weeksPerMonth,
    String? notes,
  }) async {
    await _client.from('teacher_pay_profiles').upsert({
      'teacher_id': teacherId,
      'school_id': schoolId,
      'pay_type': payType,
      'monthly_amount': monthlyAmount,
      'hourly_rate': hourlyRate,
      'weeks_per_month': weeksPerMonth,
      'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'teacher_id');
  }

  /// Returns true when the amount crossed the approval threshold and was
  /// flagged for the proprietor.
  Future<bool> recordTeacherPayment({
    required String teacherId,
    required double amount,
    required String method,
    required String kind,
    DateTime? periodMonth,
    String? purpose,
    String? paidTo,
    DateTime? paidAt,
    String? place,
    String? reference,
    String? notes,
    String? yearId,
  }) async {
    final m = await _map('principal_record_teacher_payment', {
      'p_teacher_id': teacherId,
      'p_amount': amount,
      'p_method': method,
      'p_kind': kind,
      'p_period_month': periodMonth == null ? null : pnIso(DateTime(periodMonth.year, periodMonth.month, 1)),
      'p_purpose': purpose,
      'p_paid_to': paidTo,
      'p_paid_at': paidAt?.toUtc().toIso8601String(),
      'p_place': place,
      'p_reference': reference,
      'p_notes': notes,
      'p_academic_year_id': yearId,
    });
    return pnB(m['flagged']);
  }

  Future<void> voidTeacherPayment(String id, String reason) async {
    await _client.rpc('principal_void_teacher_payment', params: {'p_payment_id': id, 'p_reason': reason});
  }

  Future<List<PnExpense>> getMyExpenses({int limit = 60, int offset = 0}) async {
    final rows = await _client
        .from('expenses')
        .select('id, category, description, amount, expense_date, payment_method, paid_to, place, source, needs_review')
        .inFilter('source', ['principal', 'teacher_payment'])
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((r) => PnExpense.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<bool> recordExpense({
    required String category,
    required String description,
    required double amount,
    required DateTime date,
    required String method,
    String? paidTo,
    String? place,
    String? reference,
    String? receiptRef,
  }) async {
    final m = await _map('principal_record_expense', {
      'p_category': category,
      'p_description': description,
      'p_amount': amount,
      'p_date': pnIso(date),
      'p_method': method,
      'p_paid_to': paidTo,
      'p_place': place,
      'p_reference': reference,
      'p_receipt_url': receiptRef,
    });
    return pnB(m['flagged']);
  }

  Future<String> uploadReceipt({required String schoolId, required Uint8List bytes, required String extension}) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$schoolId/$uid/expense_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('expense-receipts').uploadBinary(path, bytes);
    return path;
  }

  Future<List<PnCorrection>> getCorrections({bool includeResolved = false}) async {
    final rows = await _list('principal_correction_inbox', {'p_include_resolved': includeResolved});
    return rows.map(PnCorrection.fromMap).toList();
  }

  Future<void> resolveCorrection({required String paymentId, required bool approve, String? note}) async {
    await _client.rpc('principal_resolve_correction', params: {
      'p_payment_id': paymentId,
      'p_action': approve ? 'approve' : 'decline',
      'p_note': note,
    });
  }

  Future<PnArrears> getArrears({required String yearId, String? classId, int limit = 60, int offset = 0}) async {
    final m = await _map('principal_fee_arrears', {'p_year': yearId, 'p_class': classId, 'p_limit': limit, 'p_offset': offset});
    return PnArrears.fromMap(m);
  }

  // ------------------------------------------------------------ marks tracker

  Future<List<PnTrackerRow>> getMarksTracker(String periodId) async {
    final rows = await _list('principal_marks_tracker', {'p_exam_period_id': periodId});
    return rows.map(PnTrackerRow.fromMap).toList();
  }

  // ------------------------------------------------------------ marks review (second pass)

  Future<List<Map<String, dynamic>>> getMarksReviewSummary(String periodId) async {
    final res = await _client.rpc('principal_marks_review_summary', params: {'p_period': periodId});
    return pnList(res);
  }

  Future<int> approveMarks({required String periodId, String? classId, String? subjectId, List<String>? ids}) async {
    final res = await _client.rpc('principal_approve_marks', params: {
      'p_period': periodId,
      'p_class': classId,
      'p_subject': subjectId,
      'p_ids': ids,
    });
    return res is num ? res.toInt() : 0;
  }

  /// Non-destructive fee save: existing installments are updated in place
  /// (so payments linked to them stay valid), new ones are inserted and
  /// only the ones the principal removed are deleted.
  Future<void> saveFeesSafe({
    required String schoolId,
    required String classId,
    required String yearId,
    required String? feeId,
    required double registrationFee,
    required List<({String? id, String name, double amount, DateTime? due})> installments,
    required List<String> removedIds,
  }) async {
    final total = installments.fold<double>(0, (a, i) => a + i.amount);
    String fid;
    if (feeId == null) {
      final inserted = await _client
          .from('fees')
          .insert({'school_id': schoolId, 'class_id': classId, 'academic_year_id': yearId, 'registration_fee': registrationFee, 'total_school_fee': total})
          .select('id')
          .single();
      fid = inserted['id'] as String;
    } else {
      fid = feeId;
      await _client.from('fees').update({'registration_fee': registrationFee, 'total_school_fee': total}).eq('id', fid);
    }
    for (var i = 0; i < installments.length; i++) {
      final it = installments[i];
      final row = {
        'installment_name': it.name,
        'amount': it.amount,
        'due_date': it.due == null ? null : pnIso(it.due!),
        'display_order': i + 1,
      };
      if (it.id == null) {
        await _client.from('installments').insert({...row, 'fee_id': fid});
      } else {
        await _client.from('installments').update(row).eq('id', it.id!);
      }
    }
    if (removedIds.isNotEmpty) {
      await _client.from('installments').delete().inFilter('id', removedIds);
    }
  }

  /// Every timetable slot of the given classes for a year, fetched in
  /// pages of 1000 so a whole-school timetable is never silently cut off.
  Future<Map<String, List<TimetableSlot>>> getTimetablePaged(List<String> classIds, String yearId) async {
    if (classIds.isEmpty) return {};
    final grouped = <String, List<TimetableSlot>>{};
    const page = 1000;
    var from = 0;
    while (true) {
      final rows = await _client
          .from('timetable_items')
          .select('''
            id, class_id, day_of_week, start_time, end_time, room_name, needs_teacher,
            teacher_assignments ( subjects(subject_name), teachers(full_name) ),
            subjects ( subject_name ),
            timetables!inner(academic_year_id)
          ''')
          .inFilter('class_id', classIds)
          .eq('timetables.academic_year_id', yearId)
          .order('id')
          .range(from, from + page - 1);
      for (final r in rows) {
        grouped.putIfAbsent(r['class_id'] as String, () => []).add(TimetableSlot.fromMap(r));
      }
      if (rows.length < page) break;
      from += page;
    }
    return grouped;
  }
}

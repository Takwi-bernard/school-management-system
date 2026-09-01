import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parent_models.dart';

class ParentRepository {
  ParentRepository(this._client);
  final SupabaseClient _client;

  // --------------------------------------------------
  // PROFILE
  // --------------------------------------------------

  Future<ParentProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('parents')
        .select('id, user_id, school_id, full_name, phone, users(email)')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return ParentProfile.fromMap(row);
  }

  // --------------------------------------------------
  // CHILDREN - both real students AND requests still in progress
  // --------------------------------------------------

  Future<List<EnrolledChild>> getEnrolledChildren(String parentId) async {
    final rows = await _client
        .from('student_guardians')
        .select('''
          students!inner (
            id, school_id, admission_number, first_name, last_name,
            student_photo_url, current_status,
            class_enrollments (
              enrollment_status,
              classes ( id, class_name )
            )
          ),
          guardians!inner ( parent_id )
        ''')
        .eq('guardians.parent_id', parentId);

    return rows
        .map((r) => EnrolledChild.fromMap(r['students'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<PendingAdmission>> getPendingAdmissions(String parentId) async {
    final rows = await _client
        .from('admission_requests')
        .select('*, classes(class_name)')
        .eq('parent_id', parentId)
        .not('status', 'eq', 'approved') // approved ones become real students above
        .order('created_at', ascending: false);

    return rows.map((r) => PendingAdmission.fromMap(r)).toList();
  }

  // --------------------------------------------------
  // ENROLLMENT - dynamic classes + subject offerings, never hardcoded
  // --------------------------------------------------

  Future<List<ClassOption>> getAvailableClasses(String schoolId) async {
    final rows = await _client
        .from('classes')
        .select('id, class_name, department_id')
        .eq('school_id', schoolId)
        .order('level_order');
    return rows.map((r) => ClassOption.fromMap(r)).toList();
  }

  /// Looks up offerings for the class first; if none exist, falls back
  /// to the class's department (per the school's own chosen scope -
  /// see subject_offerings design). Empty result = no subject choice
  /// step needed for this class at all.
  Future<List<SubjectOfferingOption>> getSubjectOfferings({
    required String classId,
    required String? departmentId,
  }) async {
    final byClass = await _client
        .from('subject_offerings')
        .select('subject_id, is_compulsory, subjects(subject_name)')
        .eq('class_id', classId);

    if (byClass.isNotEmpty) {
      return byClass.map((r) => SubjectOfferingOption.fromMap(r)).toList();
    }

    if (departmentId == null) return [];

    final byDepartment = await _client
        .from('subject_offerings')
        .select('subject_id, is_compulsory, subjects(subject_name)')
        .eq('department_id', departmentId);

    return byDepartment.map((r) => SubjectOfferingOption.fromMap(r)).toList();
  }

   Future<String> submitAdmissionRequest({
    required String schoolId,
    required String parentId,
    required String requestedClassId,
    required String academicYearId,
    required String firstName,
    required String lastName,
    String? gender,
    DateTime? dateOfBirth,
    String? guardianName,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? address,
    Uint8List? photoBytes,
    String? photoExtension,
    required List<String> selectedSubjectIds,
  }) async {
    String? photoUrl;
    if (photoBytes != null && photoExtension != null) {
      final path = '$schoolId/$parentId/${DateTime.now().millisecondsSinceEpoch}.$photoExtension';
      await _client.storage.from('student-photos').uploadBinary(path, photoBytes);
      photoUrl = _client.storage.from('student-photos').getPublicUrl(path);
    }

    final request = await _client
        .from('admission_requests')
        .insert({
          'school_id': schoolId,
          'parent_id': parentId,
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
          'photo_url': photoUrl,
          // FIX: was 'submitted', which PendingAdmission.needsPayment
          // never matches - the dashboard showed "under review" the
          // instant the form was submitted, before any payment. A
          // brand-new admission is ALWAYS unpaid at this point, so it
          // must start in the payment-pending state, not "under review".
          'status': 'awaiting_payment',
        })
        .select()
        .single();

    if (selectedSubjectIds.isNotEmpty) {
      await _client.from('admission_request_subjects').insert([
        for (final subjectId in selectedSubjectIds)
          {'admission_request_id': request['id'], 'subject_id': subjectId},
      ]);
    }

    return request['id'] as String;
  }
  // --------------------------------------------------
  // ACADEMIC TERMS (for the report card term picker - dynamic, not
  // assumed to always be exactly 3)
  // --------------------------------------------------

  Future<List<AcademicTermOption>> getTermsForYear(String academicYearId) async {
    final rows = await _client
        .from('academic_terms')
        .select('id, term_name, term_order, is_current')
        .eq('academic_year_id', academicYearId)
        .order('term_order');
    return rows.map((r) => AcademicTermOption.fromMap(r)).toList();
  }

  // --------------------------------------------------
  // REPORT CARD - a row only exists once the school has generated
  // it; absence of a row IS the "not yet published" state, not an error.
  // --------------------------------------------------

  Future<ReportCardSummary?> getReportCard({
    required String studentId,
    required String termId,
  }) async {
    final reportRow = await _client
        .from('report_cards')
        .select('''
          id, overall_average, class_rank, total_students, principal_comment, generated_at,
          students ( first_name, last_name ),
          classes ( class_name ),
          academic_terms ( term_name )
        ''')
        .eq('student_id', studentId)
        .eq('term_id', termId)
        .maybeSingle();

    if (reportRow == null) return null;

    final subjectRows = await _client
        .from('subject_results')
        .select('score, coefficient, weighted_score, grade, remark, subjects(subject_name)')
        .eq('report_card_id', reportRow['id']);

    return ReportCardSummary.fromMap(reportRow, subjectRows);
  }

  // --------------------------------------------------
  // ATTENDANCE SUMMARY
  // --------------------------------------------------

  Future<AttendanceSummary> getAttendanceSummary({
    required String studentId,
    required String academicYearId,
  }) async {
    final rows = await _client
        .from('attendance')
        .select('status')
        .eq('student_id', studentId)
        .eq('academic_year_id', academicYearId);

    var present = 0, absent = 0, late = 0, excused = 0;
    for (final r in rows) {
      switch (r['status']) {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'late':
          late++;
        case 'excused':
          excused++;
      }
    }
    return AttendanceSummary(present: present, absent: absent, late: late, excused: excused);
  }

  // --------------------------------------------------
  // PROFILE UPDATE
  // --------------------------------------------------

  Future<void> updateProfile({
    required String parentId,
    required String fullName,
    required String phone,
  }) async {
    await _client.from('parents').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', parentId);
  }

  // --------------------------------------------------
  // CHANGE PASSWORD
  // Supabase's updateUser() alone does NOT verify the current
  // password - it just needs an active session. So we re-authenticate
  // with the CURRENT password first, as a real check, before allowing
  // the change - otherwise "Current Password" would just be theater.
  // --------------------------------------------------

  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException {
      throw Exception('Your current password is incorrect.');
    }

    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // --------------------------------------------------
  // APPROVED TEACHER COMMENTS ONLY - never drafts
  // --------------------------------------------------

  Future<List<TeacherComment>> getApprovedComments(String studentId) async {
    final rows = await _client
        .from('class_comments')
        .select('comment, created_at, teachers(full_name), exam_periods(period_name)')
        .eq('student_id', studentId)
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return rows.map((r) => TeacherComment.fromMap(r)).toList();
  }

  // --------------------------------------------------
  // FEES - fees are keyed by class_id + academic_year_id, with
  // registration_fee and total_school_fee living DIRECTLY on the fees
  // row (not a "name"/"amount" per row - that was a wrong assumption
  // in an earlier draft). Installments use `installment_name`, not
  // `name`.
  // --------------------------------------------------

  Future<List<FeeSummary>> getChildFees({
    required String studentId,
    required String classId,
    required String academicYearId,
  }) async {
    final feeRow = await _client
        .from('fees')
        .select('id, registration_fee, total_school_fee, installments(id, installment_name, amount, due_date, display_order)')
        .eq('class_id', classId)
        .eq('academic_year_id', academicYearId)
        .maybeSingle();

    if (feeRow == null) return [];

    final paidRows = await _client
        .from('payments')
        .select('installment_id, status')
        .eq('student_id', studentId)
        .eq('status', 'success');

    final paidInstallmentIds = paidRows.map((r) => r['installment_id']).toSet();

    final installmentsRaw = List<Map<String, dynamic>>.from(feeRow['installments'] as List);
    installmentsRaw.sort((a, b) => (a['display_order'] as int).compareTo(b['display_order'] as int));

    final installments = installmentsRaw
        .map((i) => InstallmentSummary(
              installmentId: i['id'] as String,
              name: i['installment_name'] as String? ?? '',
              amount: (i['amount'] as num).toDouble(),
              isPaid: paidInstallmentIds.contains(i['id']),
              dueDate: DateTime.tryParse(i['due_date'] as String? ?? ''),
            ))
        .toList();

    final paidAmount = installments.where((i) => i.isPaid).fold(0.0, (sum, i) => sum + i.amount);

    return [
      FeeSummary(
        feeId: feeRow['id'] as String,
        feeName: 'School Fees',
        totalAmount: (feeRow['total_school_fee'] as num).toDouble(),
        amountPaid: paidAmount,
        installments: installments,
      ),
    ];
  }

  /// The registration fee is a single amount per class+year (a column
  /// on `fees`, not a separate row) - used for the pending-admission
  /// "Pay Now" step before a student even exists.
  Future<double?> getRegistrationFee({
    required String classId,
    required String academicYearId,
  }) async {
    final row = await _client
        .from('fees')
        .select('registration_fee')
        .eq('class_id', classId)
        .eq('academic_year_id', academicYearId)
        .maybeSingle();
    return (row?['registration_fee'] as num?)?.toDouble();
  }

  Future<List<PaymentTransaction>> getPaymentHistory(String parentId) async {
    final rows = await _client
        .from('payments')
        .select()
        .eq('parent_id', parentId)
        .order('created_at', ascending: false);
    return rows.map((r) => PaymentTransaction.fromMap(r)).toList();
  }

  // --------------------------------------------------
  // CURRENT ACADEMIC YEAR (by ID, not display name - needed for
  // admission_requests.academic_year_id, which is a UUID foreign key,
  // not the "2025/2026" string LandingModel exposes for display).
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
  // PAYMENT - via Edge Functions only, never direct table writes
  // --------------------------------------------------

  Future<PaymentTransaction> initiatePayment({
    required String schoolId,
    String? childId,
    String? admissionRequestId,
    required double amount,
    required String paymentPurpose,
    required String phoneNumber,
  }) async {
    final response = await _client.functions.invoke('initiate-parent-payment', body: {
      'school_id': schoolId,
      if (childId != null) 'child_id': childId,
      if (admissionRequestId != null) 'admission_request_id': admissionRequestId,
      'amount': amount,
      'payment_purpose': paymentPurpose,
      'phone_number': phoneNumber,
    });

    final data = response.data as Map;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Unable to start payment.');
    }
    return PaymentTransaction.fromMap(Map<String, dynamic>.from(data['transaction']));
  }

  Future<PaymentTransaction> verifyPayment(String transactionId) async {
    final response = await _client.functions.invoke('verify-parent-payment', body: {
      'transaction_id': transactionId,
    });
    final data = response.data as Map;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Unable to verify payment.');
    }
    return PaymentTransaction.fromMap(Map<String, dynamic>.from(data['transaction']));
  }
}
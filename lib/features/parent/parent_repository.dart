import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parent_models.dart';

/// Thrown by changePassword specifically for a wrong CURRENT password,
/// so the UI (which has the locale) can show a localized message
/// instead of a hardcoded English one baked in here.
class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

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
              classes ( id, class_name ),
              academic_years ( is_current )
            )
          ),
          guardians!inner ( parent_id )
        ''')
        .eq('guardians.parent_id', parentId);

    final children = rows
        .map((r) => EnrolledChild.fromMap(r['students'] as Map<String, dynamic>))
        .toList();
    return _withSignedPhotoUrls(children);
  }

  Future<List<PendingAdmission>> getPendingAdmissions(String parentId) async {
    final rows = await _client
        .from('admission_requests')
        .select('*, classes(class_name)')
        .eq('parent_id', parentId)
        .not('status', 'eq', 'approved') // approved ones become real students above
        .order('created_at', ascending: false);

    final admissions = rows.map((r) => PendingAdmission.fromMap(r)).toList();
    final signed = await Future.wait(admissions.map((a) async {
      final path = a.photoUrl;
      if (path == null || path.isEmpty) return a;
      final url = await _signedStudentPhotoUrl(path);
      return a.withPhotoUrl(url);
    }));
    return signed;
  }

  // The student-photos bucket is private, so a stored value can never be
  // opened directly - it must always be re-signed. Handles both a bare
  // storage path (the current format) and an old getPublicUrl-style link
  // from before this fix, so previously-submitted rows keep working.
  static const _studentPhotoBucket = 'student-photos';

  String? _studentPhotoPath(String stored) {
    if (!stored.startsWith('http')) return stored;
    const marker = '/$_studentPhotoBucket/';
    final index = stored.indexOf(marker);
    if (index == -1) return null;
    return Uri.decodeComponent(stored.substring(index + marker.length).split('?').first);
  }

  Future<String?> _signedStudentPhotoUrl(String stored) async {
    final path = _studentPhotoPath(stored);
    if (path == null) return null;
    try {
      return await _client.storage.from(_studentPhotoBucket).createSignedUrl(path, 6 * 60 * 60);
    } catch (_) {
      // A photo that can no longer be signed (moved/deleted) just shows
      // the placeholder icon instead of a broken image.
      return null;
    }
  }

  Future<List<EnrolledChild>> _withSignedPhotoUrls(List<EnrolledChild> children) {
    return Future.wait(children.map((child) async {
      final stored = child.photoUrl;
      if (stored == null || stored.isEmpty) return child;
      return child.withPhotoUrl(await _signedStudentPhotoUrl(stored));
    }));
  }

  // --------------------------------------------------
  // ENROLLMENT - dynamic classes + subject offerings, never hardcoded
  // --------------------------------------------------

  Future<List<ClassOption>> getAvailableClasses(String schoolId) async {
    final rows = await _client
        .from('classes')
        .select('id, class_name, department_id')
        .eq('school_id', schoolId)
        // NOTE: `classes` has BOTH an `active` and an `is_active` column in
        // the schema - going with `is_active` since it matches the naming
        // used everywhere else (users, school_assets). Flag me if a class
        // you've deliberately disabled still shows up here, or if the
        // Principal side actually toggles the OTHER column - then this
        // needs to switch to `active` instead.
        .eq('is_active', true)
        .order('level_order');
    return rows.map((r) => ClassOption.fromMap(r)).toList();
  }

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
    String? guardianRelationship,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? address,
    Uint8List? photoBytes,
    String? photoExtension,
    required List<String> selectedSubjectIds,
  }) async {
    String? photoUrl;
    if (photoBytes != null && photoExtension != null) {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw StateError('No signed-in user - cannot upload a child photo.');
      }
      // The student-photos bucket is private. Its SELECT policy only lets
      // the uploader read a file back when the 2nd folder segment equals
      // their OWN auth.uid() - using parentId (the parents table row,
      // not the auth user) here silently broke read-back for the parent
      // who just uploaded the photo. Store the bare path, not a public
      // URL the private bucket will never actually serve; callers sign
      // it on read via _signedStudentPhotoUrl.
      final path = '$schoolId/$userId/${DateTime.now().millisecondsSinceEpoch}.$photoExtension';
      const contentTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
      final contentType = contentTypes[photoExtension.toLowerCase()];
      if (contentType == null) {
        throw const FormatException('Unsupported image type.');
      }
      await _client.storage.from('student-photos').uploadBinary(
            path,
            photoBytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      photoUrl = path;
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
          'guardian_relationship': guardianRelationship,
          'emergency_contact_name': emergencyContactName,
          'emergency_contact_phone': emergencyContactPhone,
          'address': address,
          'photo_url': photoUrl,
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
  // SIGN-UP DRAFT - the optional child name/photo captured on the
  // registration screen, reconciled into the real enrollment flow so
  // it isn't silently thrown away.
  // --------------------------------------------------

  Future<Map<String, dynamic>?> getChildDraft(String parentId) async {
    return _client
        .from('parent_child_drafts')
        .select()
        .eq('parent_id', parentId)
        // A draft that has already produced a real student is done -
        // don't offer to "continue" it again.
        .filter('converted_to_student_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<void> deleteChildDraft(String draftId) async {
    await _client.from('parent_child_drafts').delete().eq('id', draftId);
  }

  // --------------------------------------------------
  // LINK AN ALREADY-ADMITTED CHILD BY ADMISSION NUMBER
  // For when staff admitted (and possibly already paid for) a child on
  // the parent's behalf - lets the parent's own account pick that
  // child up. Both RPCs are SECURITY DEFINER since a parent has no RLS
  // access to a student they aren't yet linked to.
  // --------------------------------------------------

  /// Returns minimal info (name, class, photo path) if the admission
  /// number AND date of birth both match a child at this school, or
  /// null if not - deliberately not distinguishing which one was wrong.
  Future<Map<String, dynamic>?> lookupChildByAdmissionNumber({
    required String schoolId,
    required String admissionNumber,
    required DateTime dateOfBirth,
  }) async {
    final result = await _client.rpc('lookup_child_by_admission_number', params: {
      'p_school_id': schoolId,
      'p_admission_number': admissionNumber.trim(),
      'p_date_of_birth': dateOfBirth.toIso8601String().split('T').first,
    });
    if (result == null) return null;
    final map = Map<String, dynamic>.from(result as Map);
    final photoPath = map['photo_path'] as String?;
    if (photoPath != null && photoPath.isNotEmpty) {
      map['photo_path'] = await _signedStudentPhotoUrl(photoPath);
    }
    return map;
  }

  Future<void> linkChildToParent(String studentId) async {
    await _client.rpc('link_child_to_parent', params: {'p_student_id': studentId});
  }

  // --------------------------------------------------
  // ACADEMIC TERMS
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
  // REPORT CARD
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
        .eq('is_published', true)
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
  // --------------------------------------------------

  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException {
      throw const WrongPasswordException();
    }

    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // --------------------------------------------------
  // APPROVED TEACHER COMMENTS ONLY
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
  // FEES
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
        .select('*, students(first_name, last_name), admission_requests!payments_admission_request_id_fkey(first_name, last_name)')
        .eq('parent_id', parentId)
        .order('created_at', ascending: false);
    return rows.map((r) => PaymentTransaction.fromMap(r)).toList();
  }
  // --------------------------------------------------
  // CURRENT ACADEMIC YEAR
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
    String? installmentId,
    required double amount,
    required String paymentPurpose,
    required String phoneNumber,
  }) async {
    final response = await _client.functions.invoke('initiate-parent-payment', body: {
      'school_id': schoolId,
      if (childId != null) 'child_id': childId,
      if (admissionRequestId != null) 'admission_request_id': admissionRequestId,
      if (installmentId != null) 'installment_id': installmentId,
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

    // --------------------------------------------------
  // OFFICIAL DOCUMENT BRANDING - letterhead + stamps, same
  // school_assets table/pattern already used for the logo on the
  // landing page. Missing assets simply produce an empty map entry -
  // never blocks document generation.
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
}


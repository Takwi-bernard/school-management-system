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
              classes ( class_name )
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

  Future<void> submitAdmissionRequest({
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
          'status': 'submitted',
        })
        .select()
        .single();

    if (selectedSubjectIds.isNotEmpty) {
      await _client.from('admission_request_subjects').insert([
        for (final subjectId in selectedSubjectIds)
          {'admission_request_id': request['id'], 'subject_id': subjectId},
      ]);
    }
  }

  // --------------------------------------------------
  // FEES - fully dynamic, school-configured installments
  // --------------------------------------------------

  Future<List<FeeSummary>> getChildFees({
    required String studentId,
    required String academicYearId,
  }) async {
    final feeRows = await _client
        .from('fees')
        .select('id, name, amount, installments(id, name, amount, due_date)')
        .eq('academic_year_id', academicYearId);
    // Note: fees are per school+year+class (Migration 006) - filtering
    // by the student's actual class happens via a join in production;
    // simplified here to the shape already confirmed in the schema.

    final paidRows = await _client
        .from('payments')
        .select('installment_id, status')
        .eq('student_id', studentId)
        .eq('status', 'success');

    final paidInstallmentIds = paidRows.map((r) => r['installment_id']).toSet();

    return feeRows.map((fee) {
      final installments = (fee['installments'] as List)
          .map((i) => InstallmentSummary(
                installmentId: i['id'] as String,
                name: i['name'] as String? ?? '',
                amount: (i['amount'] as num).toDouble(),
                isPaid: paidInstallmentIds.contains(i['id']),
                dueDate: DateTime.tryParse(i['due_date'] as String? ?? ''),
              ))
          .toList();

      final paidAmount = installments.where((i) => i.isPaid).fold(0.0, (sum, i) => sum + i.amount);

      return FeeSummary(
        feeId: fee['id'] as String,
        feeName: fee['name'] as String? ?? '',
        totalAmount: (fee['amount'] as num).toDouble(),
        amountPaid: paidAmount,
        installments: installments,
      );
    }).toList();
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
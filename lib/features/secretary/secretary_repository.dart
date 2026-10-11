import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secretary_models.dart';

class SecretaryRepository {
  SecretaryRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> _call(String action, Map<String, dynamic> payload) async {
    try {
      final res = await _client.functions.invoke('secretary-actions', body: {'action': action, ...payload});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['success'] != true) throw Exception(data['message'] ?? 'Request failed.');
      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map ? details['message'] : null) ?? 'Request failed (status ${e.status}).';
      throw Exception(message);
    }
  }

  // ---------------- profile ----------------

  Future<SecretaryProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client.from('secretaries').select('id, user_id, school_id, full_name, phone, photo_url').eq('user_id', userId).maybeSingle();
      if (row == null) return null;
      final email = _client.auth.currentUser?.email;
      return SecretaryProfile(
        secretaryId: row['id'] as String,
        userId: row['user_id'] as String,
        schoolId: row['school_id'] as String,
        fullName: row['full_name'] as String? ?? '',
        phone: row['phone'] as String?,
        email: email,
        photoUrl: row['photo_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Direct, self-service update of the secretary's own row - same
  /// pattern the Teacher module already uses (RLS allows a user to
  /// update their own staff row), rather than routing this benign,
  /// self-scoped change through the Edge Function.
  Future<void> updateProfile({required String secretaryId, required String fullName, String? phone}) async {
    await _client.from('secretaries').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', secretaryId);
  }

  Future<String> uploadProfilePhoto({required String schoolId, required String userId, required Uint8List bytes, required String extension}) async {
    final path = '$schoolId/$userId/avatar.$extension';
    await _client.storage.from('staff-photos').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    final url = _client.storage.from('staff-photos').getPublicUrl(path);
    final cacheBusted = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('secretaries').update({'photo_url': cacheBusted}).eq('user_id', userId);
    return cacheBusted;
  }

  // ---------------- reference data ----------------

  Future<List<EnrollClass>> getClasses(String schoolId) async {
    final rows = await _client
        .from('classes')
        .select('id, class_name, department_id, departments(department_name)')
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('level_order');
    return rows.map((r) => EnrollClass.fromMap(r)).toList();
  }

  Future<List<EnrollSubject>> getSubjectOfferings(String classId, String departmentId) async {
    final byClass = await _client
        .from('subject_offerings')
        .select('subject_id, is_compulsory, subjects(subject_name)')
        .eq('class_id', classId);
    if (byClass.isNotEmpty) return byClass.map((r) => EnrollSubject.fromMap(r)).toList();

    final byDept = await _client
        .from('subject_offerings')
        .select('subject_id, is_compulsory, subjects(subject_name)')
        .eq('department_id', departmentId);
    return byDept.map((r) => EnrollSubject.fromMap(r)).toList();
  }

  Future<String> uploadChildPhoto({required String schoolId, required Uint8List bytes, required String extension}) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$schoolId/$uid/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('student-photos').uploadBinary(path, bytes);
    return _client.storage.from('student-photos').getPublicUrl(path);
  }

  // ---------------- parents / enrollment ----------------

  Future<List<ParentMatch>> findParents(String query) async {
    final data = await _call('find_parent', {'query': query});
    return ((data['parents'] as List?) ?? []).map((p) => ParentMatch.fromMap(Map<String, dynamic>.from(p as Map))).toList();
  }

  Future<NewParentCredentials> createParent({required String fullName, required String email, required String phone}) async {
    final data = await _call('create_parent', {'full_name': fullName, 'email': email, 'phone': phone});
    return NewParentCredentials.fromMap(data);
  }

  Future<EnrollmentResult> enrollChild({
    required String parentId,
    required String classId,
    required String firstName,
    required String lastName,
    required String gender,
    DateTime? dateOfBirth,
    String? guardianName,
    String? emergencyName,
    String? emergencyPhone,
    String? address,
    String? photoUrl,
    required List<String> subjectIds,
  }) async {
    final data = await _call('enroll_child', {
      'parent_id': parentId,
      'requested_class_id': classId,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'guardian_name': guardianName,
      'emergency_contact_name': emergencyName,
      'emergency_contact_phone': emergencyPhone,
      'address': address,
      'photo_url': photoUrl,
      'subject_ids': subjectIds,
    });
    return EnrollmentResult(
      admissionRequestId: data['admission_request_id'] as String,
      registrationFee: (data['registration_fee'] as num?)?.toDouble(),
    );
  }

  Future<double?> updateEnrollment({
    required String admissionRequestId,
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? dateOfBirth,
    String? classId,
    String? guardianName,
    String? emergencyName,
    String? emergencyPhone,
    String? address,
    String? photoUrl,
    List<String>? subjectIds,
  }) async {
    final data = await _call('update_enrollment', {
      'admission_request_id': admissionRequestId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (gender != null) 'gender': gender,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      if (classId != null) 'requested_class_id': classId,
      if (guardianName != null) 'guardian_name': guardianName,
      if (emergencyName != null) 'emergency_contact_name': emergencyName,
      if (emergencyPhone != null) 'emergency_contact_phone': emergencyPhone,
      if (address != null) 'address': address,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (subjectIds != null) 'subject_ids': subjectIds,
    });
    return (data['registration_fee'] as num?)?.toDouble();
  }

  Future<List<AwaitingRegistration>> listAwaitingRegistrations() async {
    final data = await _call('list_awaiting_registration', {});
    return ((data['requests'] as List?) ?? []).map((r) => AwaitingRegistration.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<StudentFeeLookup>> lookupStudents(String query) async {
    final data = await _call('lookup_student', {'query': query});
    return ((data['students'] as List?) ?? []).map((s) => StudentFeeLookup.fromMap(Map<String, dynamic>.from(s as Map))).toList();
  }

  Future<List<DirectoryStudent>> listStudents(String query) async {
    final data = await _call('list_students', {'query': query});
    return ((data['students'] as List?) ?? []).map((s) => DirectoryStudent.fromMap(Map<String, dynamic>.from(s as Map))).toList();
  }

  Future<SecretaryDashboard> getDashboard() async {
    final data = await _call('get_dashboard', {});
    return SecretaryDashboard.fromMap(Map<String, dynamic>.from(data['dashboard'] as Map));
  }

  Future<List<MyPayment>> listMyPayments() async {
    final data = await _call('list_my_payments', {});
    return ((data['payments'] as List?) ?? []).map((p) => MyPayment.fromMap(Map<String, dynamic>.from(p as Map))).toList();
  }

  Future<void> requestPaymentCorrection({required String paymentId, required String reason}) async {
    await _call('request_payment_correction', {'payment_id': paymentId, 'reason': reason});
  }

  Future<RecordedPayment> recordOfflinePayment({
    required String kind,
    String? admissionRequestId,
    String? studentId,
    String? installmentId,
    required String method,
  }) async {
    final data = await _call('record_offline_payment', {
      'kind': kind,
      'admission_request_id': admissionRequestId,
      'student_id': studentId,
      'installment_id': installmentId,
      'payment_method': method,
    });
    return RecordedPayment.fromMap(Map<String, dynamic>.from(data['payment'] as Map));
  }

  Future<OnlinePaymentTicket> initiateOnlinePayment({
    required String kind,
    String? admissionRequestId,
    String? studentId,
    String? installmentId,
    required String phone,
  }) async {
    final data = await _call('initiate_online_payment', {
      'kind': kind,
      'admission_request_id': admissionRequestId,
      'student_id': studentId,
      'installment_id': installmentId,
      'phone_number': phone,
    });
    return OnlinePaymentTicket.fromMap(Map<String, dynamic>.from(data['transaction'] as Map));
  }

  Future<OnlinePaymentTicket> verifyOnlinePayment(String paymentId) async {
    final data = await _call('verify_online_payment', {'payment_id': paymentId});
    return OnlinePaymentTicket.fromMap(Map<String, dynamic>.from(data['transaction'] as Map));
  }
}
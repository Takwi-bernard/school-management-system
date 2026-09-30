import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secretary_models.dart';

class SecretaryRepository {
  SecretaryRepository(this._client);
  final SupabaseClient _client;

  /// One place that turns every Edge Function failure into a readable
  /// message - never a raw "FunctionException(status: ...)" dump.
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

  // ---------------- profile + reference data (plain reads) ----------------

  Future<SecretaryProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client.from('secretaries').select('full_name').eq('user_id', userId).maybeSingle();
      if (row == null) return null;
      return SecretaryProfile(fullName: row['full_name'] as String? ?? '');
    } catch (_) {
      return null; // greeting simply falls back to blank - never blocks the dashboard
    }
  }

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

  // ---------------- privileged actions (Edge Function) ----------------

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

  Future<List<AwaitingRegistration>> listAwaitingRegistrations() async {
    final data = await _call('list_awaiting_registration', {});
    return ((data['requests'] as List?) ?? []).map((r) => AwaitingRegistration.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<StudentFeeLookup>> lookupStudents(String query) async {
    final data = await _call('lookup_student', {'query': query});
    return ((data['students'] as List?) ?? []).map((s) => StudentFeeLookup.fromMap(Map<String, dynamic>.from(s as Map))).toList();
  }

  Future<RecordedPayment> recordOfflinePayment({
    required String kind,
    String? admissionRequestId,
    String? studentId,
    String? installmentId,
    required String method, // 'cash' | 'bank_transfer'
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
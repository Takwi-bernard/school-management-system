import 'package:supabase_flutter/supabase_flutter.dart';
import 'super_admin_models.dart';

class SuperAdminRepository {
  SuperAdminRepository(this._client);
  final SupabaseClient _client;

  Future<SuperAdminProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client.from('super_admins').select('id, full_name').eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    return SuperAdminProfile(id: row['id'] as String, fullName: row['full_name'] as String? ?? '');
  }

  Future<Map<String, dynamic>> _call(String action, Map<String, dynamic> payload) async {
    try {
      final res = await _client.functions.invoke('super-admin-actions', body: {'action': action, ...payload});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['success'] != true) throw Exception(data['message'] ?? 'Request failed.');
      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map ? details['message'] : null) ?? 'Request failed (status ${e.status}).';
      throw Exception(message);
    }
  }

  Future<List<SchoolSummary>> listSchools() async {
    final data = await _call('list_schools', {});
    return ((data['schools'] as List?) ?? []).map((s) => SchoolSummary.fromMap(Map<String, dynamic>.from(s as Map))).toList();
  }

  Future<SchoolSummary> createSchool({
    required String schoolName,
    required String schoolCode,
    required String domain,
    String? motto,
    String? website,
    required List<String> phoneNumbers,
    required String primaryColor,
    required String secondaryColor,
  }) async {
    final data = await _call('create_school', {
      'school_name': schoolName,
      'school_code': schoolCode,
      'domain': domain,
      'motto': motto,
      'website': website,
      'phone_numbers': phoneNumbers,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
    });
    return SchoolSummary.fromMap(Map<String, dynamic>.from(data['school'] as Map));
  }

  Future<SchoolSummary> updateSchool({
    required String schoolId,
    String? schoolName,
    String? schoolCode,
    String? domain,
    String? motto,
    String? website,
    List<String>? phoneNumbers,
    String? primaryColor,
    String? secondaryColor,
  }) async {
    final data = await _call('update_school', {
      'school_id': schoolId,
      if (schoolName != null) 'school_name': schoolName,
      if (schoolCode != null) 'school_code': schoolCode,
      if (domain != null) 'domain': domain,
      if (motto != null) 'motto': motto,
      if (website != null) 'website': website,
      if (phoneNumbers != null) 'phone_numbers': phoneNumbers,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
    });
    return SchoolSummary.fromMap(Map<String, dynamic>.from(data['school'] as Map));
  }

  Future<String> toggleSchoolStatus(String schoolId) async {
    final data = await _call('toggle_school_status', {'school_id': schoolId});
    return data['new_status'] as String;
  }

  Future<NewAdminCredentials> createSchoolAdmin({
    required String schoolId,
    required String role,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    final data = await _call('create_school_admin', {
      'school_id': schoolId,
      'role': role,
      'full_name': fullName,
      'email': email,
      'phone': phone,
    });
    return NewAdminCredentials.fromMap(Map<String, dynamic>.from(data['account'] as Map));
  }

  Future<List<SchoolAdminAccount>> listSchoolAdmins(String schoolId) async {
    final data = await _call('list_school_admins', {'school_id': schoolId});
    return ((data['admins'] as List?) ?? []).map((a) => SchoolAdminAccount.fromMap(Map<String, dynamic>.from(a as Map))).toList();
  }
}
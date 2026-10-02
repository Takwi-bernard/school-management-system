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

  /// Every privileged action goes through this one call - never a
  /// direct table read/write from this module.
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> payload) async {
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
}
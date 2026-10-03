import 'dart:typed_data';
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

  // ---------------- SCHOOLS ----------------

  Future<List<SchoolSummary>> listSchools() async {
    final data = await _call('list_schools', {});
    return ((data['schools'] as List?) ?? []).map((s) => SchoolSummary.fromMap(Map<String, dynamic>.from(s as Map))).toList();
  }

  Future<SchoolSummary> createSchool({
    required String schoolName,
    required String schoolCode,
    required String domain,
    String? languageMode,
    String? motto,
    String? website,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
    required String primaryColor,
    required String secondaryColor,
  }) async {
    final data = await _call('create_school', {
      'school_name': schoolName, 'school_code': schoolCode, 'domain': domain,
      'language_mode': languageMode, 'motto': motto, 'website': website,
      'email': email, 'phone': phone, 'address': address, 'city': city, 'country': country,
      'primary_color': primaryColor, 'secondary_color': secondaryColor,
    });
    return SchoolSummary.fromMap(Map<String, dynamic>.from(data['school'] as Map));
  }

  Future<SchoolSummary> updateSchool({
    required String schoolId,
    String? schoolName,
    String? schoolCode,
    String? domain,
    String? languageMode,
    String? motto,
    String? website,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
    String? primaryColor,
    String? secondaryColor,
  }) async {
    final data = await _call('update_school', {
      'school_id': schoolId,
      if (schoolName != null) 'school_name': schoolName,
      if (schoolCode != null) 'school_code': schoolCode,
      if (domain != null) 'domain': domain,
      if (languageMode != null) 'language_mode': languageMode,
      if (motto != null) 'motto': motto,
      if (website != null) 'website': website,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
    });
    return SchoolSummary.fromMap(Map<String, dynamic>.from(data['school'] as Map));
  }

  Future<String> toggleSchoolStatus(String schoolId) async {
    final data = await _call('toggle_school_status', {'school_id': schoolId});
    return data['new_status'] as String;
  }

  // ---------------- ADMIN ACCOUNTS ----------------

  Future<NewAdminCredentials> createSchoolAdmin({required String schoolId, required String role, required String fullName, required String email, String? phone}) async {
    final data = await _call('create_school_admin', {'school_id': schoolId, 'role': role, 'full_name': fullName, 'email': email, 'phone': phone});
    return NewAdminCredentials.fromMap(Map<String, dynamic>.from(data['account'] as Map));
  }

  Future<List<SchoolAdminAccount>> listSchoolAdmins(String schoolId) async {
    final data = await _call('list_school_admins', {'school_id': schoolId});
    return ((data['admins'] as List?) ?? []).map((a) => SchoolAdminAccount.fromMap(Map<String, dynamic>.from(a as Map))).toList();
  }

  // ---------------- BRANDING: CONTENT ----------------

  Future<List<SchoolContentItem>> listContent(String schoolId) async {
    final data = await _call('list_school_content', {'school_id': schoolId});
    return ((data['content'] as List?) ?? []).map((c) => SchoolContentItem.fromMap(Map<String, dynamic>.from(c as Map))).toList();
  }

  Future<void> saveContent({String? id, required String schoolId, required String contentType, required String language, String? title, String? content}) async {
    await _call('upsert_school_content', {'id': id, 'school_id': schoolId, 'content_type': contentType, 'language': language, 'title': title, 'content': content});
  }

  Future<void> deleteContent(String id) async => _call('delete_school_content', {'id': id});

  // ---------------- BRANDING: GALLERY ----------------

  Future<List<GalleryItem>> listGallery(String schoolId) async {
    final data = await _call('list_gallery', {'school_id': schoolId});
    return ((data['gallery'] as List?) ?? []).map((g) => GalleryItem.fromMap(Map<String, dynamic>.from(g as Map))).toList();
  }

  Future<void> addGalleryItem({required String schoolId, required String imageUrl, String? caption, int displayOrder = 0}) async {
    await _call('add_gallery_item', {'school_id': schoolId, 'image_url': imageUrl, 'caption': caption, 'display_order': displayOrder});
  }

  Future<void> updateGalleryItem({required String id, String? caption, bool? isFeatured}) async {
    await _call('update_gallery_item', {'id': id, 'caption': caption, 'is_featured': isFeatured});
  }

  Future<void> deleteGalleryItem(String id) async => _call('delete_gallery_item', {'id': id});

  // ---------------- BRANDING: ACHIEVEMENTS ----------------

  Future<List<AchievementItem>> listAchievements(String schoolId) async {
    final data = await _call('list_achievements', {'school_id': schoolId});
    return ((data['achievements'] as List?) ?? []).map((a) => AchievementItem.fromMap(Map<String, dynamic>.from(a as Map))).toList();
  }

  Future<void> saveAchievement({
    String? id, required String schoolId, String? titleEn, String? titleFr, String? descriptionEn, String? descriptionFr,
    String? imageUrl, DateTime? achievedOn, int displayOrder = 0,
  }) async {
    await _call('upsert_achievement', {
      'id': id, 'school_id': schoolId, 'title_en': titleEn, 'title_fr': titleFr,
      'description_en': descriptionEn, 'description_fr': descriptionFr, 'image_url': imageUrl,
      'achieved_on': achievedOn?.toIso8601String().split('T').first, 'display_order': displayOrder,
    });
  }

  Future<void> deleteAchievement(String id) async => _call('delete_achievement', {'id': id});

  // ---------------- BRANDING: EVENTS ----------------

  Future<List<EventItem>> listEvents(String schoolId) async {
    final data = await _call('list_events', {'school_id': schoolId});
    return ((data['events'] as List?) ?? []).map((e) => EventItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> saveEvent({
    String? id, required String schoolId, String? title, String? description,
    DateTime? eventDate, String? eventTime, String? location, String? status,
  }) async {
    await _call('upsert_event', {
      'id': id, 'school_id': schoolId, 'title': title, 'description': description,
      'event_date': eventDate?.toIso8601String().split('T').first, 'event_time': eventTime, 'location': location, 'status': status,
    });
  }

  Future<void> deleteEvent(String id) async => _call('delete_event', {'id': id});

  // ---------------- BRANDING: ASSETS ----------------

  Future<List<SchoolAssetItem>> listAssets(String schoolId) async {
    final data = await _call('list_assets', {'school_id': schoolId});
    return ((data['assets'] as List?) ?? []).map((a) => SchoolAssetItem.fromMap(Map<String, dynamic>.from(a as Map))).toList();
  }

  /// Uploads directly to the public school-branding bucket (the client
  /// owns the file bytes), then records it via the Edge Function.
  Future<String> uploadBrandingFile({required Uint8List bytes, required String extension, required String folder}) async {
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('school-branding').uploadBinary(path, bytes);
    return _client.storage.from('school-branding').getPublicUrl(path);
  }

  Future<void> saveAsset({required String schoolId, required String assetType, required String fileUrl, String? fileName, String? mimeType, int? fileSize}) async {
    await _call('save_asset', {'school_id': schoolId, 'asset_type': assetType, 'file_url': fileUrl, 'file_name': fileName, 'mime_type': mimeType, 'file_size': fileSize});
  }

  Future<void> deleteAsset(String id) async => _call('delete_asset', {'id': id});
}
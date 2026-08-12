import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A signed-in user's actual identity in OUR system - not just the
/// Supabase auth.users record, but their role and which school they
/// belong to (read from public.users, which is what determines what
/// they can actually see once RLS kicks in).
class UserProfile {
  final String userId;
  final String role;
  final String? schoolId;

  const UserProfile({required this.userId, required this.role, this.schoolId});
}

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  // --------------------------------------------------
  // SIGN IN
  // --------------------------------------------------

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  // Redirects back to whichever school's domain initiated this - not a
  // hardcoded mobile deep link, since V1 is web-first and multi-tenant
  // (every school has a different domain to return to).
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Uri.base.origin,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  // --------------------------------------------------
  // PROFILE LOOKUP
  // --------------------------------------------------

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select('id, role, school_id')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return UserProfile(
      userId: row['id'] as String,
      role: row['role'] as String,
      schoolId: row['school_id'] as String?,
    );
  }

  // --------------------------------------------------
  // CHILD PHOTO UPLOAD
  // Storage layout: student-photos/{school_id}/{parent_user_id}/{ts}.ext
  // (matches the bucket convention already agreed for the platform).
  // --------------------------------------------------

  Future<String?> uploadChildPhoto({
    required String schoolId,
    required String parentUserId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path =
        'student-photos/$schoolId/$parentUserId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('student-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return _client.storage.from('student-photos').getPublicUrl(path);
  }

  // --------------------------------------------------
  // PARENT REGISTRATION
  // school_id is the CURRENT TENANT (resolved by TenantResolver before
  // this is ever called) - not a guess, not client-decided by role.
  // --------------------------------------------------

  Future<void> registerParent({
    required String schoolId,
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String preferredLanguage,
    String? childName,
    Uint8List? childPhotoBytes,
    String? childPhotoExtension,
    String? requestedClassName,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create the parent account.');
    }

    // Photo upload happens here, AFTER signUp, since it needs the new
    // user's id as part of the storage path - not passed in from outside.
    String? childPhotoUrl;
    if (childPhotoBytes != null && childPhotoExtension != null) {
      childPhotoUrl = await uploadChildPhoto(
        schoolId: schoolId,
        parentUserId: user.id,
        bytes: childPhotoBytes,
        extension: childPhotoExtension,
      );
    }

    await _client.rpc('register_parent', params: {
      'p_user_id': user.id,
      'p_school_id': schoolId,
      'p_full_name': fullName,
      'p_phone': phone,
      'p_email': email,
      'p_preferred_language': preferredLanguage,
      'p_child_name': childName,
      'p_child_photo_url': childPhotoUrl,
      'p_requested_class_name': requestedClassName,
    });
  }

  // --------------------------------------------------
  // TEACHER REGISTRATION
  // --------------------------------------------------

  Future<void> registerTeacher({
    required String schoolId,
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String preferredLanguage,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create the teacher account.');
    }

    await _client.rpc('register_teacher', params: {
      'p_user_id': user.id,
      'p_school_id': schoolId,
      'p_full_name': fullName,
      'p_phone': phone,
      'p_email': email,
      'p_preferred_language': preferredLanguage,
    });
  }
}
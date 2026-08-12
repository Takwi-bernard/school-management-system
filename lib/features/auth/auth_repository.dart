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
  // Path: {school_id}/{parent_user_id}/{ts}.ext - NOT prefixed with
  // "student-photos/" again, that's already the bucket name.
  // --------------------------------------------------

  Future<String?> uploadChildPhoto({
    required String schoolId,
    required String parentUserId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path =
        '$schoolId/$parentUserId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('student-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return _client.storage.from('student-photos').getPublicUrl(path);
  }

  // --------------------------------------------------
  // PARENT REGISTRATION
  // Profile (users + parents row) is created by a database trigger on
  // auth.users (Migration 016) reading this metadata - NOT by an RPC
  // call after signUp(), since there may be no active session yet if
  // the project requires email confirmation. This means core account
  // creation ALWAYS succeeds regardless of that setting.
  //
  // Child info is optional and handled separately: it needs a real
  // session (for photo upload), so if one doesn't exist yet
  // (confirmation pending), it's simply skipped - never blocks
  // account creation, matching the agreed "ask again at admission
  // time" behavior.
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
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'account_type': 'parent',
        'school_id': schoolId,
        'full_name': fullName,
        'phone': phone,
        'preferred_language': preferredLanguage,
      },
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create the parent account.');
    }

    // No active session yet (email confirmation pending) - child info
    // capture is deferred to admission time, not an error.
    if (_client.auth.currentSession == null) return;
    if (childName == null || childName.isEmpty) return;

    String? photoUrl;
    if (childPhotoBytes != null && childPhotoExtension != null) {
      photoUrl = await uploadChildPhoto(
        schoolId: schoolId,
        parentUserId: user.id,
        bytes: childPhotoBytes,
        extension: childPhotoExtension,
      );
    }

    await _client.rpc('save_child_draft', params: {
      'p_school_id': schoolId,
      'p_child_name': childName,
      'p_photo_url': photoUrl,
      'p_requested_class_name': requestedClassName,
    });
  }

  // --------------------------------------------------
  // TEACHER REGISTRATION
  // Same trigger-based pattern - nothing further needed after signUp().
  // --------------------------------------------------

  Future<void> registerTeacher({
    required String schoolId,
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String preferredLanguage,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'account_type': 'teacher',
        'school_id': schoolId,
        'full_name': fullName,
        'phone': phone,
        'preferred_language': preferredLanguage,
      },
    );

    if (response.user == null) {
      throw const AuthException('Unable to create the teacher account.');
    }
  }
}
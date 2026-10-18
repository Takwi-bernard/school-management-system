import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/web_prefs.dart';

/// Remembered across Google's full-page redirect: which kind of account
/// the person was creating ('parent' / 'teacher'). Absent = plain sign-in.
const kSignUpIntentKey = 'pending_signup_role';

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

  /// Google sends the person straight back to the auth module's own
  /// callback page (not the landing page), which finishes the sign-in
  /// and opens the right dashboard. The callback URL must be in
  /// Supabase's redirect allow-list (Authentication > URL
  /// Configuration), e.g. https://your-domain/**
  ///
  /// [signUpRole] is 'parent' or 'teacher' when the person is on a
  /// sign-up page; it is remembered so that, if Google gives us a brand
  /// new user, the right kind of account is created. From the Sign In
  /// page it is null, so an unknown Google account is NOT turned into
  /// anything - the person is told to create an account first.
  Future<void> signInWithGoogle({String? signUpRole}) {
    if (signUpRole == 'parent' || signUpRole == 'teacher') {
      webPrefSet(kSignUpIntentKey, signUpRole!);
    } else {
      webPrefRemove(kSignUpIntentKey);
    }
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: '${Uri.base.origin}/auth/callback',
    );
  }

  // --------------------------------------------------
  // PHONE (SMS code)
  // --------------------------------------------------

  /// Sends a one-time code by SMS. For sign-up [createUser] is true and
  /// [metadata] carries the same fields the email sign-up sends, so the
  /// same database trigger builds the profile. For sign-in [createUser]
  /// is false so an unknown number is refused instead of silently
  /// creating an account.
  Future<void> sendPhoneCode({
    required String phone,
    required bool createUser,
    Map<String, dynamic>? metadata,
  }) {
    return _client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: createUser,
      data: createUser ? metadata : null,
    );
  }

  Future<AuthResponse> verifyPhoneCode({required String phone, required String code}) {
    return _client.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  /// After an OAuth redirect the session is established a moment after
  /// the page loads. Waits for it, up to [timeout].
  Future<bool> waitForSession({Duration timeout = const Duration(seconds: 8)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (_client.auth.currentSession != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _client.auth.currentSession != null;
  }

  /// First-time Google sign-up: the database trigger cannot know which
  /// school or role the person chose, so the app asks the database to
  /// create the profile (parent or teacher) for the signed-in user.
  /// No-op if a profile already exists.
  Future<void> claimProfile({required String schoolId, required String role, required String language}) async {
    await _client.rpc('complete_oauth_signup', params: {'p_school_id': schoolId, 'p_role': role, 'p_language': language});
  }

  // --------------------------------------------------
  // PASSWORD RECOVERY
  // --------------------------------------------------

  /// Emails a reset link (and a one-time code, if the email template
  /// includes it). Supabase never reveals whether the address exists.
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: '${Uri.base.origin}/auth/reset');
  }

  /// Works from any browser or device, unlike the link.
  Future<AuthResponse> verifyRecoveryCode({required String email, required String code}) {
    return _client.auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();

  // --------------------------------------------------
  // PROFILE LOOKUP
  // --------------------------------------------------

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select('id, role, school_id, is_active')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    // A deactivated account is treated as "no profile" so it cannot get
    // past the sign-in gate (the caller signs the user out).
    if (row['is_active'] == false) return null;
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
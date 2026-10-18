import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_providers.dart';
import '../landing/landing_providers.dart' show activeLocaleProvider;
import 'auth_error.dart';
import '../../core/web_prefs.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserProfile? profile;

  const AuthState({this.isLoading = false, this.errorMessage, this.profile});

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserProfile? profile,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      profile: profile ?? this.profile,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._ref) : super(const AuthState());
  final AuthRepository _repository;
  final Ref _ref;

  bool get _french => _ref.read(activeLocaleProvider).languageCode == 'fr';
  String _msg(Object e) => friendlyError(e, french: _french);

  /// [expectedSchoolId] is the school whose site the person is signing
  /// in on (from the already-resolved landing/tenant data). If the
  /// account belongs to a DIFFERENT school, this refuses and signs
  /// them back out immediately - this is the actual security check
  /// that was missing from every earlier draft of this module.
  Future<void> signIn({
    required String email,
    required String password,
    required String expectedSchoolId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.signIn(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('Authentication failed.');

      await _resolveAndValidateProfile(user.id, expectedSchoolId);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
    }
  }

  Future<void> signInWithGoogle({String? signUpRole}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signInWithGoogle(signUpRole: signUpRole);
      // Control returns to the app via the OAuth redirect; the actual
      // profile resolution for Google sign-in happens in AuthGate,
      // which watches auth state changes (see auth_gate.dart) using
      // the SAME expectedSchoolId check as email/password sign-in.
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
    }
  }

  /// Finishes a Google sign-in once the OAuth redirect has landed on
  /// the auth callback page. Returns the profile on success, null (with
  /// the error set) otherwise.
  Future<UserProfile?> completeOAuth(String expectedSchoolId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hasSession = await _repository.waitForSession();
      final userId = _repository.currentUserId;
      if (!hasSession || userId == null) {
        throw const AuthException('Authentication failed.');
      }
      // A brand-new Google user has no profile yet. Only if they came
      // from a sign-up page (parent / teacher) is one created; from the
      // Sign In page they are told to create an account first.
      final intent = webPrefGet(kSignUpIntentKey);
      webPrefRemove(kSignUpIntentKey);
      if (await _repository.fetchProfile(userId) == null && (intent == 'parent' || intent == 'teacher')) {
        try {
          await _repository.claimProfile(schoolId: expectedSchoolId, role: intent!, language: _french ? 'fr' : 'en');
        } catch (_) {
          // Falls through: the check below reports the problem.
        }
      }
      await _resolveAndValidateProfile(userId, expectedSchoolId, retries: (intent == null) ? 1 : 4);
      return state.profile;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
      return null;
    }
  }

  // --------------------------------------------------
  // PHONE
  // --------------------------------------------------

  /// Returns true when the code was sent.
  Future<bool> sendPhoneCode({
    required String phone,
    required bool createUser,
    Map<String, dynamic>? metadata,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendPhoneCode(phone: phone, createUser: createUser, metadata: metadata);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
      return false;
    }
  }

  Future<UserProfile?> verifyPhoneCode({
    required String phone,
    required String code,
    required String expectedSchoolId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.verifyPhoneCode(phone: phone, code: code);
      final user = response.user;
      if (user == null) throw const AuthException('Authentication failed.');
      // A brand-new account's profile is created by a database trigger a
      // moment before this; allow it a short while to appear.
      await _resolveAndValidateProfile(user.id, expectedSchoolId, retries: 4);
      return state.profile;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
      return null;
    }
  }

  Future<void> _resolveAndValidateProfile(String userId, String expectedSchoolId, {int retries = 0}) async {
    var profile = await _repository.fetchProfile(userId);
    for (var i = 0; profile == null && i < retries; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      profile = await _repository.fetchProfile(userId);
    }

    if (profile == null) {
      await _repository.signOut();
      throw const AuthException('Your account profile could not be found.');
    }

    // Super Admin doesn't sign in through a school's public site at all.
    if (profile.role == 'super_admin') {
      await _repository.signOut();
      throw const AuthException(
          'Super Admin accounts sign in through the company portal, not a school site.');
    }

    if (profile.schoolId != expectedSchoolId) {
      await _repository.signOut();
      throw const AuthException('WRONG_SCHOOL');
    }

    state = state.copyWith(isLoading: false, profile: profile);
  }

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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.registerParent(
        schoolId: schoolId,
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        preferredLanguage: preferredLanguage,
        childName: childName,
        childPhotoBytes: childPhotoBytes,
        childPhotoExtension: childPhotoExtension,
        requestedClassName: requestedClassName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
    }
  }

  Future<void> registerTeacher({
    required String schoolId,
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String preferredLanguage,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.registerTeacher(
        schoolId: schoolId,
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        preferredLanguage: preferredLanguage,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
    }
  }

  // --------------------------------------------------
  // PASSWORD RECOVERY
  // --------------------------------------------------

  Future<bool> _guard(Future<void> Function() run) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await run();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _msg(e));
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) => _guard(() => _repository.sendPasswordReset(email));

  Future<bool> verifyRecoveryCode({required String email, required String code}) =>
      _guard(() => _repository.verifyRecoveryCode(email: email, code: code));

  /// Sets the new password, then signs out so the person signs in fresh.
  Future<bool> updatePassword(String newPassword) => _guard(() async {
        await _repository.updatePassword(newPassword);
        await _repository.signOut();
      });

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }

  /// Called whenever a page is entered, so a leftover error from a
  /// DIFFERENT page (e.g. sign-up) never bleeds into this one - error
  /// state was previously global/shared across every auth screen.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}
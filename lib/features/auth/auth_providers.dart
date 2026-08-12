import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_providers.dart';
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
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());
  final AuthRepository _repository;

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
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signInWithGoogle();
      // Control returns to the app via the OAuth redirect; the actual
      // profile resolution for Google sign-in happens in AuthGate,
      // which watches auth state changes (see auth_gate.dart) using
      // the SAME expectedSchoolId check as email/password sign-in.
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _resolveAndValidateProfile(String userId, String expectedSchoolId) async {
    final profile = await _repository.fetchProfile(userId);

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
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }

  String _friendly(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'The email or password is incorrect.';
      case 'Email not confirmed':
        return 'Please verify your email before signing in.';
      case 'WRONG_SCHOOL':
        return 'This account belongs to a different school.';
      default:
        return e.message;
    }
  }
}
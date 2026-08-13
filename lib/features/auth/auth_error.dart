import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns ANY error into a message safe AND specific enough for a user
/// to actually understand what happened - never a raw exception dump,
/// but also never a vague "something went wrong" when we know exactly
/// what occurred (e.g. our own thrown messages are already
/// human-written and safe, so they pass through directly instead of
/// being flattened to a generic fallback).
String friendlyError(Object error) {
  if (error is AuthException) {
    switch (error.message) {
      case 'Invalid login credentials':
        return 'The email or password is incorrect.';
      case 'Email not confirmed':
        return 'Please verify your email before signing in.';
      case 'User already registered':
        return 'An account with this email already exists.';
      case 'WRONG_SCHOOL':
        return 'This account belongs to a different school. Please check the site you\'re signing in from.';
      case 'Your account profile could not be found.':
      case 'Super Admin accounts sign in through the company portal, not a school site.':
      case 'Authentication failed.':
        // These are OUR OWN messages, already written to be clear and
        // safe - pass through as-is rather than flattening to generic text.
        return error.message;
      default:
        return 'We couldn\'t sign you in. Please check your details and try again.';
    }
  }

  if (error is PostgrestException) {
    return 'Something went wrong on our end. Please try again in a moment.';
  }

  return 'We couldn\'t reach the server. Please check your connection and try again.';
}
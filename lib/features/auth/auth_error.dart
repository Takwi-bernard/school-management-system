import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns ANY error (auth, database, network, unknown) into a message
/// safe to show a user. Never surfaces raw exception text, stack
/// traces, or Postgres error codes - a user has no way to understand
/// "PostgrestException(message: ..., code: P0001)" and it looks
/// broken/unprofessional even when the underlying issue is minor.
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
        return 'This account belongs to a different school.';
      default:
        return 'We couldn\'t complete that. Please try again.';
    }
  }

  if (error is PostgrestException) {
    // Database-side errors (RPC failures, constraint violations, etc.)
    // - never shown verbatim, always a generic safe fallback.
    return 'Something went wrong on our end. Please try again in a moment.';
  }

  // Covers network failures, timeouts, and anything unexpected - the
  // most common real-world case on a slow or unreliable connection.
  return 'We couldn\'t reach the server. Please check your connection and try again.';
}
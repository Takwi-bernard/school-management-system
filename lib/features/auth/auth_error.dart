import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns ANY error into a message safe AND specific enough for a user
/// to understand, in the language they are using. Our own thrown
/// messages are already human-written, so they pass through (translated
/// where we know them) instead of being flattened to a generic fallback.
String friendlyError(Object error, {bool french = false}) {
  String t(String en, String fr) => french ? fr : en;

  if (error is AuthException) {
    final raw = error.message;
    final low = raw.toLowerCase();

    switch (raw) {
      case 'Invalid login credentials':
        return t('The email or password is incorrect.', 'L\'e-mail ou le mot de passe est incorrect.');
      case 'Email not confirmed':
        return t('Please verify your email before signing in.', 'Veuillez vérifier votre e-mail avant de vous connecter.');
      case 'User already registered':
        return t('An account with this email already exists.', 'Un compte existe déjà avec cet e-mail.');
      case 'WRONG_SCHOOL':
        return t(
          'This account belongs to a different school. Please check the site you\'re signing in from.',
          'Ce compte appartient à un autre établissement. Vérifiez le site depuis lequel vous vous connectez.',
        );
      case 'Your account profile could not be found.':
        return t(
          'Your account profile could not be found. If you are new here, please create an account first.',
          'Le profil de votre compte est introuvable. Si vous êtes nouveau, créez d\'abord un compte.',
        );
      case 'Super Admin accounts sign in through the company portal, not a school site.':
        return t(raw, 'Les comptes Super Admin se connectent via le portail de l\'entreprise, pas sur le site d\'une école.');
      case 'Authentication failed.':
        return t(raw, 'L\'authentification a échoué.');
    }

    // Phone / one-time-code errors
    if (low.contains('expired') || (low.contains('token') && low.contains('invalid'))) {
      return t('That code is wrong or has expired. Please try again or request a new one.', 'Ce code est incorrect ou a expiré. Réessayez ou demandez-en un nouveau.');
    }
    if (low.contains('signups not allowed') || low.contains('user not found')) {
      return t('No account uses this number yet. Please create an account first.', 'Aucun compte n\'utilise ce numéro. Veuillez d\'abord créer un compte.');
    }
    if (low.contains('provider') && (low.contains('phone') || low.contains('sms'))) {
      return t('Sign-in by phone is not available yet. Please use your email.', 'La connexion par téléphone n\'est pas encore disponible. Veuillez utiliser votre e-mail.');
    }
    if (low.contains('rate limit') || low.contains('only request this after') || low.contains('too many')) {
      return t('Too many attempts. Please wait a moment and try again.', 'Trop de tentatives. Patientez un instant puis réessayez.');
    }
    if (low.contains('invalid') && low.contains('phone')) {
      return t('That phone number does not look right.', 'Ce numéro de téléphone semble incorrect.');
    }

    if (low.contains('different from the old')) {
      return t('Your new password must be different from the old one.', 'Votre nouveau mot de passe doit être différent de l\'ancien.');
    }
    if (low.contains('weak') || low.contains('at least') && low.contains('characters')) {
      return t('That password is too weak. Use at least 8 characters.', 'Ce mot de passe est trop faible. Utilisez au moins 8 caractères.');
    }
    if (low.contains('session missing') || low.contains('not authenticated')) {
      return t('Your reset session has expired. Please request a new code.', 'Votre session de réinitialisation a expiré. Demandez un nouveau code.');
    }

    return t('Something went wrong. Please check your details and try again.', 'Un problème est survenu. Vérifiez vos informations puis réessayez.');
  }

  if (error is PostgrestException) {
    return t('Something went wrong on our end. Please try again in a moment.', 'Un problème est survenu de notre côté. Réessayez dans un instant.');
  }

  return t('We couldn\'t reach the server. Please check your connection and try again.', 'Impossible de joindre le serveur. Vérifiez votre connexion puis réessayez.');
}

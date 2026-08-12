import 'package:flutter/material.dart';

/// Static UI chrome strings only. School-specific content (history,
/// mission, achievements, statistics labels, etc.) is bilingual DATA
/// fetched from Supabase already filtered by language - it never
/// belongs in this file.
class AppStrings {
  final Locale locale;
  const AppStrings(this.locale);

  bool get isFrench => locale.languageCode == 'fr';

  String get home => isFrench ? 'Accueil' : 'Home';
  String get about => isFrench ? 'À propos' : 'About';
  String get achievements => isFrench ? 'Réalisations' : 'Achievements';
  String get gallery => isFrench ? 'Galerie' : 'Gallery';
  String get admissions => isFrench ? 'Admissions' : 'Admissions';
  String get contact => isFrench ? 'Contact' : 'Contact';
  String get signIn => isFrench ? 'Se connecter' : 'Sign In';
  String get selectRole =>
      isFrench ? 'Sélectionnez votre rôle' : 'Select your role to continue';

  String get parent => isFrench ? 'Parent' : 'Parent';
  String get teacher => isFrench ? 'Enseignant' : 'Teacher';
  String get principal => isFrench ? 'Directeur' : 'Principal';
  String get secretary => isFrench ? 'Secrétaire' : 'Secretary';
  String get proprietor => isFrench ? 'Promoteur' : 'Proprietor';

  String get applyNow => isFrench ? 'Postuler maintenant' : 'Apply Now';
  String get learnMore => isFrench ? 'En savoir plus' : 'Learn More';
  String get startAdmission =>
      isFrench ? "Commencer l'admission" : 'Start Admission';

  String get ourSchool => isFrench ? 'Notre école' : 'Our School';
  String get mission => isFrench ? 'Mission' : 'Mission';
  String get vision => isFrench ? 'Vision' : 'Vision';
  String get principalMessage =>
      isFrench ? 'Message du Directeur' : 'Message from the Principal';
  String get achievementsTitle =>
      isFrench ? 'Nos réalisations' : 'Our Achievements';
  String get galleryTitle =>
      isFrench ? 'Découvrez notre école' : 'Discover Our School';

  String get announcements => isFrench ? 'Annonces' : 'Announcements';
  String get latestNews => isFrench ? 'Dernières nouvelles' : 'Latest News';
  String get upcomingEvents =>
      isFrench ? 'Événements à venir' : 'Upcoming Events';

  String get quickLinks => isFrench ? 'Liens rapides' : 'Quick Links';
  String get allRightsReserved =>
      isFrench ? 'Tous droits réservés' : 'All rights reserved';
  String get poweredBy => isFrench
      ? 'Propulsé par la plateforme scolaire'
      : 'Powered by the school platform';

  // Authentication
  String get signInTitle => isFrench ? 'Se connecter' : 'Sign In';
  String get email => isFrench ? 'Adresse e-mail' : 'Email';
  String get password => isFrench ? 'Mot de passe' : 'Password';
  String get confirmPassword => isFrench ? 'Confirmer le mot de passe' : 'Confirm Password';
  String get forgotPassword => isFrench ? 'Mot de passe oublié ?' : 'Forgot password?';
  String get orDivider => isFrench ? 'OU' : 'OR';
  String get continueWithGoogle =>
      isFrench ? 'Continuer avec Google' : 'Continue with Google';
  String get noAccount => isFrench ? "Vous n'avez pas de compte ?" : "Don't have an account?";
  String get alreadyHaveAccount => isFrench ? 'Vous avez déjà un compte ?' : 'Already have an account?';
  String get createAccount => isFrench ? 'Créer un compte' : 'Create Account';
  String get chooseAccountType =>
      isFrench ? 'Choisissez votre type de compte' : 'Choose your account type';
  String get parentAccountDesc => isFrench
      ? 'Créez un compte et inscrivez votre enfant'
      : 'Create an account and register your child';
  String get teacherAccountDesc =>
      isFrench ? 'Créez votre compte enseignant' : 'Create your teacher account';
  String get fullName => isFrench ? 'Nom complet' : 'Full Name';
  String get phoneNumber => isFrench ? 'Numéro de téléphone' : 'Phone Number';
  String get childInformation => isFrench ? "Informations sur l'enfant" : "Child Information";
  String get childInformationOptional => isFrench
      ? "Facultatif - vous pourrez le faire plus tard"
      : "Optional - you can do this later";
  String get childFullName => isFrench ? "Nom complet de l'enfant" : "Child's Full Name";
  String get requestedClass => isFrench ? 'Classe demandée' : 'Requested Class';
  String get uploadPhoto => isFrench ? 'Télécharger une photo' : 'Upload Photo';
  String get createParentAccount =>
      isFrench ? 'Créer le compte parent' : 'Create Parent Account';
  String get createTeacherAccount =>
      isFrench ? 'Créer le compte enseignant' : 'Create Teacher Account';
  String get wrongSchoolAccount => isFrench
      ? "Ce compte appartient à une autre école."
      : "This account belongs to a different school.";
}
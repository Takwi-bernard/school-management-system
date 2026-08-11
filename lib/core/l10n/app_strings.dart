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
}
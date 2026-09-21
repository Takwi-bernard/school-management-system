import '../../core/l10n/app_strings.dart';

/// Teacher-module strings added on top of AppStrings. Kept in an
/// extension (instead of editing app_strings.dart) so the existing
/// shared file is untouched. Every name starts with "t" so it can never
/// collide with an existing AppStrings member.
extension TeacherStrings on AppStrings {
  // ---- Marks entry -------------------------------------------------
  String get tInvalidScore =>
      isFrench ? 'Entrez un nombre de 0 à 20' : 'Enter a number from 0 to 20';

  String get tFixScores => isFrench
      ? 'Veuillez corriger les notes signalées en rouge.'
      : 'Please correct the scores marked in red.';

  String get tNothingToSave => isFrench
      ? 'Aucune note à enregistrer pour le moment.'
      : 'There are no scores to save yet.';

  String get tStatusDraft => isFrench ? 'Brouillon' : 'Draft';
  String get tStatusSubmitted => isFrench ? 'Soumis' : 'Submitted';
  String get tStatusApproved => isFrench ? 'Approuvé' : 'Approved';
  String get tStatusRejected => isFrench ? 'Rejeté' : 'Rejected';

  String get tPrincipalFeedback =>
      isFrench ? 'Commentaire du Directeur' : 'Principal feedback';

  String get tSubmitConfirmTitle =>
      isFrench ? 'Soumettre les notes ?' : 'Submit marks?';

  String tSubmitConfirmBody(int entered, int missing) {
    if (isFrench) {
      final base = 'Vous allez soumettre $entered note(s) au Directeur. '
          'Une fois soumises, vous ne pourrez plus les modifier '
          'sauf si le Directeur les rejette.';
      return missing > 0
          ? '$base\n\n$missing élève(s) n\'ont pas encore de note.'
          : base;
    }
    final base = 'You are about to submit $entered score(s) to the Principal. '
        'Once submitted you cannot edit them unless the Principal rejects them.';
    return missing > 0
        ? '$base\n\n$missing student(s) do not have a score yet.'
        : base;
  }

  String get tExamPeriod => isFrench ? 'Période d\'examen' : 'Exam period';

  String get tAllLocked => isFrench
      ? 'Toutes les notes de cette période sont déjà soumises ou approuvées.'
      : 'All marks for this period are already submitted or approved.';

  // ---- Shared ------------------------------------------------------
  String get tCheckStatus => isFrench ? 'Vérifier le statut' : 'Check status';

  // ---- Profile -----------------------------------------------------
  String get tNameRequired =>
      isFrench ? 'Le nom ne peut pas être vide.' : 'Name cannot be empty.';

  String get tPhotoTooLarge => isFrench
      ? 'La photo est trop volumineuse (5 Mo maximum).'
      : 'That photo is too large (5 MB maximum).';

  String get tPhotoBadType => isFrench
      ? 'Format non pris en charge. Utilisez JPG, PNG ou WEBP.'
      : 'Unsupported format. Please use JPG, PNG or WEBP.';

  // ---- Class list / exports ---------------------------------------
  String get tAdmissionNo => isFrench ? 'N° d\'admission' : 'Admission No.';
  String get tGender => isFrench ? 'Sexe' : 'Gender';
  String get tClassListTitle => isFrench ? 'Liste de classe' : 'Class List';

  String tGenderLabel(String value) {
    switch (value) {
      case 'male':
        return isFrench ? 'Masculin' : 'Male';
      case 'female':
        return isFrench ? 'Féminin' : 'Female';
      default:
        return value;
    }
  }
}

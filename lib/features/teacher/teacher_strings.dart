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

  // ---- Dashboard -----------------------------------------------------
  String get tTodaysClasses => isFrench ? 'Cours du jour' : "Today's classes";
  String get tNoClassesToday =>
      isFrench ? 'Aucun cours prévu aujourd\'hui.' : 'No classes scheduled today.';
  String get tNowLabel => isFrench ? 'En cours' : 'Now';
  String get tUpNextLabel => isFrench ? 'À suivre' : 'Up next';
  String get tTakeAttendance => isFrench ? 'Faire l\'appel' : 'Take attendance';
  String get tAttendanceDone => isFrench ? 'Présence faite' : 'Attendance taken';
  String get tAttendanceNotDoneToday =>
      isFrench ? 'Présence non faite aujourd\'hui' : 'Attendance not taken today';

  String get tMarksToDo => isFrench ? 'Notes à traiter' : 'Marks to-do';
  String get tMarksAllCaughtUpTitle =>
      isFrench ? 'Tout est à jour' : "You're all caught up";
  String get tMarksAllCaughtUpBody => isFrench
      ? 'Aucune note en attente pour la période en cours.'
      : 'No marks are waiting on you for the current period.';
  String get tNoOpenPeriod => isFrench
      ? 'Aucune période d\'examen n\'est ouverte pour le moment.'
      : 'No exam period is open right now.';
  String get tMarksStatusNotStarted => isFrench ? 'Non commencé' : 'Not started';
  String tMarksProgress(int entered, int total) =>
      total > 0 ? '$entered/$total' : '$entered';
  String get tDueLabel => isFrench ? 'Échéance' : 'Due';
  String tDueInDays(int days) {
    if (days < 0) return isFrench ? 'En retard' : 'Overdue';
    if (days == 0) return isFrench ? 'Aujourd\'hui' : 'Due today';
    if (days == 1) return isFrench ? 'Demain' : 'Due tomorrow';
    return isFrench ? 'Dans $days jours' : 'Due in $days days';
  }

  String get tMyClasses => isFrench ? 'Mes classes' : 'My classes';
  String tStudentsCount(int count) =>
      isFrench ? '$count élève${count == 1 ? '' : 's'}' : '$count student${count == 1 ? '' : 's'}';
}

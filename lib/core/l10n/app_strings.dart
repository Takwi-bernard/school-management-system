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

  // Teacher module
  String get welcomeBack => isFrench ? 'Bon retour,' : 'Welcome back,';
  String get approvalPending => isFrench ? 'Approbation en attente' : 'Approval Pending';
  String get applicationNotApproved => isFrench ? 'Candidature non approuvée' : 'Application Not Approved';
  String get pendingApprovalMessage => isFrench
      ? "Votre compte a été créé, mais vous n'avez pas encore été approuvé en tant qu'enseignant de cette école. Veuillez attendre l'approbation du Directeur, ou contactez-le directement ci-dessous."
      : "Your account has been created, but you have not yet been approved as a teacher of this school. Please wait for the Principal to approve your account, or contact them directly below.";
  String get rejectedMessage => isFrench
      ? "Votre candidature d'enseignant pour cette école n'a pas été approuvée. Si vous pensez qu'il s'agit d'une erreur, veuillez contacter le Directeur."
      : "Your teacher application for this school was not approved. If you believe this is a mistake, please contact the Principal.";
  String get contactSchool => isFrench ? "Contactez l'école" : 'Contact the school';
  String get myTeaching => isFrench ? 'Mes cours' : 'My Teaching';
  String get noAssignmentsTitle =>
      isFrench ? "Aucune affectation d'enseignement pour le moment" : 'No teaching assignments yet';
  String get noAssignmentsDescription => isFrench
      ? "Dès que le Directeur vous attribue des matières et des classes, elles apparaîtront ici."
      : "Once the Principal assigns you subjects and classes, they'll appear here.";
  String get subjectsLabel => isFrench ? 'Matières' : 'Subjects';
  String get classesLabel => isFrench ? 'Classes' : 'Classes';
  String get assignmentsLabel => isFrench ? 'Affectations' : 'Assignments';
  String get coefficientLabel => isFrench ? 'Coefficient' : 'Coefficient';
  String get coefficientShort => 'Coef.';
  String get signOut => isFrench ? 'Se déconnecter' : 'Sign Out';
  String get periodsPerWeekLabel => isFrench ? 'périodes/semaine' : 'periods/week';
  String get myProfile => isFrench ? 'Mon profil' : 'My Profile';
  String get personalInformation => isFrench ? 'Informations personnelles' : 'Personal Information';
  String get saveChanges => isFrench ? 'Enregistrer les modifications' : 'Save Changes';
  String get whatWouldYouLikeToDo => isFrench ? 'Que souhaitez-vous faire ?' : 'What would you like to do?';
  String get classListLabel => isFrench ? 'Liste de classe' : 'Class List';
  String get viewEnrolledStudents => isFrench ? 'Voir les élèves inscrits' : 'View enrolled students';
  String get marksLabel => isFrench ? 'Notes' : 'Marks';
  String get enterSubmitMarks =>
      isFrench ? 'Saisir et soumettre les notes de séquence' : 'Enter and submit sequence marks';
  String get attendanceLabel => isFrench ? 'Présence' : 'Attendance';
  String get recordDailyAttendance => isFrench ? 'Enregistrer la présence quotidienne' : 'Record daily attendance';
  String get studentsLabel => isFrench ? 'Élèves' : 'Students';
  String get exportNotReady => isFrench
      ? "L'exportation n'est pas encore disponible - à venir dans une prochaine mise à jour."
      : 'Export is not available yet - coming in a future update.';
  String get noStudentsEnrolled =>
      isFrench ? 'Aucun élève inscrit dans cette classe pour le moment.' : 'No students enrolled in this class yet.';
  String get marksNotOpenYet => isFrench
      ? "Le Directeur n'a pas encore ouvert la saisie des notes pour une séquence."
      : 'The Principal has not opened marks entry for any sequence yet.';
  String get dueLabel => isFrench ? 'Échéance' : 'Due';
  String get scoreLabel => isFrench ? 'Note (0-20)' : 'Score (0-20)';
  String get commentOptional => isFrench ? 'Commentaire (facultatif)' : 'Comment (optional)';
  String get saveDraft => isFrench ? 'Enregistrer le brouillon' : 'Save Draft';
  String get submitToPrincipal => isFrench ? 'Soumettre au Directeur' : 'Submit to Principal';
  String get marksSubmittedMessage =>
      isFrench ? 'Notes soumises au Directeur pour examen.' : 'Marks submitted to the Principal for review.';
  String get draftSavedMessage => isFrench ? 'Brouillon enregistré.' : 'Draft saved.';
  String get saveMarksError => isFrench
      ? 'Impossible d\'enregistrer les notes. Veuillez réessayer.'
      : 'Could not save marks. Please try again.';
  String get dateLabel => isFrench ? 'Date' : 'Date';
  String get changeDate => isFrench ? 'Changer la date' : 'Change Date';
  String get statusPresent => isFrench ? 'Présent' : 'Present';
  String get statusAbsent => isFrench ? 'Absent' : 'Absent';
  String get statusLate => isFrench ? 'En retard' : 'Late';
  String get statusExcused => isFrench ? 'Excusé' : 'Excused';
  String get saveAttendance => isFrench ? 'Enregistrer la présence' : 'Save Attendance';
  String get attendanceSavedMessage => isFrench ? 'Présence enregistrée.' : 'Attendance saved.';
  String get saveAttendanceError => isFrench
      ? 'Impossible d\'enregistrer la présence. Veuillez réessayer.'
      : 'Could not save attendance. Please try again.';
  String get myTimetable => isFrench ? 'Mon emploi du temps' : 'My Timetable';
  String get timetableEmpty =>
      isFrench ? "Votre emploi du temps n'a pas encore été configuré." : 'Your timetable has not been configured yet.';
  String get photoUpdatedMessage => isFrench ? 'Photo mise à jour.' : 'Photo updated.';
  String get photoUploadError => isFrench
      ? 'Impossible de télécharger la photo. Veuillez réessayer.'
      : 'Could not upload photo. Please try again.';
  String get profileUpdatedMessage => isFrench ? 'Profil mis à jour.' : 'Profile updated.';
  String get profileSaveError => isFrench
      ? 'Impossible d\'enregistrer les modifications. Veuillez réessayer.'
      : 'Could not save changes. Please try again.';
  String get profileNotFound =>
      isFrench ? 'Votre profil d\'enseignant est introuvable.' : 'Your teacher profile could not be found.';

  List<String> get weekdays => isFrench
      ? ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
      : ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
}
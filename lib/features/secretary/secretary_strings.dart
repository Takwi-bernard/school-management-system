import '../../core/l10n/app_strings.dart';

/// Secretary-module-specific strings, following the same pattern as
/// teacher_strings.dart: everything NOT already covered by the shared
/// AppStrings class lives here, prefixed with "s" so it can never
/// collide with a current or future AppStrings getter of the same name.
extension SecretaryStrings on AppStrings {
  // ---------------- Shell / navigation ----------------
  String get sSecretaryRole => isFrench ? 'Secrétaire' : 'Secretary';
  String get sOverview => isFrench ? 'Aperçu' : 'Overview';
  String get sOverviewDescription => isFrench ? "Ce qui se passe aujourd'hui" : "What's happening today";
  String get sEnrollChild => isFrench ? 'Inscrire un enfant' : 'Enroll a Child';
  String get sEnrollChildDescription => isFrench ? "Trouver ou créer le parent, puis inscrire l'enfant." : 'Find or create the parent, then enroll the child.';
  String get sAwaitingRegistration => isFrench ? "En attente des frais d'inscription" : 'Awaiting Registration Payment';
  String get sAwaitingRegistrationDescription => isFrench ? "Encaisser les frais d'inscription en attente." : 'Collect registration fees still outstanding.';
  String get sCollectFees => isFrench ? 'Encaisser les frais scolaires' : 'Collect School Fees';
  String get sCollectFeesDescription => isFrench ? 'Rechercher un élève et encaisser une tranche.' : 'Look up a student and collect an installment.';
  String get sDirectory => isFrench ? 'Répertoire des élèves' : 'Student Directory';
  String get sDirectoryDescription => isFrench ? 'Parcourir tous les élèves inscrits.' : 'Browse every enrolled student.';
  String get sMyCollections => isFrench ? 'Mes encaissements' : 'My Collections';
  String get sMyCollectionsDescription => isFrench ? 'Historique des paiements que vous avez enregistrés.' : 'A log of payments you have recorded.';

  // ---------------- Dashboard ----------------
  String get sAwaitingRegistrationStat => isFrench ? "Frais d'inscription en attente" : 'Awaiting registration fee';
  String get sCollectedToday => isFrench ? "Encaissé aujourd'hui" : 'Collected today';
  String get sQuickActions => isFrench ? 'Actions rapides' : 'Quick actions';

  // ---------------- Enrollment wizard ----------------
  String get sStepParent => isFrench ? 'Parent' : 'Parent';
  String get sStepChild => isFrench ? 'Enfant' : 'Child';
  String get sStepClass => isFrench ? 'Classe' : 'Class';
  String get sStepGuardian => isFrench ? 'Tuteur' : 'Guardian';
  String get sStepReview => isFrench ? 'Vérification' : 'Review';
  String get sSearchParentLabel => isFrench ? 'Rechercher un parent' : 'Search parent';
  String get sSearchParentHint => isFrench ? 'Nom, téléphone ou e-mail' : 'Name, phone or email';
  String get sNoParentFound => isFrench ? 'Aucun parent trouvé. Vous pouvez créer un compte ci-dessous.' : 'No parent found. You can create an account for them below.';
  String get sCreateNewParentAccount => isFrench ? 'Créer un nouveau compte parent' : 'Create a new parent account';
  String get sChangeParent => isFrench ? 'Changer' : 'Change';
  String get sExistingChildren => isFrench ? 'Déjà inscrits ici :' : 'Already enrolled here:';
  String get sNewParentAccountTitle => isFrench ? 'Nouveau compte parent' : 'New parent account';
  String get sSignInAtLabel => isFrench ? 'Connexion sur' : 'Sign in at';
  String get sTemporaryPasswordLabel => isFrench ? 'Mot de passe temporaire' : 'Temporary password';
  String get sAccountCreatedWarning => isFrench
      ? "Ces informations ne s'affichent qu'une seule fois. Transmettez-les au parent avant de fermer cette fenêtre."
      : 'These details are shown ONLY NOW. Give them to the parent before closing this window.';
  String get sCopy => isFrench ? 'Copier' : 'Copy';
  String get sPrintSlip => isFrench ? 'Imprimer la fiche' : 'Print slip';
  String get sGenderLabel => isFrench ? 'Sexe' : 'Gender';
  String get sMale => isFrench ? 'Masculin' : 'Male';
  String get sFemale => isFrench ? 'Féminin' : 'Female';
  String get sDateOfBirthOptional => isFrench ? 'Date de naissance (facultatif)' : 'Date of birth (optional)';
  String get sChildPhotoHint => isFrench ? "Photo (recommandée - utilisée sur les cartes d'identité et les bulletins)" : 'Photo (recommended - used on ID cards and report cards)';
  String get sDepartmentLabel => isFrench ? 'Département' : 'Department';
  String get sClassLabel => isFrench ? 'Classe' : 'Class';
  String get sSelectDepartmentFirst => isFrench ? "Choisissez d'abord le département, puis la classe." : 'Choose the department first, then the class.';
  String get sNoClassesInDepartment => isFrench ? 'Aucune classe dans ce département.' : 'No classes in this department.';
  String get sGuardianDetailsHint => isFrench ? "Tout est facultatif - aide l'école à joindre la famille." : 'All optional - helps the school reach the family.';
  String get sNext => isFrench ? 'Suivant' : 'Next';
  String get sBack => isFrench ? 'Retour' : 'Back';
  String get sCreateEnrollmentButton => isFrench ? "Créer l'inscription" : 'Create Enrollment';
  String get sSavingLabel => isFrench ? 'Enregistrement...' : 'Saving...';
  String get sReviewParentLabel => isFrench ? 'Parent' : 'Parent';
  String get sReviewChildLabel => isFrench ? 'Enfant' : 'Child';
  String get sReviewGenderLabel => isFrench ? 'Sexe' : 'Gender';
  String get sReviewBornLabel => isFrench ? 'Né(e) le' : 'Born';
  String get sReviewClassLabel => isFrench ? 'Classe' : 'Class';
  String get sReviewSubjectsLabel => isFrench ? 'Matières' : 'Subjects';
  String get sReviewGuardianLabel => isFrench ? 'Tuteur' : 'Guardian';
  String get sReviewEmergencyPhoneLabel => isFrench ? "Téléphone d'urgence" : 'Emergency phone';
  String get sNextStepNote => isFrench
      ? "Ensuite, vous pourrez encaisser les frais d'inscription (espèces, banque ou Mobile Money), ou le faire plus tard."
      : 'Next you will be asked to collect the registration fee (cash, bank, or Mobile Money) - or you can collect it later.';
  String get sEditEnrollmentTitle => isFrench ? "Modifier l'inscription" : 'Edit Enrollment';
  String get sEnrollmentUpdatedMessage => isFrench ? 'Inscription mise à jour.' : 'Enrollment updated.';
  String get sCollectLaterMessage => isFrench
      ? "Inscription enregistrée. Encaissez les frais d'inscription à tout moment depuis « En attente des frais d'inscription »."
      : 'Enrollment saved. Collect the registration fee anytime from "Awaiting Registration Payment".';
  String get sNoFeeConfiguredWarning => isFrench
      ? "aucun frais d'inscription n'est configuré pour cette classe. Demandez au principal de le définir."
      : 'this class has no registration fee configured yet. Ask the Principal to set it under School Fees.';

  // ---------------- Awaiting registration ----------------
  String get sSearchChildOrParentHint => isFrench ? 'Rechercher par enfant ou parent' : 'Search by child or parent';
  String get sNothingAwaitingMessage => isFrench ? "Rien n'attend de paiement d'inscription." : 'Nothing is waiting for a registration payment.';
  String get sNoSearchMatchesMessage => isFrench ? 'Aucun résultat pour cette recherche.' : 'No matches for this search.';
  String get sEnrolledOnLabel => isFrench ? 'Inscrit le' : 'Enrolled';
  String get sNoFeeConfiguredLabel => isFrench ? 'Frais non configurés' : 'No fee configured';
  String get sEditTooltip => isFrench ? 'Modifier' : 'Edit';
  String get sCollectAmountPrefix => isFrench ? 'Encaisser ' : 'Collect ';

  // ---------------- Collect fees / directory ----------------
  String get sSearchStudentHint => isFrench ? "Numéro d'inscription ou nom" : 'Admission number or name';
  String get sNoStudentMatchMessage => isFrench ? 'Aucun élève ne correspond à cette recherche.' : 'No student matches that search.';
  String get sNoFeePlanMessage => isFrench ? 'Aucun plan de frais trouvé pour la classe actuelle de cet élève.' : "No fee plan found for this student's current class.";
  String get sPaidLabel => isFrench ? 'Payé' : 'Paid';
  String get sCollectLabel => isFrench ? 'Encaisser' : 'Collect';
  String get sDueOnLabel => isFrench ? 'échéance' : 'due';
  String get sOfLabel => isFrench ? 'sur' : 'of';
  String get sPaidWord => isFrench ? 'payé' : 'paid';

  // ---------------- Payment dialog ----------------
  String get sConfirmPaymentReceivedTitle => isFrench ? 'Confirmer le paiement reçu' : 'Confirm payment received';
  String get sNotYetLabel => isFrench ? 'Pas encore' : 'Not yet';
  String get sYesRecordItLabel => isFrench ? "Oui, l'enregistrer" : 'Yes, record it';
  String get sCashLabel => isFrench ? 'Espèces' : 'Cash';
  String get sCashSubtitle => isFrench ? "Argent reçu au bureau de l'école" : 'Money received at the school office';
  String get sBankTransferLabel => isFrench ? 'Virement / dépôt bancaire' : 'Bank transfer / deposit';
  String get sBankTransferSubtitle => isFrench ? 'Bordereau ou virement confirmé' : 'Bank slip or transfer confirmed';
  String get sMobileMoneySubtitle => isFrench ? 'Envoyer une demande de paiement au téléphone' : "Send a payment request to the payer's phone";
  String get sMobileMoneyUnavailableMessage => isFrench
      ? "Mobile Money n'est pas configuré pour cette école. Utilisez les espèces ou le virement bancaire."
      : 'Mobile Money is not configured for this school. Use cash or bank transfer instead.';
  String get sPayerPhoneLabel => isFrench ? 'Numéro MTN / Orange Money du payeur' : "Payer's MTN / Orange Money number";
  String get sPayerPhoneHelp => isFrench ? 'Le payeur recevra une invite sur son téléphone et devra entrer son code PIN.' : 'The payer will get a prompt on their phone and must enter their PIN.';
  String get sSendRequestLabel => isFrench ? 'Envoyer la demande' : 'Send request';
  String get sWaitingConfirmationMessage => isFrench ? 'En attente de la confirmation du payeur sur son téléphone...' : 'Waiting for the payer to confirm on their phone...';
  String get sUpdatesAutomaticallyMessage => isFrench ? 'Cette page se met à jour automatiquement.' : 'This updates automatically.';
  String get sCloseKeepsWaitingLabel => isFrench ? "Fermer (continue d'attendre en arrière-plan)" : 'Close (keeps waiting in the background)';
  String get sPaymentRecordedTitle => isFrench ? 'Paiement enregistré' : 'Payment recorded';
  String get sReferenceLabel => isFrench ? 'Référence' : 'Reference';
  String get sFlagForReviewLabel => isFrench ? 'Signaler pour correction' : 'Flag for correction';
  String get sFlagReasonHint => isFrench ? 'Expliquez brièvement ce qui ne va pas (montant, méthode, etc.)' : "Briefly explain what's wrong (amount, method, etc.)";
  String get sFlagSubmittedMessage => isFrench ? 'Signalé. Le principal examinera ce paiement.' : 'Flagged. The Principal will review this payment.';
  String get sFlagAlreadyRequestedLabel => isFrench ? 'Correction déjà demandée' : 'Correction already requested';
  String get sSubmitLabel => isFrench ? 'Envoyer' : 'Submit';
  String get sNotNowLabel => isFrench ? 'Pas maintenant' : 'Not now';
  String get sCannotUndoHint => isFrench
      ? "Ceci sera enregistré. Si vous faites une erreur, vous pourrez la signaler pour correction depuis « Mes encaissements »."
      : 'This will be recorded. If you make a mistake, you can flag it for correction afterward from "My Collections".';

  // ---------------- Directory ----------------
  String get sDirectoryEmptyMessage => isFrench ? 'Aucun élève à afficher.' : 'No students to show.';
  String get sViewCollectFeesLabel => isFrench ? 'Voir / encaisser les frais' : 'View / Collect Fees';
  String get sStudentDetailsTitle => isFrench ? "Détails de l'élève" : 'Student Details';
  String get sNoGuardianOnFile => isFrench ? 'Aucun tuteur enregistré' : 'No guardian on file';
  String get sAdmissionNumberLabel => isFrench ? "Numéro d'inscription" : 'Admission number';

  // ---------------- My collections ----------------
  String get sNoCollectionsYetMessage => isFrench ? "Vous n'avez encore rien encaissé." : "You haven't collected anything yet.";
  String get sCorrectionRequestedLabel => isFrench ? 'Correction demandée' : 'Correction requested';

  // ---------------- Profile ----------------
  String get sChangePhotoLabel => isFrench ? 'Changer la photo' : 'Change photo';
  String get sPhoneOptionalLabel => isFrench ? 'Téléphone (facultatif)' : 'Phone (optional)';
  String get sAccountEmailLabel => isFrench ? 'E-mail du compte' : 'Account email';
}
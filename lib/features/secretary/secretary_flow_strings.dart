import 'package:school_management_system/features/secretary/secretary_strings.dart';

import '../../core/l10n/app_strings.dart';

/// Strings for the two payment / enrollment flows. Kept in its own
/// extension (prefix "f") so secretary_strings.dart does not need to be
/// replaced again and no getter can ever collide with AppStrings or
/// SecretaryStrings.
extension SecretaryFlowStrings on AppStrings {
  // ---------------- generic ----------------
  String get fRefresh => isFrench ? 'Actualiser' : 'Refresh';
  String get fDone => isFrench ? 'Terminé' : 'Done';
  String get fSearch => isFrench ? 'Rechercher' : 'Search';
  String get fMobileMoney => 'Mobile Money';
  String get fPhoneLabel => isFrench ? 'Téléphone' : 'Phone';
  String get fInvalidEmail => isFrench ? 'Entrez une adresse e-mail valide.' : 'Enter a valid email.';

  // ---------------- awaiting registration ----------------
  String fParentLine(String name, String? phone) {
    final base = '${isFrench ? 'Parent' : 'Parent'}: $name';
    return (phone == null || phone.isEmpty) ? base : '$base · $phone';
  }

  String get fRegistrationFeePurpose => isFrench ? "Frais d'inscription" : 'Registration Fee';
  String get fNoFeeHint => isFrench ? 'Demandez au principal de configurer les frais.' : 'Ask the Principal to configure the fee.';

  // ---------------- collect fees ----------------
  String get fFeesHelp => isFrench
      ? "Recherchez par numéro d'inscription ou par nom. Le numéro d'inscription affiché ici permet au parent de retrouver son enfant."
      : 'Search by admission number or name. The admission number shown here is what a parent can use to find their child.';
  String get fSearchPrompt => isFrench ? 'Recherchez un élève pour voir son plan de frais.' : 'Search for a student to see their fee plan.';
  String get fMinCharsHint => isFrench ? 'Saisissez au moins 2 caractères.' : 'Type at least 2 characters.';

  // ---------------- payment dialog ----------------
  String fConfirmReceivedBody(String amount, String method, String purpose, String child) => isFrench
      ? 'Avez-vous bien reçu $amount par $method pour « $purpose » ($child) ?'
      : 'Have you received $amount by $method for "$purpose" ($child)?';
  String fPaymentByLine(String amount, String method) => isFrench ? '$amount par $method' : '$amount by $method';
  String get fInvalidMomoNumber => isFrench ? 'Entrez un numéro Mobile Money valide.' : 'Enter a valid Mobile Money number.';
  String get fPaymentDeclined => isFrench
      ? "Le paiement a été refusé ou a expiré. Réessayez ou utilisez un autre mode de paiement."
      : 'The payment was declined or expired. Try again, or use another method.';
  String get fStillWaiting => isFrench
      ? "Toujours en attente de confirmation. Le paiement peut encore aboutir - vérifiez de nouveau dans quelques instants depuis la liste."
      : 'Still waiting for confirmation. It may still complete - check again shortly from the list.';
  String get fDownloadReceipt => isFrench ? 'Télécharger le reçu' : 'Download receipt';

  // ---------------- enrollment wizard ----------------
  String fStepOf(int n, int total, String title) => isFrench ? 'Étape $n sur $total · $title' : 'Step $n of $total · $title';
  String get fParentStepHelp => isFrench
      ? "Recherchez le parent par nom, téléphone ou e-mail. S'il n'a pas encore de compte, créez-en un."
      : 'Search for the parent by name, phone or email. If they have no account yet, create one.';
  String get fNoEmail => isFrench ? "pas d'e-mail" : 'no email';
  String get fNoPhone => isFrench ? 'pas de téléphone' : 'no phone';
  String get fFirstName => isFrench ? 'Prénom' : 'First name';
  String get fLastName => isFrench ? 'Nom' : 'Last name';
  String get fSelectParentFirst => isFrench ? "Sélectionnez ou créez d'abord le parent." : 'Select or create the parent first.';
  String get fSelectGender => isFrench ? "Veuillez choisir le sexe de l'enfant." : "Please select the child's gender.";
  String get fSelectClass => isFrench ? 'Veuillez choisir une classe.' : 'Please select a class.';
  String get fClassStepHelp => isFrench
      ? "Choisissez d'abord le département, puis la classe - un même nom de classe peut exister dans deux départements."
      : 'Choose the department first, then the class - the same class name can exist in two departments.';
  String get fSubjectsTitle => isFrench ? 'Matières' : 'Subjects';
  String get fCompulsoryLocked => isFrench ? 'Les matières obligatoires sont verrouillées.' : 'Compulsory subjects are locked in.';
  String get fCompulsory => isFrench ? 'Obligatoire' : 'Compulsory';
  String get fOptional => isFrench ? 'Facultative' : 'Optional';
  String get fNoSubjectsConfigured => isFrench ? "Aucune matière n'est encore configurée pour cette classe." : 'No subjects are configured for this class yet.';
  String get fGuardianName => isFrench ? 'Nom du tuteur' : 'Guardian name';
  String get fEmergencyName => isFrench ? "Nom du contact d'urgence" : 'Emergency contact name';
  String get fEmergencyPhone => isFrench ? "Téléphone du contact d'urgence" : 'Emergency contact phone';
  String get fAddress => isFrench ? 'Adresse' : 'Address';
  String get fKeepCurrentPhoto => isFrench ? 'Touchez pour changer la photo' : 'Tap to change the photo';
  String get fPhotoPickError => isFrench ? "Impossible de lire cette image. Essayez une autre photo." : 'Could not read that image. Try another photo.';
  String get fEditNote => isFrench
      ? "Vous modifiez une inscription dont les frais d'inscription n'ont pas encore été payés. Le parent n'est pas modifiable."
      : 'You are editing an enrollment whose registration fee has not been paid yet. The parent cannot be changed.';
  String fEnrollmentCreatedNoFee(String child) => isFrench
      ? 'Inscription créée pour $child, mais $sNoFeeConfiguredWarning'
      : 'Enrollment created for $child, but $sNoFeeConfiguredWarning';
  String fRegistrationFeeRecorded(String child) => isFrench
      ? "Frais d'inscription enregistrés. $child est maintenant chez le principal pour approbation."
      : 'Registration fee recorded. $child is now with the Principal for approval.';
  String get fSaveChanges => isFrench ? 'Enregistrer les modifications' : 'Save changes';

  // ---------------- new parent / credentials ----------------
  String get fEmailLoginLabel => isFrench ? 'E-mail (identifiant de connexion)' : 'Email (their login)';
  String get fCreateAccount => isFrench ? 'Créer le compte' : 'Create account';
  String get fParentAccountCreatedTitle => isFrench ? 'Compte parent créé' : 'Parent account created';
  String get fCopiedMessage => isFrench ? 'Copié.' : 'Copied.';
  String get fSlipTitle => isFrench ? 'DÉTAILS DU COMPTE PARENT' : 'PARENT ACCOUNT DETAILS';
  String get fSlipNote => isFrench
      ? 'Veuillez vous connecter et changer votre mot de passe immédiatement. Gardez cette fiche confidentielle.'
      : 'Please sign in and change your password right away. Keep this slip private.';
  String get fSlipError => isFrench ? "Impossible de générer la fiche." : 'Could not generate the slip.';
  String fCredentialsPlainText(String school, String url, String email, String password) => isFrench
      ? '$school\nCompte parent\nConnexion : $url\nE-mail : $email\nMot de passe temporaire : $password\nVeuillez changer votre mot de passe après la connexion.'
      : '$school\nParent account\nSign in: $url\nEmail: $email\nTemporary password: $password\nPlease change your password after signing in.';
}
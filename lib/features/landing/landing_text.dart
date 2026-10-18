/// Landing-page wording that is not in AppStrings, kept bilingual in one
/// place so no landing widget has a hardcoded English string.
class LandingText {
  final bool fr;
  const LandingText(this.fr);

  String get signOut => fr ? 'Se déconnecter' : 'Sign out';
  String get dashboard => fr ? 'Mon espace' : 'Dashboard';
  String get readMore => fr ? 'Lire la suite' : 'Read more';
  String get showLess => fr ? 'Réduire' : 'Show less';
  String get retry => fr ? 'Réessayer' : 'Try again';
  String get language => fr ? 'Langue' : 'Language';
  String get backToTop => fr ? 'Haut de page' : 'Back to top';
  String get menu => fr ? 'Menu' : 'Menu';
  String get quickLinks => fr ? 'Liens rapides' : 'Quick links';
  String get getInTouch => fr ? 'Contactez-nous' : 'Get in touch';
  String get contactTitle => fr ? 'Nous sommes à votre écoute' : "We'd love to hear from you";
  String get phone => fr ? 'Téléphone' : 'Phone';
  String get email => fr ? 'E-mail' : 'Email';
  String get address => fr ? 'Adresse' : 'Address';
  String get website => fr ? 'Site web' : 'Website';
  String get tapToCopy => fr ? 'Touchez pour copier' : 'Tap to copy';
  String get copied => fr ? 'Copié' : 'Copied';
  String get parentOnly => fr ? 'Les admissions se gèrent depuis un compte parent.' : 'Admission is managed from a parent account.';
  String get loadFailed => fr ? 'Impossible de charger cette page. Vérifiez votre connexion.' : "We couldn't load this page. Please check your connection.";
  String get admissionsLead => fr
      ? 'Créez un compte parent et commencez la demande d\'admission de votre enfant en ligne.'
      : "Create a parent account and start your child's application online.";
  String academicYear(String year) => fr ? 'Année scolaire $year' : 'Academic year $year';
  String get close => fr ? 'Fermer' : 'Close';

  static const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _monthsFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

  String month(DateTime d) => (fr ? _monthsFr : _monthsEn)[d.month - 1];
  String date(DateTime d) => '${d.day} ${month(d)} ${d.year}';
}

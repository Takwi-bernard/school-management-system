import '../../core/l10n/app_strings.dart';

/// Shared formatting for every Proprietor screen, so money, dates and
/// percentages read identically everywhere.

String pMoney(num v) {
  final neg = v < 0;
  final digits = v.abs().round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '${neg ? '-' : ''}$grouped FCFA';
}

/// Compact form for chart axes and tight tiles: 1.2M, 450K.
String pCompact(num v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  String trim(double x) {
    final s = x.toStringAsFixed(x >= 100 ? 0 : 1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (a >= 1000000000) return '$sign${trim(a / 1000000000)}B';
  if (a >= 1000000) return '$sign${trim(a / 1000000)}M';
  if (a >= 1000) return '$sign${trim(a / 1000)}K';
  return '$sign${a.round()}';
}

String _two(int n) => n.toString().padLeft(2, '0');

String pDate(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}';
}

String pDateTime(DateTime d) {
  final l = d.toLocal();
  return '${pDate(l)} ${_two(l.hour)}:${_two(l.minute)}';
}

const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _monthsLongEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthsLongFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

String pMonthShort(AppStrings s, DateTime d) => (s.isFrench ? _monthsFr : _monthsEn)[d.month - 1];
String pMonthLong(AppStrings s, DateTime d) => '${(s.isFrench ? _monthsLongFr : _monthsLongEn)[d.month - 1]} ${d.year}';

String pPercent(double v, {int decimals = 0}) => '${v.toStringAsFixed(decimals)}%';

/// Month-over-month change as a signed percentage; null when there is
/// no previous value to compare against.
double? pDelta(double current, double previous) {
  if (previous <= 0) return null;
  return (current - previous) / previous * 100;
}

String pSigned(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}%';

String pMethodLabel(AppStrings s, String method) {
  switch (method) {
    case 'cash':
      return s.isFrench ? 'Espèces' : 'Cash';
    case 'bank_transfer':
      return s.isFrench ? 'Virement bancaire' : 'Bank transfer';
    case 'mtn_momo':
      return 'MTN MoMo';
    case 'orange_money':
      return 'Orange Money';
    default:
      return method.isEmpty ? '-' : method;
  }
}

/// Greeting by Douala hour of day.
String pGreeting(AppStrings s) {
  final h = DateTime.now().toUtc().add(const Duration(hours: 1)).hour;
  if (h < 12) return s.isFrench ? 'Bonjour' : 'Good morning';
  if (h < 18) return s.isFrench ? 'Bonne après-midi' : 'Good afternoon';
  return s.isFrench ? 'Bonsoir' : 'Good evening';
}
import '../../core/l10n/app_strings.dart';
import 'secretary_strings.dart';

/// Shared formatting helpers for the whole Secretary module, so every
/// screen shows money, dates, and payment methods identically.

String formatMoney(double v) {
  final digits = v.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$grouped FCFA';
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}';
}

String formatTime(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

String formatDateTime(DateTime d) => '${formatDate(d)} ${formatTime(d)}';

String paymentMethodLabel(AppStrings s, String method) {
  switch (method) {
    case 'cash':
      return s.sCashLabel;
    case 'bank_transfer':
      return s.sBankTransferLabel;
    case 'mtn_momo':
      return 'MTN MoMo';
    case 'orange_money':
      return 'Orange Money';
    default:
      return method;
  }
}

String genderLabel(AppStrings s, String? gender) {
  if (gender == 'male') return s.sMale;
  if (gender == 'female') return s.sFemale;
  return '-';
}

String closeLabel(AppStrings s) => s.isFrench ? 'Fermer' : 'Close';
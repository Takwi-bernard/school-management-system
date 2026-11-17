import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

// ============================================================
// MOBILE MONEY PAYMENT PAGES
//
// Two focused, full-screen steps (not part of the shell tabs):
//   1. MobileMoneyPaymentPage - review, enter number, confirm.
//   2. PaymentStatusPage      - waits for the parent to approve on
//      their phone, and keeps checking until it KNOWS the result.
//
// The status page is built for a weak network. It never gives up
// on a single failed request, it reads the payment straight from
// the database (light) and asks the provider (heavier) in turn,
// it re-checks the moment the parent comes back to the tab, and it
// always shows proof of life ("checked 8s ago") so a slow network
// never looks like a scam.
//
// Also used for registration fees (child == null,
// admissionRequestId set instead).
// ============================================================

/// Soft fade + rise-in, staggered by [delayMs]. Used so the screen
/// settles in rather than appearing all at once.
class _FadeIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const _FadeIn({required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    final total = 420 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
      ),
      child: child,
    );
  }
}

/// Keeps only digits, drops a pasted +237 / 237 prefix, caps at the
/// 9 digits of a Cameroonian mobile number.
class _CmPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('237') && d.length > 9) d = d.substring(3);
    if (d.length > 9) d = d.substring(0, 9);
    return TextEditingValue(text: d, selection: TextSelection.collapsed(offset: d.length));
  }
}

String _maskPhone(String digits) {
  if (digits.length < 9) return digits;
  return '${digits.substring(0, 3)} ••• ••${digits.substring(7)}';
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// The amount, what it is for, and who gets it - shown identically
/// on both pages so the parent always sees exactly what they are
/// paying. On the status page it also carries the reference.
class _AmountCard extends StatelessWidget {
  final bool fr;
  final String schoolName;
  final String purpose;
  final String? childName;
  final double amount;
  final String? reference;
  final DateTime? requestedAt;

  const _AmountCard({
    required this.fr,
    required this.schoolName,
    required this.purpose,
    required this.amount,
    this.childName,
    this.reference,
    this.requestedAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget row(String label, String value, {Widget? trailing}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fr ? 'MONTANT' : 'AMOUNT',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatAmount(amount)} FCFA',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          row(fr ? 'Pour' : 'For', purpose),
          if (childName != null && childName!.isNotEmpty) row(fr ? 'Élève' : 'Student', childName!),
          row(fr ? 'Payé à' : 'Paid to', schoolName),
          if (requestedAt != null) row(fr ? 'Demandé à' : 'Requested', _hm(requestedAt!)),
          if (reference != null && reference!.isNotEmpty)
            row(
              fr ? 'Référence' : 'Reference',
              reference!,
              trailing: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: reference!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(fr ? 'Référence copiée' : 'Reference copied'), duration: const Duration(seconds: 2)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 16, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A calm inline message: amber for "needs attention", red for
/// "didn't work". Replaces SnackBars for anything the parent must
/// actually read (a SnackBar disappears before a slow reader or a
/// distracted parent has finished it).
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Notice({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(height: 1.45))),
        ],
      ),
    );
  }
}

// ============================================================
// STEP 1 - PAYMENT PAGE
// ============================================================

class MobileMoneyPaymentPage extends ConsumerStatefulWidget {
  final EnrolledChild? child;
  final String? admissionRequestId;
  final String? installmentId;
  final LandingModel landing;
  final double amount;
  final String paymentPurpose;

  const MobileMoneyPaymentPage({
    super.key,
    this.child,
    this.admissionRequestId,
    this.installmentId,
    required this.landing,
    required this.amount,
    required this.paymentPurpose,
  });

  @override
  ConsumerState<MobileMoneyPaymentPage> createState() => _MobileMoneyPaymentPageState();
}

class _MobileMoneyPaymentPageState extends ConsumerState<MobileMoneyPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _friendlyError(Object e, bool fr) {
    if (e is TimeoutException) {
      return fr
          ? 'Le réseau est lent et nous n\'avons pas pu confirmer l\'envoi de la demande. Avant de réessayer, ouvrez l\'historique des paiements pour vérifier qu\'elle n\'est pas déjà partie.'
          : 'The network is slow and we could not confirm the request was sent. Before trying again, check your Payment history to make sure it did not already go through.';
    }
    final text = e.toString().replaceFirst('Exception: ', '').trim();
    final technical = text.contains('ClientException') ||
        text.contains('SocketException') ||
        text.contains('XMLHttpRequest') ||
        text.contains('Failed host lookup') ||
        text.contains('FunctionException') ||
        text.startsWith('Instance of');
    if (text.isEmpty || technical) {
      return fr
          ? 'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.'
          : 'We couldn\'t reach the server. Check your connection and try again.';
    }
    return text;
  }

  /// One last, explicit look before any money moves - amount, number
  /// and who receives it. Costs one tap, prevents wrong-number
  /// payments, and tells a nervous parent exactly what will happen.
  Future<bool> _confirmSheet(String digits, bool fr) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      builder: (ctx) {
        return Theme(
          data: theme,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.phone_android_rounded, color: scheme.primary, size: 28),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    fr ? 'Envoyer la demande de paiement ?' : 'Send the payment request?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fr
                        ? '${_formatAmount(widget.amount)} FCFA seront demandés au numéro ${_maskPhone(digits)} pour ${widget.paymentPurpose}, au profit de ${widget.landing.schoolName}.'
                        : '${_formatAmount(widget.amount)} FCFA will be requested from ${_maskPhone(digits)} for ${widget.paymentPurpose}, paid to ${widget.landing.schoolName}.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fr
                        ? 'Aucun argent n\'est prélevé avant que vous saisissiez votre code secret sur votre téléphone.'
                        : 'No money is taken until you enter your PIN on your phone.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(fr ? 'Oui, envoyer la demande' : 'Yes, send the request'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(fr ? 'Modifier le numéro' : 'Change the number'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _pay() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final fr = AppStrings(ref.read(activeLocaleProvider)).isFrench;
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    final confirmed = await _confirmSheet(digits, fr);
    if (!confirmed || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transaction = await ref
          .read(parentRepositoryProvider)
          .initiatePayment(
            schoolId: widget.landing.schoolId,
            childId: widget.child?.studentId,
            admissionRequestId: widget.admissionRequestId,
            installmentId: widget.installmentId,
            amount: widget.amount,
            paymentPurpose: widget.paymentPurpose,
            phoneNumber: digits,
          )
          .timeout(const Duration(seconds: 40));
      if (!mounted) return;
      // The new pending payment should appear in history / fees at once.
      ref.invalidate(paymentHistoryProvider);
      ref.invalidate(pendingInstallmentsProvider);
      context.pushReplacement('/parent/payment-status', extra: {
        'transactionId': transaction.id,
        'landing': widget.landing,
        'child': widget.child,
        'paymentPurpose': widget.paymentPurpose,
        'amount': widget.amount,
        'maskedPhone': _maskPhone(digits),
        'startedAt': DateTime.now(),
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e, fr));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final fr = strings.isFrench;
    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      child: Builder(
        // A fresh Theme.of(context) from BELOW the Theme(...) wrapper -
        // reading it from the outer build() context would silently
        // fall back to the app's default colors instead of this school's.
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;

          Widget step(int n, String text) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Text('$n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(height: 1.4))),
                  ],
                ),
              );

          return Scaffold(
            appBar: AppBar(title: Text(strings.mobileMoneyPayment)),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          brandedSubpageHeader(context, schoolName: widget.landing.schoolName, logoUrl: widget.landing.logoUrl),
                          _FadeIn(
                            child: _AmountCard(
                              fr: fr,
                              schoolName: widget.landing.schoolName,
                              purpose: widget.paymentPurpose,
                              childName: widget.child?.fullName,
                              amount: widget.amount,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _FadeIn(
                            delayMs: 90,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  fr ? 'Numéro Mobile Money' : 'Mobile Money number',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _phoneController,
                                  enabled: !_loading,
                                  keyboardType: TextInputType.phone,
                                  autofillHints: const [AutofillHints.telephoneNumberNational],
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [_CmPhoneFormatter()],
                                  onFieldSubmitted: (_) => _pay(),
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                                  decoration: InputDecoration(
                                    hintText: '6XX XXX XXX',
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(left: 14, right: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.phone_android_rounded, size: 18, color: scheme.onSurfaceVariant),
                                          const SizedBox(width: 8),
                                          Text('+237', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: scheme.primary, width: 1.6),
                                    ),
                                  ),
                                  validator: (v) {
                                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                    if (!RegExp(r'^6\d{8}$').hasMatch(digits)) return strings.enterValidNumber;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  fr
                                      ? 'Le numéro MTN ou Orange Money qui recevra la demande de paiement (9 chiffres, commence par 6).'
                                      : 'The MTN or Orange Money number that will receive the payment request (9 digits, starts with 6).',
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _FadeIn(
                            delayMs: 160,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fr ? 'Comment ça marche' : 'How it works',
                                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                                  ),
                                  const SizedBox(height: 4),
                                  step(1, fr ? 'Vous confirmez ici. Une demande part vers votre téléphone.' : 'You confirm here. A request is sent to your phone.'),
                                  step(2, fr ? 'Vous saisissez votre code secret Mobile Money sur le téléphone.' : 'You enter your Mobile Money PIN on the phone.'),
                                  step(3, fr ? 'Cette page confirme le paiement et vous donne un reçu.' : 'This page confirms the payment and gives you a receipt.'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _FadeIn(
                            delayMs: 220,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    fr
                                        ? 'Paiement sécurisé. L\'argent n\'est prélevé qu\'après votre code secret, et ${widget.landing.schoolName} le reçoit directement.'
                                        : 'Secure payment. Money is only taken after you enter your PIN, and ${widget.landing.schoolName} receives it directly.',
                                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _Notice(icon: Icons.error_outline_rounded, color: kOverdue, text: _error!),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _loading ? null : _pay,
                              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _loading
                                    ? Row(
                                        key: const ValueKey('sending'),
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary)),
                                          const SizedBox(width: 12),
                                          Text(fr ? 'Envoi de la demande...' : 'Sending request...'),
                                        ],
                                      )
                                    : Row(
                                        key: const ValueKey('idle'),
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.lock_rounded, size: 17),
                                          const SizedBox(width: 10),
                                          Text(
                                            fr ? 'Payer ${_formatAmount(widget.amount)} FCFA' : 'Pay ${_formatAmount(widget.amount)} FCFA',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// STEP 2 - PAYMENT STATUS PAGE
// ============================================================

enum _Phase { waiting, slow, paused, success, failed, cancelled }

/// Calm "waiting" visual: a phone with two soft rings that expand
/// and fade. Motion that says "alive and working" without colour noise.
class _PulsingBadge extends StatefulWidget {
  final Color color;
  final IconData icon;
  const _PulsingBadge({super.key, required this.color, required this.icon});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          Widget ring(double phaseShift) {
            final t = (_c.value + phaseShift) % 1.0;
            return Opacity(
              opacity: (1 - t) * 0.35,
              child: Container(
                width: 76 + 44 * t,
                height: 76 + 44 * t,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2)),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              ring(0),
              ring(0.5),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(widget.icon, size: 36, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Result badge (success / failed / cancelled) that pops in.
class _ResultBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _ResultBadge({super.key, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 50, color: color),
      ),
    );
  }
}

enum _StepState { done, active, todo }

class _StepTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final _StepState state;
  final bool last;
  final Color doneColor;
  const _StepTile({required this.title, this.subtitle, required this.state, required this.doneColor, this.last = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color c = switch (state) {
      _StepState.done => doneColor,
      _StepState.active => scheme.primary,
      _StepState.todo => scheme.outlineVariant,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: state == _StepState.todo ? Colors.transparent : c.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: c, width: 1.6),
                  ),
                  child: switch (state) {
                    _StepState.done => Icon(Icons.check_rounded, size: 14, color: c),
                    _StepState.active => SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: c)),
                    _StepState.todo => null,
                  },
                ),
                if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: scheme.outlineVariant.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: state == _StepState.active ? FontWeight.w800 : FontWeight.w600,
                      color: state == _StepState.todo ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentStatusPage extends ConsumerStatefulWidget {
  final String transactionId;
  final LandingModel landing;
  final EnrolledChild? child;
  final String paymentPurpose;
  final double amount;

  /// e.g. "670 ••• ••12" - never the full number.
  final String? maskedPhone;

  /// When the payment was requested. Null = just now. The Payment
  /// History tab passes the row's own created_at when it reopens an
  /// older pending payment here.
  final DateTime? startedAt;

  const PaymentStatusPage({
    super.key,
    required this.transactionId,
    required this.landing,
    this.child,
    required this.paymentPurpose,
    required this.amount,
    this.maskedPhone,
    this.startedAt,
  });

  @override
  ConsumerState<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends ConsumerState<PaymentStatusPage> with WidgetsBindingObserver {
  // After this long the screen switches from "waiting for you" to the
  // reassuring "taking longer than usual" message. It keeps checking.
  static const _slowAfterSeconds = 90;

  // How long one stretch of automatic checking lasts. After that it
  // pauses (so it does not eat a parent's mobile data forever) and
  // offers "Check again". Coming back to the tab also re-checks.
  static const _checkBudget = Duration(minutes: 10);

  late final DateTime _startedAt;
  late DateTime _budgetStart;

  PaymentTransaction? _tx;
  String? _reference;

  bool _checking = false; // a check is running right now (also the re-entry guard)
  bool _manualChecking = false; // ...and the parent asked for it
  bool _paused = false;
  bool _offline = false;
  bool _receiptBusy = false;
  int _failures = 0;
  int _cycles = 0;
  DateTime? _lastChecked;
  bool _slowShown = false;

  Timer? _pollTimer;
  Timer? _tickTimer;
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  bool get _isTerminal => _tx?.isTerminal ?? false;
  int get _elapsedSeconds => DateTime.now().difference(_startedAt).inSeconds;

  _Phase get _phase {
    final t = _tx;
    if (t != null && t.isSuccessful) return _Phase.success;
    if (t != null && t.isCancelled) return _Phase.cancelled;
    if (t != null && t.isFailed) return _Phase.failed;
    if (_paused) return _Phase.paused;
    if (_elapsedSeconds >= _slowAfterSeconds) return _Phase.slow;
    return _Phase.waiting;
  }

  @override
  void initState() {
    super.initState();
    _startedAt = widget.startedAt ?? DateTime.now();
    _budgetStart = DateTime.now();
    _slowShown = _elapsedSeconds >= _slowAfterSeconds;
    WidgetsBinding.instance.addObserver(this);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _tick.value++;
      if (!_slowShown && !_isTerminal && _elapsedSeconds >= _slowAfterSeconds) {
        _slowShown = true;
        setState(() {});
      }
    });
    // setState (used inside _cycle) is not allowed during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cycle();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  /// The parent usually leaves for their Mobile Money prompt and comes
  /// back. The moment they do, check right away instead of waiting
  /// for the next scheduled round.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isTerminal && !_paused) {
      _failures = 0;
      _pollTimer?.cancel();
      _cycle();
    }
  }

  void _scheduleNext() {
    _pollTimer?.cancel();
    if (!mounted || _isTerminal) return;
    if (DateTime.now().difference(_budgetStart) >= _checkBudget) {
      if (!_paused) setState(() => _paused = true);
      return;
    }
    final e = _elapsedSeconds;
    final baseSeconds = e < 60 ? 3 : (e < 180 ? 5 : 10);
    // Failed rounds (bad network) slow the pace gently instead of
    // hammering a connection that is already struggling - but never stop.
    final raw = 1 + _failures * 0.7;
    final factor = raw > 4.0 ? 4.0 : raw;
    _pollTimer = Timer(Duration(milliseconds: (baseSeconds * factor * 1000).round()), _cycle);
  }

  /// One round of checking. Light read first (the payment row, which
  /// the provider's webhook updates), then - every third round, or
  /// when the parent taps "Check now" - ask the provider directly.
  /// Neither failing ends the loop: a failed request is a slow
  /// network, not a failed payment.
  Future<void> _cycle({bool manual = false}) async {
    if (!mounted || _isTerminal) return;
    if (_checking) {
      // A round is already running - just show the parent that their
      // tap was heard; it clears when that round finishes.
      if (manual) setState(() => _manualChecking = true);
      return;
    }
    setState(() {
      _checking = true;
      if (manual) _manualChecking = true;
    });
    _cycles++;
    var reachedServer = false;
    try {
      final repo = ref.read(parentRepositoryProvider);

      PaymentTransaction? row;
      try {
        row = await repo.getPaymentById(widget.transactionId).timeout(const Duration(seconds: 12));
        reachedServer = true;
      } catch (_) {
        // Weak connection - fall through, try the other route.
      }
      if (!mounted) return;
      if (row != null) {
        if (row.isTerminal) {
          _finish(row);
          return;
        }
        _reference = row.transactionReference ?? _reference;
      }

      if (manual || _cycles % 3 == 1) {
        try {
          final verified = await repo.verifyPayment(widget.transactionId).timeout(const Duration(seconds: 20));
          reachedServer = true;
          if (!mounted) return;
          if (verified.isTerminal) {
            PaymentTransaction? full;
            try {
              full = await repo.getPaymentById(widget.transactionId).timeout(const Duration(seconds: 10));
            } catch (_) {}
            if (!mounted) return;
            _finish(full ?? _mergePartial(verified));
            return;
          }
          _reference = verified.transactionReference ?? _reference;
        } catch (_) {
          // Provider check unavailable right now - the next round retries.
        }
      }

      if (!mounted) return;
      setState(() {
        _failures = reachedServer ? 0 : _failures + 1;
        _offline = !reachedServer;
        if (reachedServer) _lastChecked = DateTime.now();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _manualChecking = false;
        });
        _scheduleNext();
      }
    }
  }

  /// verify-parent-payment only reliably returns status + reference.
  /// Fill the rest from what this page already knows so the receipt
  /// never prints "0 FCFA" / "Payment".
  PaymentTransaction _mergePartial(PaymentTransaction v) {
    return PaymentTransaction(
      id: v.id,
      status: v.status,
      amount: widget.amount,
      paymentPurpose: widget.paymentPurpose,
      childName: widget.child?.fullName,
      transactionReference: v.transactionReference ?? _reference,
      createdAt: _startedAt,
    );
  }

  void _finish(PaymentTransaction t) {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    setState(() {
      _tx = t;
      _reference = t.transactionReference ?? _reference;
      _offline = false;
      _paused = false;
    });
    // Everything that depends on this payment must refresh now -
    // not the next time the parent happens to open it.
    ref.invalidate(paymentHistoryProvider);
    ref.invalidate(childFeesProvider);
    ref.invalidate(pendingAdmissionsProvider);
    ref.invalidate(enrolledChildrenProvider);
    ref.invalidate(pendingInstallmentsProvider);
    if (t.isSuccessful) HapticFeedback.mediumImpact();
  }

  void _checkNow() {
    if (_paused) {
      setState(() {
        _paused = false;
        _budgetStart = DateTime.now();
        _failures = 0;
      });
    }
    _pollTimer?.cancel();
    _cycle(manual: true);
  }

  void _goHome() => context.go('/parent');

  void _tryAgain() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/parent');
    }
  }

  Future<void> _generateReceipt(bool fr) async {
    final tx = _tx;
    if (tx == null || _receiptBusy) return;
    setState(() => _receiptBusy = true);
    try {
      await generateReceiptPdf(ref: ref, transaction: tx, landing: widget.landing, isFrench: fr);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(fr ? 'Échec du téléchargement. Veuillez réessayer.' : 'Download failed. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _receiptBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final fr = strings.isFrench;
    String t(String en, String frText) => fr ? frText : en;

    final phase = _phase;
    final terminal = phase == _Phase.success || phase == _Phase.failed || phase == _Phase.cancelled;
    final waitingLike = phase == _Phase.waiting || phase == _Phase.slow;

    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        final Color phaseColor = switch (phase) {
          _Phase.success => kSettled,
          _Phase.failed || _Phase.cancelled => kOverdue,
          _Phase.paused => kPending,
          _ => scheme.primary,
        };

        final String title = switch (phase) {
          _Phase.success => strings.paymentSuccessful,
          _Phase.cancelled => t('Payment cancelled', 'Paiement annulé'),
          _Phase.failed => strings.paymentFailed,
          _Phase.paused => t('We paused the checking', 'Vérification en pause'),
          _Phase.slow => t('Still waiting for confirmation', 'Toujours en attente de confirmation'),
          _Phase.waiting => t('Approve on your phone', 'Validez sur votre téléphone'),
        };

        final phone = widget.maskedPhone;
        final String message = switch (phase) {
          _Phase.success => t(
              'Your payment has been confirmed. The school can now see this update.',
              'Votre paiement a été confirmé. L\'école peut maintenant voir cette mise à jour.'),
          _Phase.cancelled || _Phase.failed => t(
              'The payment was not completed. If money was deducted from your account, do not pay again: contact the school and give them the reference below.',
              'Le paiement n\'a pas abouti. Si de l\'argent a été débité de votre compte, ne payez pas à nouveau : contactez l\'école avec la référence ci-dessous.'),
          _Phase.paused => t(
              'We have not received a confirmation yet, and the request may have expired. Tap "Check again". If money left your account, do not pay again: contact the school with the reference below.',
              'Nous n\'avons pas encore reçu de confirmation et la demande a peut-être expiré. Appuyez sur « Vérifier à nouveau ». Si de l\'argent a quitté votre compte, ne payez pas à nouveau : contactez l\'école avec la référence ci-dessous.'),
          _Phase.slow => t(
              'Networks can be slow - this is normal. Please do not pay again. If you already entered your PIN, this page updates by itself the moment the network confirms. We are still checking.',
              'Le réseau peut être lent, c\'est normal. Ne payez pas une deuxième fois. Si vous avez déjà saisi votre code secret, cette page se met à jour dès que le réseau confirme. Nous continuons de vérifier.'),
          _Phase.waiting => phone != null
              ? t(
                  'We sent a payment request to $phone. Open the prompt on your phone and enter your Mobile Money PIN.',
                  'Nous avons envoyé une demande de paiement au $phone. Ouvrez la notification sur votre téléphone et saisissez votre code secret Mobile Money.')
              : t(
                  'Open the prompt on your phone and enter your Mobile Money PIN.',
                  'Ouvrez la notification sur votre téléphone et saisissez votre code secret Mobile Money.'),
        };

        final Widget hero = switch (phase) {
          _Phase.success => _ResultBadge(key: const ValueKey('ok'), color: kSettled, icon: Icons.check_rounded),
          _Phase.failed => _ResultBadge(key: const ValueKey('fail'), color: kOverdue, icon: Icons.close_rounded),
          _Phase.cancelled => _ResultBadge(key: const ValueKey('cancel'), color: kOverdue, icon: Icons.block_rounded),
          _Phase.paused => _ResultBadge(key: const ValueKey('pause'), color: kPending, icon: Icons.schedule_rounded),
          _ => _PulsingBadge(key: const ValueKey('wait'), color: scheme.primary, icon: Icons.phone_android_rounded),
        };

        final stepsFailed = phase == _Phase.failed || phase == _Phase.cancelled;

        return Scaffold(
          appBar: AppBar(title: Text(strings.paymentStatus), automaticallyImplyLeading: false),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      brandedSubpageHeader(context, schoolName: widget.landing.schoolName, logoUrl: widget.landing.logoUrl),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          child: hero,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey(phase),
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: terminal ? phaseColor : null),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: (_offline && !terminal)
                            ? Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _Notice(
                                  icon: Icons.wifi_off_rounded,
                                  color: kPending,
                                  text: t(
                                    'Weak connection. We keep trying automatically - your payment is not affected.',
                                    'Connexion faible. Nous continuons d\'essayer automatiquement - votre paiement n\'est pas affecté.'),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 20),
                      _FadeIn(
                        child: _AmountCard(
                          fr: fr,
                          schoolName: widget.landing.schoolName,
                          purpose: widget.paymentPurpose,
                          childName: widget.child?.fullName ?? _tx?.childName,
                          amount: widget.amount,
                          reference: _reference,
                          requestedAt: _startedAt,
                        ),
                      ),
                      if (!terminal) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _StepTile(
                                title: t('Request sent', 'Demande envoyée'),
                                subtitle: phone != null ? t('To $phone', 'Au $phone') : null,
                                state: _StepState.done,
                                doneColor: kSettled,
                              ),
                              _StepTile(
                                title: t('You approve on your phone', 'Vous validez sur votre téléphone'),
                                subtitle: t('Enter your Mobile Money PIN', 'Saisissez votre code secret Mobile Money'),
                                state: _StepState.active,
                                doneColor: kSettled,
                              ),
                              _StepTile(
                                title: t('Payment confirmed', 'Paiement confirmé'),
                                subtitle: t('You get your receipt here', 'Vous recevez votre reçu ici'),
                                state: _StepState.todo,
                                doneColor: kSettled,
                                last: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Proof of life: the parent can SEE the system is
                        // still working, even when nothing else changes.
                        Center(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _tick,
                            builder: (context, _, __) {
                              final lc = _lastChecked;
                              String label;
                              if (_checking) {
                                label = t('Checking now...', 'Vérification en cours...');
                              } else if (lc == null) {
                                label = t('Starting...', 'Démarrage...');
                              } else {
                                final s = DateTime.now().difference(lc).inSeconds;
                                final ago = s < 5
                                    ? t('just now', 'à l\'instant')
                                    : s < 60
                                        ? t('${s}s ago', 'il y a ${s}s')
                                        : t('${s ~/ 60} min ago', 'il y a ${s ~/ 60} min');
                                label = t('Last checked $ago', 'Dernière vérification : $ago');
                              }
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_checking && !_paused)
                                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: scheme.onSurfaceVariant))
                                  else
                                    Icon(Icons.update_rounded, size: 14, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      // ---------------- actions ----------------
                      if (phase == _Phase.success) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _receiptBusy ? null : () => _generateReceipt(fr),
                          icon: _receiptBusy
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                              : const Icon(Icons.receipt_long_rounded),
                          label: Text(strings.downloadReceipt),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: _goHome,
                          child: Text(t('Back to my account', 'Retour à mon compte')),
                        ),
                      ],
                      if (stepsFailed) ...[
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _tryAgain,
                          child: Text(strings.tryAgain),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: _goHome,
                          child: Text(t('Back to my account', 'Retour à mon compte')),
                        ),
                      ],
                      if (waitingLike) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: _manualChecking ? null : _checkNow,
                          icon: _manualChecking
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh_rounded),
                          label: Text(t('Check now', 'Vérifier maintenant')),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _goHome,
                          child: Text(t('Leave this page', 'Quitter cette page')),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(
                            'You can leave safely. If you do, the payment still completes - find it under Payment history.',
                            'Vous pouvez quitter sans risque. Le paiement aboutit quand même - retrouvez-le dans l\'historique des paiements.'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                        ),
                      ],
                      if (phase == _Phase.paused) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _manualChecking ? null : _checkNow,
                          icon: _manualChecking
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                              : const Icon(Icons.refresh_rounded),
                          label: Text(t('Check again', 'Vérifier à nouveau')),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: _goHome,
                          child: Text(t('Back to my account', 'Retour à mon compte')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================
// SHARED RECEIPT PDF GENERATOR - used by both the payment-status
// screen and the payment-history tab, so a receipt looks identical
// no matter where it's generated from.
// ============================================================

String _formatReceiptDate(DateTime d, bool isFrench) {
  const monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const monthsFr = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  final months = isFrench ? monthsFr : monthsEn;
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final minute = d.minute.toString().padLeft(2, '0');
  return isFrench
      ? '${d.day} ${months[d.month - 1]} ${d.year} \u00b7 ${d.hour.toString().padLeft(2, '0')}:$minute'
      : '${months[d.month - 1]} ${d.day}, ${d.year} \u00b7 $hour12:$minute $ampm';
}

String _formatAmount(double amount) {
  final whole = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return buffer.toString();
}

/// Layout mirrors the report card / class list PDFs: an edge-to-edge
/// letterhead (8 mm margin) when the school has uploaded one, with the
/// body independently inset 2.5 cm - normal letter margins - rather
/// than lining up with the letterhead's own edge. No letterhead: the
/// whole page uses the 2.5 cm margin.
Future<void> generateReceiptPdf({
  required WidgetRef ref,
  required PaymentTransaction transaction,
  required LandingModel landing,
  required bool isFrench,
}) async {
  String t(String en, String fr) => isFrench ? fr : en;

  final assets = await ref.read(officialBrandingProvider(landing.schoolId).future);
  final branding = await OfficialBranding.fetch(assets);

  pw.MemoryImage? fallbackLogo;
  if (branding.letterhead == null && landing.logoUrl.isNotEmpty) {
    try {
      final res = await http.get(Uri.parse(landing.logoUrl));
      if (res.statusCode == 200) fallbackLogo = pw.MemoryImage(res.bodyBytes);
    } catch (_) {
      // No fallback logo - the document just prints without one.
    }
  }

  final accent = PdfColor.fromInt(0xFF1E8E5A); // matches kSettled - "paid", on paper too
  final hasLetterhead = branding.letterhead != null;
  const letterheadMargin = 8 * PdfPageFormat.mm;
  const bodyMargin = 2.5 * PdfPageFormat.cm;
  final bodyInset = hasLetterhead ? bodyMargin - letterheadMargin : 0.0;
  final letterheadWidth = PdfPageFormat.a5.width - 2 * letterheadMargin;

  pw.Widget row(String label, String value, {bool valueBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: valueBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor,
              )),
        ],
      ),
    );
  }

  pw.Widget divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Container(height: 0.5, color: PdfColors.grey300, width: double.infinity),
      );

  final body = <pw.Widget>[
    pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            t('PAYMENT RECEIPT', 'REÇU DE PAIEMENT'),
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
          ),
          pw.SizedBox(height: 6),
          pw.Container(width: 44, height: 2, color: accent),
        ],
      ),
    ),
    pw.SizedBox(height: 16),
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          row(t('Student', 'Élève'), transaction.childName ?? '-'),
          divider(),
          row(t('Payment purpose', 'Objet du paiement'), transaction.paymentPurpose),
          divider(),
          row(t('Amount', 'Montant'), '${_formatAmount(transaction.amount)} FCFA', valueBold: true),
          divider(),
          row(t('Transaction reference', 'Référence de transaction'), transaction.transactionReference ?? '-'),
          divider(),
          row(t('Date', 'Date'), _formatReceiptDate(transaction.createdAt, isFrench)),
          divider(),
          row(t('Status', 'Statut'), t('PAID', 'PAYÉ'), valueColor: accent, valueBold: true),
        ],
      ),
    ),
    pw.SizedBox(height: 22),
    pw.Align(alignment: pw.Alignment.centerRight, child: buildStampBlock(branding.proprietorStamp)),
    pw.SizedBox(height: 16),
    pw.Text(
      t('Generated automatically by the school management system.', 'Généré automatiquement par le système de gestion scolaire.'),
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    ),
    pw.SizedBox(height: 4),
    pw.Text(
      t(
        'If this receipt does not correspond to a valid transaction in our records, please contact the school Principal for rectification.',
        'Si ce reçu ne correspond pas à une transaction valide dans nos registres, veuillez contacter le Directeur de l\'école pour rectification.',
      ),
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
    ),
  ];

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: hasLetterhead
          ? const pw.EdgeInsets.fromLTRB(letterheadMargin, letterheadMargin, letterheadMargin, letterheadMargin)
          : const pw.EdgeInsets.all(bodyMargin),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (hasLetterhead)
            buildFullWidthLetterhead(branding: branding, width: letterheadWidth)
          else
            buildDocumentHeader(
              branding: branding,
              schoolName: landing.schoolName,
              motto: landing.motto,
              fallbackLogo: fallbackLogo,
            ),
          pw.SizedBox(height: 14),
          for (final widget in body)
            pw.Padding(padding: pw.EdgeInsets.symmetric(horizontal: bodyInset), child: widget),
        ],
      ),
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: 'receipt_${transaction.id}.pdf');
}
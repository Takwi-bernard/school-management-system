import 'package:flutter/material.dart';
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
// MOBILE MONEY PAYMENT PAGE
// Also used directly for registration fees (child == null in that
// case, admissionRequestId set instead). Still a legacy pushed page
// this pass - a payment flow benefits from being a focused,
// full-screen step regardless of the shell migration elsewhere.
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

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final transaction = await ref.read(parentRepositoryProvider).initiatePayment(
            schoolId: widget.landing.schoolId,
            childId: widget.child?.studentId,
            admissionRequestId: widget.admissionRequestId,
            installmentId: widget.installmentId,
            amount: widget.amount,
            paymentPurpose: widget.paymentPurpose,
            phoneNumber: _phoneController.text.trim(),
          );
      if (!mounted) return;
      context.pushReplacement('/parent/payment-status', extra: {
        'transactionId': transaction.id,
        'landing': widget.landing,
        'child': widget.child,
        'paymentPurpose': widget.paymentPurpose,
        'amount': widget.amount,
      });
    } catch (e) {
      if (mounted) {
        // initiatePayment throws Exception(serverMessage) - strip the
        // "Exception: " prefix Dart adds so the parent doesn't see it.
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      child: Builder(
        // A fresh Theme.of(context) here, from the context BELOW the
        // Theme(...) wrapper above - reading it from the outer build()
        // context (before the wrapper applies) would silently fall
        // back to the app's default colors instead of this school's.
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return Scaffold(
            appBar: AppBar(title: Text(strings.mobileMoneyPayment)),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        brandedSubpageHeader(context, schoolName: widget.landing.schoolName, logoUrl: widget.landing.logoUrl),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.phone_android_rounded, size: 32, color: scheme.onPrimary),
                              const SizedBox(height: 10),
                              Text(
                                widget.paymentPurpose,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                              ),
                              if (widget.child != null) ...[
                                const SizedBox(height: 2),
                                Text(widget.child!.fullName, style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75), fontSize: 12)),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                '${widget.amount.toStringAsFixed(0)} FCFA',
                                style: TextStyle(color: scheme.onPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: strings.mobileMoneyNumber,
                            hintText: '6XXXXXXXX',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          validator: (v) {
                            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 9) return strings.enterValidNumber;
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.isFrench
                              ? 'Utilisez le numéro MTN ou Orange Money qui recevra la demande de paiement.'
                              : 'Use the MTN or Orange Money number that will receive the payment request.',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: kPending.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 18, color: kPending),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  strings.isFrench
                                      ? 'Après avoir appuyé sur "Confirmer", vous recevrez une demande sur votre téléphone. Entrez votre code secret Mobile Money pour terminer le paiement.'
                                      : 'After tapping "Confirm", you will receive a prompt on your phone. Enter your Mobile Money PIN to complete the payment.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _pay,
                            child: _loading
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                                : Text(strings.confirmPayment),
                          ),
                        ),
                      ],
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
// PAYMENT STATUS PAGE
// ============================================================

class PaymentStatusPage extends ConsumerStatefulWidget {
  final String transactionId;
  final LandingModel landing;
  final EnrolledChild? child;
  final String paymentPurpose;
  final double amount;

  const PaymentStatusPage({
    super.key,
    required this.transactionId,
    required this.landing,
    this.child,
    required this.paymentPurpose,
    required this.amount,
  });

  @override
  ConsumerState<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends ConsumerState<PaymentStatusPage> {
  // 20 tries * 6s = 2 minutes. Past that a Mobile Money prompt has
  // almost certainly expired - polling forever (silently, on a page
  // the parent may have walked away from) wastes their data for no
  // reason, so it stops and offers a manual re-check instead.
  static const _maxAttempts = 20;

  PaymentTransaction? _transaction;
  bool _checking = false;
  bool _timedOut = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final result = await ref.read(parentRepositoryProvider).verifyPayment(widget.transactionId);
      if (!mounted) return;
      setState(() => _transaction = result);
      if (!result.isTerminal) {
        _attempts++;
        if (_attempts >= _maxAttempts) {
          setState(() => _timedOut = true);
          return;
        }
        await Future.delayed(const Duration(seconds: 6));
        if (mounted) _poll();
      } else {
        ref.invalidate(pendingAdmissionsProvider);
        ref.invalidate(enrolledChildrenProvider);
      }
    } catch (_) {
      // A network blip while polling isn't a failed payment - just
      // stop this round quietly; "Check again" lets the parent retry.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _checkAgain() {
    setState(() {
      _timedOut = false;
      _attempts = 0;
    });
    _poll();
  }

  Future<void> _generateReceipt(BuildContext context) async {
    final strings = AppStrings(ref.read(activeLocaleProvider));
    await generateReceiptPdf(ref: ref, transaction: _transaction!, landing: widget.landing, isFrench: strings.isFrench);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final t = _transaction;
    final success = t?.isSuccessful ?? false;
    // A cancelled payment reads the same as a failed one here - both
    // are dead ends that need a fresh attempt, just worded differently.
    final failed = (t?.isFailed ?? false) || (t?.isCancelled ?? false);
    final cancelled = t?.isCancelled ?? false;

    final statusColor = success
        ? kSettled
        : failed
            ? kOverdue
            : kPending;
    final statusIcon = success
        ? Icons.check_circle_rounded
        : failed
            ? Icons.cancel_rounded
            : _timedOut
                ? Icons.schedule_rounded
                : Icons.hourglass_top_rounded;

    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      // Builder gives a context BELOW the Theme(...) above, so the
      // Theme.of(context) calls inside actually read this school's
      // theme - reading it from build()'s own context (above the
      // wrapper) would silently fall back to the app's default.
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(
        appBar: AppBar(title: Text(strings.paymentStatus), automaticallyImplyLeading: false),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  brandedSubpageHeader(context, schoolName: widget.landing.schoolName, logoUrl: widget.landing.logoUrl),
                  const SizedBox(height: 18),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(statusIcon, size: 48, color: statusColor),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    success
                        ? strings.paymentSuccessful
                        : cancelled
                            ? (strings.isFrench ? 'Paiement annulé' : 'Payment cancelled')
                            : failed
                                ? strings.paymentFailed
                                : _timedOut
                                    ? (strings.isFrench ? 'Toujours en attente' : 'Still pending')
                                    : strings.paymentPending,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    success
                        ? (strings.isFrench
                            ? 'Votre paiement a été confirmé. L\'école peut maintenant voir cette mise à jour.'
                            : 'Your payment has been confirmed. The school can now see this update.')
                        : failed
                            ? (strings.isFrench
                                ? 'Le paiement n\'a pas pu être confirmé. Vous pouvez réessayer.'
                                : 'The payment could not be confirmed. You can try again.')
                            : _timedOut
                                ? (strings.isFrench
                                    ? 'Nous n\'avons pas encore reçu de confirmation. Vous pouvez vérifier à nouveau, ou consulter l\'historique des paiements plus tard.'
                                    : 'We haven\'t received confirmation yet. You can check again, or look at your payment history later.')
                                : (strings.isFrench
                                    ? 'Vérifiez votre téléphone et entrez votre code secret Mobile Money pour continuer. Cette page se mettra à jour automatiquement.'
                                    : 'Check your phone and enter your Mobile Money PIN to continue. This page will update automatically.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 26),
                  if (success)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _generateReceipt(context),
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: Text(strings.downloadReceipt),
                      ),
                    ),
                  if (!success && !failed && !_timedOut)
                    const Padding(padding: EdgeInsets.only(top: 4), child: CircularProgressIndicator()),
                  if (!success && !failed && _timedOut)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _checkAgain,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(strings.isFrench ? 'Vérifier à nouveau' : 'Check again'),
                      ),
                    ),
                  if (failed)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(strings.tryAgain)),
                    ),
                ],
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

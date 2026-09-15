import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final theme = Theme.of(context);

    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      child: Scaffold(
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
                    const SizedBox(height: 8),
                    Icon(Icons.phone_android_rounded, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(widget.paymentPurpose, style: theme.textTheme.titleMedium),
                    if (widget.child != null)
                      Text(widget.child!.fullName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 8),
                    Text('${widget.amount.toStringAsFixed(0)} FCFA', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: strings.mobileMoneyNumber,
                        hintText: '6XXXXXXXX',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18),
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
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(strings.confirmPayment),
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
  PaymentTransaction? _transaction;
  bool _checking = false;

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
      if (result.isPending) {
        await Future.delayed(const Duration(seconds: 6));
        if (mounted) _poll();
      } else {
        ref.invalidate(pendingAdmissionsProvider);
        ref.invalidate(enrolledChildrenProvider);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _generateReceipt(BuildContext context) async {
    await generateReceiptPdf(ref: ref, transaction: _transaction!, landing: widget.landing);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final t = _transaction;
    final success = t?.isSuccessful ?? false;
    final failed = t?.isFailed ?? false;

    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      child: Scaffold(
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
                  const SizedBox(height: 8),
                  Icon(
                    success ? Icons.check_circle_rounded : failed ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                    size: 72,
                    color: success ? Colors.green : failed ? Colors.red : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    success ? strings.paymentSuccessful : failed ? strings.paymentFailed : strings.paymentPending,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                            : (strings.isFrench
                                ? 'Vérifiez votre téléphone et entrez votre code secret Mobile Money pour continuer. Cette page se mettra à jour automatiquement.'
                                : 'Check your phone and enter your Mobile Money PIN to continue. This page will update automatically.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 24),
                  if (success)
                    FilledButton.icon(
                      onPressed: () => _generateReceipt(context),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text(strings.downloadReceipt),
                    ),
                  if (!success && !failed) const Padding(padding: EdgeInsets.only(top: 12), child: CircularProgressIndicator()),
                  if (failed) OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(strings.tryAgain)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SHARED RECEIPT PDF GENERATOR - used by both the payment-status
// screen and the payment-history tab, so a receipt looks identical
// no matter where it's generated from.
// ============================================================

String _formatReceiptDate(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final minute = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year} \u00b7 $hour12:$minute $ampm';
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

Future<void> generateReceiptPdf({
  required WidgetRef ref,
  required PaymentTransaction transaction,
  required LandingModel landing,
}) async {
  final assets = await ref.read(officialBrandingProvider(landing.schoolId).future);
  final branding = await OfficialBranding.fetch(assets);

  pw.MemoryImage? fallbackLogo;
  if (branding.letterhead == null && landing.logoUrl.isNotEmpty) {
    try {
      final res = await http.get(Uri.parse(landing.logoUrl));
      if (res.statusCode == 200) fallbackLogo = pw.MemoryImage(res.bodyBytes);
    } catch (_) {}
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            buildDocumentHeader(
              branding: branding,
              schoolName: landing.schoolName,
              motto: landing.motto,
              fallbackLogo: fallbackLogo,
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 1.5, color: PdfColors.grey400, width: double.infinity),
            pw.SizedBox(height: 16),
            pw.Text('PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 1.4)),
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _pdfRow('Student', transaction.childName ?? '-'),
                  _pdfDivider(),
                  _pdfRow('Payment purpose', transaction.paymentPurpose),
                  _pdfDivider(),
                  _pdfRow('Amount', '${_formatAmount(transaction.amount)} FCFA', valueBold: true),
                  _pdfDivider(),
                  _pdfRow('Transaction reference', transaction.transactionReference ?? '-'),
                  _pdfDivider(),
                  _pdfRow('Date', _formatReceiptDate(transaction.createdAt)),
                  _pdfDivider(),
                  _pdfRow('Status', 'PAID', valueColor: PdfColors.green800, valueBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Align(alignment: pw.Alignment.centerRight, child: buildStampBlock(branding.proprietorStamp)),
            pw.SizedBox(height: 16),
            pw.Text('Generated automatically by the school management system.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(
              'If this receipt does not correspond to a valid transaction in our records, '
              'please contact the school Principal for rectification.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: 'receipt_${transaction.id}.pdf');
}

pw.Widget _pdfDivider() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Container(height: 0.5, color: PdfColors.grey300, width: double.infinity),
    );

pw.Widget _pdfRow(String label, String value, {bool valueBold = false, PdfColor? valueColor}) {
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
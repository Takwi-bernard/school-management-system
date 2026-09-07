import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

// ============================================================
// CHILD FEES PAGE
// ============================================================

class ChildFeesPage extends ConsumerWidget {
  final EnrolledChild child;
  const ChildFeesPage({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider).value;
    if (landing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final academicYearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));

    return Theme(
      data: buildSchoolTheme(landing.primaryColor, landing.secondaryColor),
      child: Scaffold(
        appBar: AppBar(title: Text(strings.schoolFees)),
        body: academicYearIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (yearId) {
            if (yearId == null) {
              return _FeesInfoState(icon: Icons.event_busy_rounded, message: strings.academicYearNotSet);
            }
            if (child.classId == null) {
              return _FeesInfoState(
                icon: Icons.info_outline_rounded,
                message: strings.isFrench
                    ? 'La classe de cet enfant n\'est pas encore confirmée par l\'école.'
                    : 'This child\'s class has not been confirmed by the school yet.',
              );
            }
            final feesAsync = ref.watch(
              childFeesProvider((studentId: child.studentId, classId: child.classId!, academicYearId: yearId)),
            );
            return feesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (fees) {
                if (fees.isEmpty) {
                  return _FeesInfoState(icon: Icons.receipt_long_outlined, message: strings.noFeesConfigured);
                }
                return ListView(
                  padding: EdgeInsets.all(Responsive.pagePadding(context)),
                  children: [
                    brandedSubpageHeader(
                      context,
                      schoolName: landing.schoolName,
                      logoUrl: landing.logoUrl,
                      subtitle: child.fullName,
                    ),

                    // Explicit confirmation - this screen only exists for a
                    // real enrolled student, which by definition means
                    // registration is already paid. Say so plainly instead
                    // of leaving the parent to infer it.
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              strings.isFrench
                                  ? 'Frais d\'inscription payés. ${child.firstName} est officiellement inscrit(e) à ${landing.schoolName}.'
                                  : 'Registration fee paid. ${child.firstName} is officially enrolled at ${landing.schoolName}.',
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    ...fees.map((fee) => _FeeCard(fee: fee, child: child, landing: landing, strings: strings)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FeesInfoState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _FeesInfoState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// The states an installment can be in, purely computed from data
/// already available (isPaid + dueDate vs today) - nothing new to
/// store, just clearer presentation of what's already there.
enum _InstallmentUrgency { paid, overdue, dueSoon, upcoming, noDueDate }

_InstallmentUrgency _urgencyOf(InstallmentSummary i) {
  if (i.isPaid) return _InstallmentUrgency.paid;
  if (i.dueDate == null) return _InstallmentUrgency.noDueDate;
  final daysLeft = i.dueDate!.difference(DateTime.now()).inDays;
  if (daysLeft < 0) return _InstallmentUrgency.overdue;
  if (daysLeft <= 7) return _InstallmentUrgency.dueSoon;
  return _InstallmentUrgency.upcoming;
}

class _FeeCard extends StatelessWidget {
  final FeeSummary fee;
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _FeeCard({required this.fee, required this.child, required this.landing, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = fee.totalAmount <= 0 ? 0.0 : (fee.amountPaid / fee.totalAmount).clamp(0.0, 1.0);
    final unpaidCount = fee.installments.where((i) => !i.isPaid).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(fee.feeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text('${fee.totalAmount.toStringAsFixed(0)} FCFA', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),

          Text(
            fee.fullyPaid
                ? (strings.isFrench
                    ? 'Tous les frais de scolarité ont été réglés.'
                    : 'All school fees have been settled.')
                : strings.isFrench
                    ? 'L\'école a divisé ces frais en ${fee.installments.length} versements. Il reste $unpaidCount versement${unpaidCount > 1 ? 's' : ''} à payer.'
                    : 'The school has split this fee into ${fee.installments.length} installment${fee.installments.length > 1 ? 's' : ''}. $unpaidCount remain${unpaidCount == 1 ? 's' : ''} unpaid.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text(
            '${fee.amountPaid.toStringAsFixed(0)} / ${fee.totalAmount.toStringAsFixed(0)} FCFA  ·  '
            '${(progress * 100).toStringAsFixed(0)}% ${strings.isFrench ? 'payé' : 'paid'}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),

          if (fee.fullyPaid)
            Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.isFrench ? 'Rien d\'autre à payer pour le moment.' : 'Nothing else to pay right now.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            )
          else
            ...fee.installments.map((i) => _InstallmentRow(installment: i, child: child, landing: landing, strings: strings)),
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final InstallmentSummary installment;
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _InstallmentRow({
    required this.installment,
    required this.child,
    required this.landing,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = _urgencyOf(installment);

    final (Color badgeColor, String badgeText, IconData badgeIcon) = switch (urgency) {
      _InstallmentUrgency.paid => (Colors.green, strings.isFrench ? 'Payé' : 'Paid', Icons.check_circle_rounded),
      _InstallmentUrgency.overdue => (Colors.red, strings.isFrench ? 'En retard' : 'Overdue', Icons.error_rounded),
      _InstallmentUrgency.dueSoon => (Colors.orange, strings.isFrench ? 'Échéance proche' : 'Due soon', Icons.schedule_rounded),
      _InstallmentUrgency.upcoming => (theme.colorScheme.primary, strings.isFrench ? 'À venir' : 'Upcoming', Icons.event_rounded),
      _InstallmentUrgency.noDueDate => (theme.colorScheme.outline, strings.isFrench ? 'Non payé' : 'Unpaid', Icons.radio_button_unchecked_rounded),
    };

    String? explanation;
    if (urgency == _InstallmentUrgency.overdue) {
      final daysLate = DateTime.now().difference(installment.dueDate!).inDays;
      explanation = strings.isFrench
          ? 'La date limite était il y a $daysLate jour${daysLate > 1 ? 's' : ''}. Veuillez régulariser dès que possible pour éviter tout retard supplémentaire.'
          : 'This was due $daysLate day${daysLate > 1 ? 's' : ''} ago. Please settle it as soon as possible to avoid falling further behind.';
    } else if (urgency == _InstallmentUrgency.dueSoon) {
      final daysLeft = installment.dueDate!.difference(DateTime.now()).inDays;
      explanation = strings.isFrench
          ? 'Échéance dans $daysLeft jour${daysLeft > 1 ? 's' : ''}.'
          : 'Due in $daysLeft day${daysLeft > 1 ? 's' : ''}.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgency == _InstallmentUrgency.overdue
            ? Colors.red.withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgency == _InstallmentUrgency.overdue ? Colors.red.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, color: badgeColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(installment.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (installment.dueDate != null)
                      Text('${strings.due}: ${_formatDate(installment.dueDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (explanation != null) ...[
            const SizedBox(height: 8),
            Text(explanation, style: theme.textTheme.bodySmall?.copyWith(color: badgeColor)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${installment.amount.toStringAsFixed(0)} FCFA', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.push('/parent/payment', extra: {
                  'child': child,
                  'landing': landing,
                  'amount': installment.amount,
                  'paymentPurpose': installment.name,
                  'installmentId': installment.installmentId,
                }),
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(strings.payNow),
                style: urgency == _InstallmentUrgency.overdue
                    ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ============================================================
// MOBILE MONEY PAYMENT PAGE
// Also used directly for registration fees (child == null in that
// case, admissionRequestId set instead).
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
                    Text('${widget.amount.toStringAsFixed(0)} FCFA',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
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
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
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
      // Keep the screen usable; next manual retry can try again.
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
                  if (!success && !failed)
                    const Padding(padding: EdgeInsets.only(top: 12), child: CircularProgressIndicator()),
                  if (failed)
                    OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(strings.tryAgain)),
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
// SHARED RECEIPT PDF GENERATOR - used by BOTH the payment-status
// screen (right after paying) and the payment history screen (any
// past transaction), so a receipt looks identical no matter where
// it's generated from.
// ============================================================

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
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            buildDocumentHeader(
              branding: branding,
              schoolName: landing.schoolName,
              motto: landing.motto,
              fallbackLogo: fallbackLogo,
            ),
            pw.SizedBox(height: 16),
            pw.Text('PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            _pdfRow('Student', transaction.childName ?? '-'),
            _pdfRow('Payment purpose', transaction.paymentPurpose),
            _pdfRow('Amount', '${transaction.amount.toStringAsFixed(0)} FCFA'),
            _pdfRow('Transaction reference', transaction.transactionReference ?? '-'),
            _pdfRow('Date', transaction.createdAt.toString().split('.').first),
            _pdfRow('Status', 'PAID'),
            pw.Divider(),
            pw.SizedBox(height: 10),
            // A receipt is a financial document - stamped by the
            // Proprietor's seal, not the Principal's (academic
            // documents like report cards use the Principal stamp
            // instead - see parent_report_cards.dart).
            pw.Align(alignment: pw.Alignment.centerRight, child: buildStampBlock(branding.proprietorStamp)),
            pw.SizedBox(height: 10),
            pw.Text('Generated automatically by the school management system.',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: 'receipt_${transaction.id}.pdf');
}

pw.Widget _pdfRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: const pw.TextStyle(fontSize: 10)), pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))],
    ),
  );
}

// ============================================================
// PAYMENT HISTORY PAGE - every transaction across every child,
// newest first, with a download option on each successful one.
// ============================================================

class PaymentHistoryPage extends ConsumerWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider).value;
    if (landing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final historyAsync = ref.watch(paymentHistoryProvider);

    return Theme(
      data: buildSchoolTheme(landing.primaryColor, landing.secondaryColor),
      child: Scaffold(
        appBar: AppBar(title: Text(strings.paymentHistory)),
        body: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (transactions) {
            if (transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(strings.noPaymentsYet, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.all(Responsive.pagePadding(context)),
              children: [
                brandedSubpageHeader(context, schoolName: landing.schoolName, logoUrl: landing.logoUrl),
                Text(
                  strings.isFrench
                      ? 'Toutes vos transactions, pour tous vos enfants, les plus récentes en premier.'
                      : 'All your transactions, across all your children, most recent first.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 16),
                ...transactions.map((t) => _PaymentHistoryTile(transaction: t, landing: landing, strings: strings)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaymentHistoryTile extends ConsumerStatefulWidget {
  final PaymentTransaction transaction;
  final LandingModel landing;
  final AppStrings strings;
  const _PaymentHistoryTile({required this.transaction, required this.landing, required this.strings});

  @override
  ConsumerState<_PaymentHistoryTile> createState() => _PaymentHistoryTileState();
}

class _PaymentHistoryTileState extends ConsumerState<_PaymentHistoryTile> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await generateReceiptPdf(ref: ref, transaction: widget.transaction, landing: widget.landing);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.transaction;
    final strings = widget.strings;

    final (Color color, String label, IconData icon) = t.isSuccessful
        ? (Colors.green, strings.isFrench ? 'Payé' : 'Paid', Icons.check_circle_rounded)
        : t.isFailed
            ? (Colors.red, strings.isFrench ? 'Échoué' : 'Failed', Icons.cancel_rounded)
            : (Colors.orange, strings.isFrench ? 'En attente' : 'Pending', Icons.hourglass_top_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.paymentPurpose, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (t.childName != null)
                      Text(t.childName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Text('${t.amount.toStringAsFixed(0)} FCFA', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Text(_formatDate(t.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          if (t.isSuccessful) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(strings.downloadReceipt),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
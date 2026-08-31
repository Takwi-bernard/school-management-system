import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

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
        appBar: AppBar(title: Text('${strings.schoolFees} - ${child.fullName}')),
        body: academicYearIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (yearId) {
            if (yearId == null) {
              return Center(child: Text(strings.academicYearNotSet));
            }
            final feesAsync = ref.watch(childFeesProvider((studentId: child.studentId, academicYearId: yearId)));
            return feesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (fees) {
                if (fees.isEmpty) {
                  return Center(child: Text(strings.noFeesConfigured));
                }
                return ListView(
                  padding: EdgeInsets.all(Responsive.pagePadding(context)),
                  children: fees
                      .map((fee) => _FeeCard(fee: fee, child: child, landing: landing, strings: strings))
                      .toList(),
                );
              },
            );
          },
        ),
      ),
    );
  }
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fee.feeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 8),
          Text('${fee.amountPaid.toStringAsFixed(0)} / ${fee.totalAmount.toStringAsFixed(0)} FCFA',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          // DYNAMIC INSTALLMENTS - whatever the school configured, in
          // whatever names/order/count it chose. Never assumes exactly 3.
          ...fee.installments.map((i) => _InstallmentRow(installment: i, fee: fee, child: child, landing: landing, strings: strings)),
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final InstallmentSummary installment;
  final FeeSummary fee;
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const _InstallmentRow({
    required this.installment,
    required this.fee,
    required this.child,
    required this.landing,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(installment.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: installment.isPaid ? Colors.green : theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(installment.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (installment.dueDate != null)
                  Text('${strings.due}: ${_formatDate(installment.dueDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Text('${installment.amount.toStringAsFixed(0)} FCFA', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          if (!installment.isPaid)
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileMoneyPaymentPage(
                    child: child,
                    landing: landing,
                    amount: installment.amount,
                    paymentPurpose: installment.name,
                  ),
                ),
              ),
              child: Text(strings.payNow),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Also used directly for registration fees (child == null in that
/// case, admissionRequestId set instead) - see the optional
/// constructor params below.
class MobileMoneyPaymentPage extends ConsumerStatefulWidget {
  final EnrolledChild? child;
  final String? admissionRequestId;
  final LandingModel landing;
  final double amount;
  final String paymentPurpose;

  const MobileMoneyPaymentPage({
    super.key,
    this.child,
    this.admissionRequestId,
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
            amount: widget.amount,
            paymentPurpose: widget.paymentPurpose,
            phoneNumber: _phoneController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusPage(
            transactionId: transaction.id,
            landing: widget.landing,
            child: widget.child,
            paymentPurpose: widget.paymentPurpose,
            amount: widget.amount,
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(activeLocaleProvider));

    return Theme(
      data: buildSchoolTheme(widget.landing.primaryColor, widget.landing.secondaryColor),
      child: Scaffold(
        appBar: AppBar(title: Text(strings.mobileMoneyPayment)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_android_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(widget.paymentPurpose, style: Theme.of(context).textTheme.titleMedium),
                    Text('${widget.amount.toStringAsFixed(0)} FCFA',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: strings.mobileMoneyNumber, border: const OutlineInputBorder(), hintText: '6XXXXXXXX'),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 9) return strings.enterValidNumber;
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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

  Future<void> _generateReceipt(BuildContext context) async {
    final t = _transaction!;
    final doc = pw.Document();

    pw.MemoryImage? logo;
    if (widget.landing.logoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(widget.landing.logoUrl));
        if (res.statusCode == 200) logo = pw.MemoryImage(res.bodyBytes);
      } catch (_) {
        // Missing/unreachable logo should never block the receipt itself.
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) pw.Image(logo, width: 56, height: 56),
              pw.SizedBox(height: 10),
              pw.Text(widget.landing.schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (widget.landing.motto.isNotEmpty)
                pw.Text(widget.landing.motto, style:  pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 20),
              pw.Text('PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              _receiptRow('Student', widget.child?.fullName ?? '-'),
              _receiptRow('Payment purpose', widget.paymentPurpose),
              _receiptRow('Amount', '${widget.amount.toStringAsFixed(0)} FCFA'),
              _receiptRow('Transaction reference', t.transactionReference ?? '-'),
              _receiptRow('Date', t.createdAt.toString().split('.').first),
              _receiptRow('Status', 'PAID'),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Generated automatically by the school management system.',
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'receipt_${t.id}.pdf');
  }

  pw.Widget _receiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: const pw.TextStyle(fontSize: 10)), pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))],
      ),
    );
  }
}
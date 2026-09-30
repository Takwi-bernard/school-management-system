import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import '../parent/parent_fees.dart' show generateReceiptPdf;
import '../parent/parent_models.dart' show PaymentTransaction;
import 'secretary_models.dart';
import 'secretary_providers.dart';

String _money(double v) => '${v.toStringAsFixed(0)} FCFA';
String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ============================================================
// REGISTRATION FEES STILL OUTSTANDING
// ============================================================

class AwaitingRegistrationsPage extends ConsumerWidget {
  final String schoolId;
  final LandingModel landing;
  const AwaitingRegistrationsPage({super.key, required this.schoolId, required this.landing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(awaitingRegistrationsProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Awaiting Registration Payment', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(awaitingRegistrationsProvider(schoolId))),
        ]),
        const SizedBox(height: 6),
        Text('Children who were enrolled but whose registration fee has not been received yet. The Principal cannot see them until it is paid.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('Nothing is waiting for a registration payment.'));
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = items[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.childName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text('${r.className} · ${r.departmentName}', style: theme.textTheme.bodySmall),
                          Text('Parent: ${r.parentName}${r.parentPhone != null ? ' · ${r.parentPhone}' : ''}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                          Text('Enrolled ${_date(r.createdAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ]),
                      ),
                      if (r.fee == null)
                        const Text('No fee configured', style: TextStyle(fontStyle: FontStyle.italic))
                      else
                        FilledButton(
                          onPressed: () async {
                            final paid = await showDialog<bool>(
                              context: context,
                              builder: (_) => CollectPaymentDialog(
                                landing: landing,
                                kind: 'registration',
                                purpose: 'Registration Fee',
                                childName: r.childName,
                                amount: r.fee!,
                                admissionRequestId: r.id,
                              ),
                            );
                            if (paid == true) ref.invalidate(awaitingRegistrationsProvider(schoolId));
                          },
                          child: Text('Collect ${_money(r.fee!)}'),
                        ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// SCHOOL FEES - look a student up, collect an installment
// ============================================================

class CollectSchoolFeesPage extends ConsumerStatefulWidget {
  final LandingModel landing;
  const CollectSchoolFeesPage({super.key, required this.landing});

  @override
  ConsumerState<CollectSchoolFeesPage> createState() => _CollectSchoolFeesPageState();
}

class _CollectSchoolFeesPageState extends ConsumerState<CollectSchoolFeesPage> {
  final _controller = TextEditingController();
  List<StudentFeeLookup> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.length < 2) return;
    setState(() { _loading = true; _error = null; });
    try {
      final found = await ref.read(secretaryRepositoryProvider).lookupStudents(q);
      if (mounted) setState(() { _results = found; _searched = true; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Collect School Fees', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Search by admission number or name. The admission number shown here is what a parent can use to find their child.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Admission number or name', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: _loading ? null : _search, child: const Text('Search')),
        ]),
        const SizedBox(height: 14),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        Expanded(
          child: _searched && _results.isEmpty && !_loading
              ? const Center(child: Text('No student matches that search.'))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _studentTile(theme, _results[i]),
                ),
        ),
      ]),
    );
  }

  Widget _studentTile(ThemeData theme, StudentFeeLookup s) {
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${s.admissionNumber} · ${s.className}${s.departmentName.isEmpty ? '' : ' · ${s.departmentName}'}\n${_money(s.amountPaid)} of ${_money(s.totalFee)} paid'),
        children: [
          if (s.installments.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No fee plan found for this student\'s current class.'))
          else
            ...s.installments.map((inst) => ListTile(
                  leading: Icon(inst.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: inst.isPaid ? Colors.green : theme.colorScheme.outline),
                  title: Text(inst.name),
                  subtitle: Text('${_money(inst.amount)}${inst.dueDate != null ? ' · due ${_date(inst.dueDate!)}' : ''}'),
                  trailing: inst.isPaid
                      ? const Text('Paid', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700))
                      : FilledButton(
                          onPressed: () async {
                            final paid = await showDialog<bool>(
                              context: context,
                              builder: (_) => CollectPaymentDialog(
                                landing: widget.landing,
                                kind: 'installment',
                                purpose: inst.name,
                                childName: s.fullName,
                                amount: inst.amount,
                                studentId: s.studentId,
                                installmentId: inst.id,
                              ),
                            );
                            if (paid == true) _search();
                          },
                          child: const Text('Collect'),
                        ),
                )),
        ],
      ),
    );
  }
}

// ============================================================
// COLLECT A PAYMENT - cash / bank transfer / Mobile Money
// ============================================================

enum _PayMode { choose, momoPhone, waiting, done }

class CollectPaymentDialog extends ConsumerStatefulWidget {
  final LandingModel landing;
  final String kind; // 'registration' | 'installment'
  final String purpose;
  final String childName;
  final double amount;
  final String? admissionRequestId;
  final String? studentId;
  final String? installmentId;

  const CollectPaymentDialog({
    super.key,
    required this.landing,
    required this.kind,
    required this.purpose,
    required this.childName,
    required this.amount,
    this.admissionRequestId,
    this.studentId,
    this.installmentId,
  });

  @override
  ConsumerState<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends ConsumerState<CollectPaymentDialog> {
  _PayMode _mode = _PayMode.choose;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  final _phone = TextEditingController();
  RecordedPayment? _receipt;
  String _methodLabel = '';

  @override
  void dispose() {
    _disposed = true;
    _phone.dispose();
    super.dispose();
  }

  String _clean(Object e) => '$e'.replaceFirst('Exception: ', '');

  Future<void> _recordOffline(String method, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm payment received'),
        content: Text('Have you received ${_money(widget.amount)} by $label for ${widget.purpose} (${widget.childName})? This will be recorded and cannot be undone here.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, record it')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _busy = true; _error = null; });
    try {
      final receipt = await ref.read(secretaryRepositoryProvider).recordOfflinePayment(
            kind: widget.kind,
            admissionRequestId: widget.admissionRequestId,
            studentId: widget.studentId,
            installmentId: widget.installmentId,
            method: method,
          );
      if (!mounted) return;
      setState(() { _receipt = receipt; _methodLabel = label; _mode = _PayMode.done; });
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startMomo() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      setState(() => _error = 'Enter a valid Mobile Money number.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final repo = ref.read(secretaryRepositoryProvider);
    try {
      final ticket = await repo.initiateOnlinePayment(
        kind: widget.kind,
        admissionRequestId: widget.admissionRequestId,
        studentId: widget.studentId,
        installmentId: widget.installmentId,
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      setState(() { _mode = _PayMode.waiting; _busy = false; });
      await _poll(repo, ticket);
    } catch (e) {
      if (mounted) setState(() { _error = _clean(e); _busy = false; });
    }
  }

  Future<void> _poll(dynamic repo, OnlinePaymentTicket ticket) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (_disposed || !mounted) return;
      try {
        final t = await repo.verifyOnlinePayment(ticket.id) as OnlinePaymentTicket;
        if (_disposed || !mounted) return;
        if (t.status == 'success') {
          setState(() {
            _receipt = RecordedPayment(
              id: t.id,
              reference: t.reference ?? ticket.reference ?? '-',
              amount: widget.amount,
              purpose: widget.purpose,
              childName: widget.childName,
              createdAt: DateTime.now(),
            );
            _methodLabel = 'Mobile Money';
            _mode = _PayMode.done;
          });
          return;
        }
        if (t.status == 'failed') {
          setState(() { _mode = _PayMode.momoPhone; _error = 'The payment was declined or expired. Try again, or use another method.'; });
          return;
        }
      } catch (_) {
        // transient - keep polling
      }
    }
    if (mounted) {
      setState(() { _mode = _PayMode.momoPhone; _error = 'Still waiting for confirmation. It may still complete - check again shortly from the list.'; });
    }
  }

  Future<void> _downloadReceipt() async {
    final r = _receipt!;
    try {
      await generateReceiptPdf(
        isFrench: true,
        ref: ref,
        transaction: PaymentTransaction(
          id: r.id,
          status: 'success',
          amount: r.amount,
          paymentPurpose: r.purpose,
          childName: r.childName,
          transactionReference: r.reference,
          createdAt: r.createdAt,
        ),
        landing: widget.landing,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget header() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.purpose, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(widget.childName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 6),
          Text(_money(widget.amount), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
        ]);

    Widget errorText() => _error == null
        ? const SizedBox()
        : Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)));

    Widget option(IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _busy ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ])),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          ),
        );

    Widget content;
    List<Widget> actions;

    switch (_mode) {
      case _PayMode.choose:
        content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          header(),
          option(Icons.payments_outlined, 'Cash', 'Money received at the school office', () => _recordOffline('cash', 'cash')),
          option(Icons.account_balance_outlined, 'Bank transfer / deposit', 'Bank slip or transfer confirmed', () => _recordOffline('bank_transfer', 'bank transfer')),
          option(Icons.phone_android_rounded, 'Mobile Money', 'Send a payment request to the payer\'s phone', () => setState(() { _mode = _PayMode.momoPhone; _error = null; })),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          errorText(),
        ]);
        actions = [TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Not now'))];
        break;

      case _PayMode.momoPhone:
        content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          header(),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Payer\'s MTN / Orange Money number', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text('The payer will get a prompt on their phone and must enter their PIN.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          errorText(),
        ]);
        actions = [
          TextButton(onPressed: _busy ? null : () => setState(() { _mode = _PayMode.choose; _error = null; }), child: const Text('Back')),
          FilledButton(
            onPressed: _busy ? null : _startMomo,
            child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send request'),
          ),
        ];
        break;

      case _PayMode.waiting:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          header(),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Waiting for the payer to confirm on their phone...', textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('This updates automatically.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ]);
        actions = [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close (keeps waiting in the background)'))];
        break;

      case _PayMode.done:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          const SizedBox(height: 10),
          Text('Payment recorded', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${_money(widget.amount)} by $_methodLabel', textAlign: TextAlign.center),
          Text('Reference: ${_receipt?.reference ?? '-'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _downloadReceipt, icon: const Icon(Icons.receipt_long_rounded), label: const Text('Download receipt')),
        ]);
        actions = [FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done'))];
        break;
    }

    return AlertDialog(content: SizedBox(width: 420, child: SingleChildScrollView(child: content)), actions: actions);
  }
}
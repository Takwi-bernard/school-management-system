import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import '../parent/parent_fees.dart' show generateReceiptPdf;
import '../parent/parent_models.dart' show PaymentTransaction;
import 'secretary_enrollment.dart';
import 'secretary_flow_strings.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

String _clean(Object e) => '$e'.replaceFirst('Exception: ', '');

void _refreshSecretaryData(WidgetRef ref, String schoolId) {
  ref.invalidate(awaitingRegistrationsProvider(schoolId));
  ref.invalidate(secretaryDashboardProvider(schoolId));
  ref.invalidate(myPaymentsProvider(schoolId));
}

Widget _initialsAvatar(ThemeData theme, String name, {double radius = 22}) {
  final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
  return CircleAvatar(
    radius: radius,
    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
    child: Text(initial, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
  );
}

// ============================================================
// REGISTRATION FEES STILL OUTSTANDING
// ============================================================

class AwaitingRegistrationsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const AwaitingRegistrationsPage({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<AwaitingRegistrationsPage> createState() => _AwaitingRegistrationsPageState();
}

class _AwaitingRegistrationsPageState extends ConsumerState<AwaitingRegistrationsPage> {
  final _search = TextEditingController();
  String _query = '';

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _collect(AwaitingRegistration r) async {
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CollectPaymentDialog(
        landing: widget.landing,
        strings: _s,
        kind: 'registration',
        purpose: _s.fRegistrationFeePurpose,
        childName: r.childName,
        amount: r.fee!,
        admissionRequestId: r.id,
      ),
    );
    if (paid == true) _refreshSecretaryData(ref, widget.schoolId);
  }

  Future<void> _edit(AwaitingRegistration r) async {
    final themeData = Theme.of(context);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => Theme(
          data: themeData,
          child: Scaffold(
            appBar: AppBar(title: Text(_s.sEditEnrollmentTitle)),
            body: SafeArea(
              child: EnrollChildPage(
                schoolId: widget.schoolId,
                landing: widget.landing,
                strings: _s,
                editing: r,
                onFinished: (saved) => Navigator.of(routeContext).pop(saved),
              ),
            ),
          ),
        ),
      ),
    );
    if (changed == true) _refreshSecretaryData(ref, widget.schoolId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(awaitingRegistrationsProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecretaryPageHeader(
          title: _s.sAwaitingRegistration,
          subtitle: _s.sAwaitingRegistrationDescription,
          trailing: IconButton(
            tooltip: _s.fRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(awaitingRegistrationsProvider(widget.schoolId)),
          ),
        ),
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: _s.sSearchChildOrParentHint,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SecretaryErrorView(
              error: e,
              strings: _s,
              onRetry: () => ref.invalidate(awaitingRegistrationsProvider(widget.schoolId)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                  await ref.refresh(awaitingRegistrationsProvider(widget.schoolId).future);
                },
                  child: ListView(children: [
                    SizedBox(
                      height: 320,
                      child: SecretaryEmptyState(icon: Icons.hourglass_empty_rounded, title: _s.sNothingAwaitingMessage),
                    ),
                  ]),
                );
              }
              final filtered = _query.isEmpty
                  ? items
                  : items.where((r) {
                      return r.childName.toLowerCase().contains(_query) ||
                          r.parentName.toLowerCase().contains(_query) ||
                          (r.parentPhone ?? '').toLowerCase().contains(_query);
                    }).toList();
              if (filtered.isEmpty) {
                return SecretaryEmptyState(icon: Icons.search_off_rounded, title: _s.sNoSearchMatchesMessage);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  await ref.refresh(awaitingRegistrationsProvider(widget.schoolId).future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _tile(theme, filtered[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _tile(ThemeData theme, AwaitingRegistration r) {
    final hasFee = r.fee != null && r.fee! > 0;

    final info = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (r.photoUrl != null && r.photoUrl!.isNotEmpty)
        CircleAvatar(radius: 22, backgroundImage: NetworkImage(r.photoUrl!))
      else
        _initialsAvatar(theme, r.childName),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.childName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(r.departmentName.isEmpty ? r.className : '${r.className} · ${r.departmentName}', style: theme.textTheme.bodySmall),
          Text(_s.fParentLine(r.parentName, r.parentPhone), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          Text('${_s.sEnrolledOnLabel} ${formatDate(r.createdAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ]),
      ),
    ]);

    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(tooltip: _s.sEditTooltip, icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(r)),
      const SizedBox(width: 4),
      if (hasFee)
        FilledButton(onPressed: () => _collect(r), child: Text('${_s.sCollectAmountPrefix}${formatMoney(r.fee!)}'))
      else
        Flexible(
          child: Text(_s.sNoFeeConfiguredLabel, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.error)),
        ),
    ]);

    return SecretaryCard(
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            info,
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: actions),
          ]);
        }
        return Row(children: [Expanded(child: info), const SizedBox(width: 12), actions]);
      }),
    );
  }
}

// ============================================================
// SCHOOL FEES - look a student up, collect an installment
// ============================================================

class CollectSchoolFeesPage extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  final String? initialQuery;
  const CollectSchoolFeesPage({super.key, required this.landing, required this.strings, this.initialQuery});

  @override
  ConsumerState<CollectSchoolFeesPage> createState() => _CollectSchoolFeesPageState();
}

class _CollectSchoolFeesPageState extends ConsumerState<CollectSchoolFeesPage> {
  final _controller = TextEditingController();
  List<StudentFeeLookup> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _token = 0;
  Timer? _debounce;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.length >= 2) {
      _controller.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _token++;
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final q = _controller.text.trim();
    if (q.length < 2) return;
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await ref.read(secretaryRepositoryProvider).lookupStudents(q);
      if (!mounted || token != _token) return;
      setState(() {
        _results = found;
        _searched = true;
      });
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = _clean(e));
    } finally {
      if (mounted && token == _token) setState(() => _loading = false);
    }
  }

  Future<void> _collect(StudentFeeLookup s, InstallmentLookup inst) async {
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CollectPaymentDialog(
        landing: widget.landing,
        strings: _s,
        kind: 'installment',
        purpose: inst.name,
        childName: s.fullName,
        amount: inst.amount,
        studentId: s.studentId,
        installmentId: inst.id,
      ),
    );
    if (paid == true) {
      _refreshSecretaryData(ref, widget.landing.schoolId);
      if (mounted) _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_error != null) {
      body = SecretaryErrorView(error: _error!, strings: _s, onRetry: _search);
    } else if (!_searched && !_loading) {
      body = SecretaryEmptyState(icon: Icons.manage_search_rounded, title: _s.fSearchPrompt);
    } else if (_searched && _results.isEmpty && !_loading) {
      body = SecretaryEmptyState(icon: Icons.search_off_rounded, title: _s.sNoStudentMatchMessage);
    } else {
      body = ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _studentTile(theme, _results[i]),
      );
    }

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecretaryPageHeader(title: _s.sCollectFees, subtitle: _s.fFeesHelp),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _s.sSearchStudentHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: _loading ? null : _search, child: Text(_s.fSearch)),
        ]),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        const SizedBox(height: 4),
        Expanded(child: body),
      ]),
    );
  }

  Widget _studentTile(ThemeData theme, StudentFeeLookup s) {
    final sub = [
      s.admissionNumber,
      s.className,
      if (s.departmentName.isNotEmpty) s.departmentName,
    ].where((e) => e.isNotEmpty).join(' · ');
    final progress = s.totalFee > 0 ? (s.amountPaid / s.totalFee).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _results.length == 1,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _initialsAvatar(theme, s.fullName),
          title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sub, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 6)),
              const SizedBox(height: 4),
              Text('${formatMoney(s.amountPaid)} ${_s.sOfLabel} ${formatMoney(s.totalFee)} ${_s.sPaidWord}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ]),
          ),
          children: [
            if (s.installments.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(_s.sNoFeePlanMessage))
            else
              ...s.installments.map((inst) => ListTile(
                    leading: Icon(
                      inst.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: inst.isPaid ? Colors.green : theme.colorScheme.outline,
                    ),
                    title: Text(inst.name),
                    subtitle: Text('${formatMoney(inst.amount)}${inst.dueDate != null ? ' · ${_s.sDueOnLabel} ${formatDate(inst.dueDate!)}' : ''}'),
                    trailing: inst.isPaid
                        ? Text(_s.sPaidLabel, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700))
                        : FilledButton(onPressed: () => _collect(s, inst), child: Text(_s.sCollectLabel)),
                  )),
          ],
        ),
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
  final AppStrings strings;
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
    required this.strings,
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
  bool _receiptBusy = false;
  String? _error;
  final _phone = TextEditingController();
  RecordedPayment? _receipt;
  String _methodLabel = '';

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _disposed = true;
    _phone.dispose();
    super.dispose();
  }

  Future<void> _recordOffline(String method) async {
    final label = paymentMethodLabel(_s, method);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_s.sConfirmPaymentReceivedTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s.fConfirmReceivedBody(formatMoney(widget.amount), label, widget.purpose, widget.childName)),
          const SizedBox(height: 10),
          Text(_s.sCannotUndoHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_s.sNotYetLabel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_s.sYesRecordItLabel)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref.read(secretaryRepositoryProvider).recordOfflinePayment(
            kind: widget.kind,
            admissionRequestId: widget.admissionRequestId,
            studentId: widget.studentId,
            installmentId: widget.installmentId,
            method: method,
          );
      if (!mounted) return;
      _refreshSecretaryData(ref, widget.landing.schoolId);
      setState(() {
        _receipt = receipt;
        _methodLabel = label;
        _mode = _PayMode.done;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startMomo() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      setState(() => _error = _s.fInvalidMomoNumber);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
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
      setState(() {
        _mode = _PayMode.waiting;
        _busy = false;
      });
      await _poll(ticket);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _clean(e);
          _busy = false;
        });
      }
    }
  }

  Future<void> _poll(OnlinePaymentTicket ticket) async {
    final repo = ref.read(secretaryRepositoryProvider);
    final schoolId = widget.landing.schoolId;
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (_disposed || !mounted) return;
      try {
        final t = await repo.verifyOnlinePayment(ticket.id);
        if (_disposed || !mounted) return;
        if (t.status == 'success') {
          _refreshSecretaryData(ref, schoolId);
          setState(() {
            _receipt = RecordedPayment(
              id: t.id,
              reference: t.reference ?? ticket.reference ?? '-',
              amount: widget.amount,
              purpose: widget.purpose,
              childName: widget.childName,
              createdAt: DateTime.now(),
            );
            _methodLabel = _s.fMobileMoney;
            _mode = _PayMode.done;
          });
          return;
        }
        if (t.status == 'failed' || t.status == 'cancelled' || t.status == 'expired') {
          setState(() {
            _mode = _PayMode.momoPhone;
            _error = _s.fPaymentDeclined;
          });
          return;
        }
      } catch (_) {
        // Transient network/server hiccup - keep polling.
      }
    }
    if (mounted && !_disposed) {
      setState(() {
        _mode = _PayMode.momoPhone;
        _error = _s.fStillWaiting;
      });
    }
  }

  Future<void> _downloadReceipt() async {
    final r = _receipt;
    if (r == null || _receiptBusy) return;
    setState(() => _receiptBusy = true);
    try {
      await generateReceiptPdf(
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
        isFrench: _s.isFrench,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_clean(e))));
    } finally {
      if (mounted) setState(() => _receiptBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboard = ref.watch(secretaryDashboardProvider(widget.landing.schoolId));
    final momoReady = dashboard.maybeWhen(data: (d) => d.mobileMoneyConfigured, orElse: () => false);
    final momoKnownMissing = dashboard.maybeWhen(data: (d) => !d.mobileMoneyConfigured, orElse: () => false);

    Widget header() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.purpose, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(widget.childName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 6),
          Text(formatMoney(widget.amount), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
        ]);

    Widget errorText() => _error == null
        ? const SizedBox()
        : Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          );

    Widget option(IconData icon, String title, String subtitle, VoidCallback? onTap) {
      final enabled = onTap != null && !_busy;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ]),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    Widget content;
    List<Widget> actions;

    switch (_mode) {
      case _PayMode.choose:
        content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          header(),
          option(Icons.payments_outlined, _s.sCashLabel, _s.sCashSubtitle, () => _recordOffline('cash')),
          option(Icons.account_balance_outlined, _s.sBankTransferLabel, _s.sBankTransferSubtitle, () => _recordOffline('bank_transfer')),
          option(
            Icons.phone_android_rounded,
            _s.fMobileMoney,
            _s.sMobileMoneySubtitle,
            momoReady
                ? () => setState(() {
                      _mode = _PayMode.momoPhone;
                      _error = null;
                    })
                : null,
          ),
          if (momoKnownMissing)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(_s.sMobileMoneyUnavailableMessage, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          errorText(),
        ]);
        actions = [TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(_s.sNotNowLabel))];
        break;

      case _PayMode.momoPhone:
        content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          header(),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(labelText: _s.sPayerPhoneLabel, prefixIcon: const Icon(Icons.phone_outlined), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text(_s.sPayerPhoneHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          errorText(),
        ]);
        actions = [
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _mode = _PayMode.choose;
                      _error = null;
                    }),
            child: Text(_s.sBack),
          ),
          FilledButton(
            onPressed: _busy ? null : _startMomo,
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_s.sSendRequestLabel),
          ),
        ];
        break;

      case _PayMode.waiting:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          header(),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_s.sWaitingConfirmationMessage, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(_s.sUpdatesAutomaticallyMessage, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ]);
        actions = [
          TextButton(
            onPressed: () {
              _refreshSecretaryData(ref, widget.landing.schoolId);
              Navigator.pop(context, false);
            },
            child: Text(_s.sCloseKeepsWaitingLabel),
          ),
        ];
        break;

      case _PayMode.done:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          const SizedBox(height: 10),
          Text(_s.sPaymentRecordedTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_s.fPaymentByLine(formatMoney(widget.amount), _methodLabel), textAlign: TextAlign.center),
          Text('${_s.sReferenceLabel}: ${_receipt?.reference ?? '-'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _receiptBusy ? null : _downloadReceipt,
            icon: _receiptBusy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long_rounded),
            label: Text(_s.fDownloadReceipt),
          ),
        ]);
        actions = [FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_s.fDone))];
        break;
    }

    final width = math.min(420.0, MediaQuery.of(context).size.width - 80);
    return PopScope(
      canPop: _mode != _PayMode.done,
      onPopInvokedWithResult: (didPop, _) {
        // Swallowing back/escape on the receipt screen would trap the
        // user; instead, closing it any other way still reports success.
        if (!didPop && _mode == _PayMode.done) Navigator.pop(context, true);
      },
      child: AlertDialog(
        content: SizedBox(width: width, child: SingleChildScrollView(child: content)),
        actions: actions,
      ),
    );
  }
}
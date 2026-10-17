import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import '../parent/parent_fees.dart' show generateReceiptPdf;
import '../parent/parent_models.dart' show PaymentTransaction;
import '../principal/principal_core.dart';
import '../principal/principal_kit.dart';
import '../proprietor/proprietor_ui.dart';
import 'secretary_enrollment.dart';
import 'secretary_flow_strings.dart';
import 'secretary_format.dart';
import 'secretary_models.dart';
import 'secretary_providers.dart';
import 'secretary_strings.dart';
import 'secretary_ui.dart';

void _refreshSecretaryData(WidgetRef ref, String schoolId) {
  ref.invalidate(awaitingRegistrationsProvider(schoolId));
  ref.invalidate(secretaryDashboardProvider(schoolId));
  ref.invalidate(myPaymentsProvider(schoolId));
}

/// Opens the payment sheet. Resolves to true when a payment was recorded.
/// It cannot be swiped away by accident while a payment is in flight.
Future<bool?> showCollectPayment(
  BuildContext context, {
  required LandingModel landing,
  required AppStrings strings,
  required String kind,
  required String purpose,
  required String childName,
  required double amount,
  String? admissionRequestId,
  String? studentId,
  String? installmentId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => CollectPaymentSheet(
      landing: landing,
      strings: strings,
      kind: kind,
      purpose: purpose,
      childName: childName,
      amount: amount,
      admissionRequestId: admissionRequestId,
      studentId: studentId,
      installmentId: installmentId,
    ),
  );
}

// ============================================================ awaiting

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
    final paid = await showCollectPayment(
      context,
      landing: widget.landing,
      strings: _s,
      kind: 'registration',
      purpose: _s.fRegistrationFeePurpose,
      childName: r.childName,
      amount: r.fee!,
      admissionRequestId: r.id,
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
            appBar: AppBar(
              backgroundColor: themeData.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: Text(_s.sEditEnrollmentTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
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
    final cs = theme.colorScheme;
    final async = ref.watch(awaitingRegistrationsProvider(widget.schoolId));

    Future<void> refresh() async {
      ref.invalidate(awaitingRegistrationsProvider(widget.schoolId));
      try {
        await ref.read(awaitingRegistrationsProvider(widget.schoolId).future);
      } catch (_) {}
    }

    return PrPage(
      onRefresh: refresh,
      children: [
        PrHeader(
          title: _s.sAwaitingRegistration,
          subtitle: _s.sAwaitingRegistrationDescription,
          trailing: async.valueOrNull == null || async.valueOrNull!.isEmpty
              ? null
              : PnChip(label: '${async.valueOrNull!.length}', color: pnWarn(), icon: Icons.hourglass_top_rounded),
        ),
        PnSearch(
          controller: _search,
          hint: _s.sSearchChildOrParentHint,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 16),
        SxAsync<List<AwaitingRegistration>>(
          value: async,
          strings: _s,
          onRetry: () => ref.invalidate(awaitingRegistrationsProvider(widget.schoolId)),
          isEmpty: (l) => l.isEmpty,
          empty: SxEmpty(icon: Icons.task_alt_rounded, title: _s.sNothingAwaitingMessage),
          builder: (items) {
            final filtered = _query.isEmpty
                ? items
                : items.where((r) {
                    return r.childName.toLowerCase().contains(_query) ||
                        r.parentName.toLowerCase().contains(_query) ||
                        (r.parentPhone ?? '').toLowerCase().contains(_query);
                  }).toList();
            if (filtered.isEmpty) return PrCard(child: SxEmpty(icon: Icons.search_off_rounded, title: _s.sNoSearchMatchesMessage));
            return LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 920 ? 2 : 1;
              const gap = 12.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, children: [
                for (var i = 0; i < filtered.length; i++) SizedBox(width: w, child: _tile(theme, cs, filtered[i], i)),
              ]);
            });
          },
        ),
      ],
    );
  }

  Widget _tile(ThemeData theme, ColorScheme cs, AwaitingRegistration r, int i) {
    final hasFee = r.fee != null && r.fee! > 0;
    return SxRow(
      index: i < 10 ? i : 0,
      leading: PnAvatar(stored: r.photoUrl, name: r.childName, radius: 24),
      title: r.childName,
      lines: [
        r.departmentName.isEmpty ? r.className : '${r.className} · ${r.departmentName}',
        _s.fParentLine(r.parentName, r.parentPhone),
        '${_s.sEnrolledOnLabel} ${formatDate(r.createdAt)}',
      ],
      trailing: IconButton.filledTonal(tooltip: _s.sEditTooltip, icon: const Icon(Icons.edit_rounded, size: 18), onPressed: () => _edit(r)),
      bottom: hasFee
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => _collect(r),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: Text('${_s.sCollectAmountPrefix}${formatMoney(r.fee!)}'),
              ),
            )
          : PnNotice(text: _s.sNoFeeConfiguredLabel, icon: Icons.warning_amber_rounded, color: pnWarn()),
    );
  }
}

// ============================================================ school fees

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
  Object? _error;
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
    setState(() {});
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
      if (mounted && token == _token) setState(() => _error = e);
    } finally {
      if (mounted && token == _token) setState(() => _loading = false);
    }
  }

  Future<void> _collect(StudentFeeLookup s, InstallmentLookup inst) async {
    final paid = await showCollectPayment(
      context,
      landing: widget.landing,
      strings: _s,
      kind: 'installment',
      purpose: inst.name,
      childName: s.fullName,
      amount: inst.amount,
      studentId: s.studentId,
      installmentId: inst.id,
    );
    if (paid == true) {
      _refreshSecretaryData(ref, widget.landing.schoolId);
      if (mounted) _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = SxError(error: _error!, strings: _s, onRetry: _search);
    } else if (_loading && _results.isEmpty) {
      body = const SxSkeletonList(rows: 3, height: 116);
    } else if (!_searched) {
      body = PrCard(child: SxEmpty(icon: Icons.manage_search_rounded, title: _s.fSearchPrompt, text: _s.fMinCharsHint));
    } else if (_results.isEmpty) {
      body = PrCard(child: SxEmpty(icon: Icons.search_off_rounded, title: _s.sNoStudentMatchMessage));
    } else {
      body = Column(children: [
        for (var i = 0; i < _results.length; i++)
          PrReveal(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StudentFeeCard(key: ValueKey(_results[i].studentId), data: _results[i], strings: _s, initiallyOpen: _results.length == 1, onCollect: _collect),
            ),
          ),
      ]);
    }

    return PrPage(
      maxWidth: 900,
      children: [
        PrHeader(title: _s.sCollectFees, subtitle: _s.fFeesHelp),
        Row(children: [
          Expanded(child: PnSearch(controller: _controller, hint: _s.sSearchStudentHint, onChanged: _onChanged)),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _loading ? null : _search,
              child: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ]),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _loading && _results.isNotEmpty ? 14 : 0,
          padding: const EdgeInsets.only(top: 8),
          child: _loading && _results.isNotEmpty ? const LinearProgressIndicator(minHeight: 3) : null,
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }
}

class _StudentFeeCard extends StatefulWidget {
  final StudentFeeLookup data;
  final AppStrings strings;
  final bool initiallyOpen;
  final Future<void> Function(StudentFeeLookup, InstallmentLookup) onCollect;
  const _StudentFeeCard({super.key, required this.data, required this.strings, required this.initiallyOpen, required this.onCollect});

  @override
  State<_StudentFeeCard> createState() => _StudentFeeCardState();
}

class _StudentFeeCardState extends State<_StudentFeeCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = widget.data;
    final str = widget.strings;
    final sub = [s.admissionNumber, s.className, if (s.departmentName.isNotEmpty) s.departmentName].where((e) => e.isNotEmpty).join(' · ');
    final progress = s.totalFee > 0 ? (s.amountPaid / s.totalFee).clamp(0.0, 1.0).toDouble() : 0.0;
    final settled = s.totalFee > 0 && s.amountPaid >= s.totalFee;

    return PrCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PnAvatar(stored: null, name: s.fullName, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                  ]),
                ),
                if (settled) PnChip(label: str.sPaidLabel, color: pnGood(), icon: Icons.check_rounded),
                const SizedBox(width: 6),
                AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 220), child: Icon(Icons.expand_more_rounded, color: cs.outline)),
              ]),
              const SizedBox(height: 14),
              PrProgressBar(value: progress, color: settled ? pnGood() : null),
              const SizedBox(height: 6),
              Text('${formatMoney(s.amountPaid)} ${str.sOfLabel} ${formatMoney(s.totalFee)} ${str.sPaidWord}',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Column(children: [
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
                  if (s.installments.isEmpty)
                    Padding(padding: const EdgeInsets.all(18), child: Text(str.sNoFeePlanMessage, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)))
                  else
                    for (final inst in s.installments)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(children: [
                          Icon(inst.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: inst.isPaid ? pnGood() : cs.outline, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(inst.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                              Text(
                                '${formatMoney(inst.amount)}${inst.dueDate != null ? ' · ${str.sDueOnLabel} ${formatDate(inst.dueDate!)}' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                              ),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          if (inst.isPaid)
                            Text(str.sPaidLabel, style: TextStyle(color: pnGood(), fontWeight: FontWeight.w800, fontSize: 13))
                          else
                            FilledButton(
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () => widget.onCollect(s, inst),
                              child: Text(str.sCollectLabel),
                            ),
                        ]),
                      ),
                ]),
        ),
      ]),
    );
  }
}

// ============================================================ payment sheet

enum _PayMode { choose, momoPhone, waiting, done }

class CollectPaymentSheet extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  final String kind; // 'registration' | 'installment'
  final String purpose;
  final String childName;
  final double amount;
  final String? admissionRequestId;
  final String? studentId;
  final String? installmentId;

  const CollectPaymentSheet({
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
  ConsumerState<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends ConsumerState<CollectPaymentSheet> {
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
    final confirmed = await pnConfirm(
      context,
      _s,
      title: _s.sConfirmPaymentReceivedTitle,
      message: '${_s.fConfirmReceivedBody(formatMoney(widget.amount), label, widget.purpose, widget.childName)}\n\n${_s.sCannotUndoHint}',
      confirmLabel: _s.sYesRecordItLabel,
    );
    if (!confirmed || !mounted) return;

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
      if (mounted) setState(() => _error = sxMessage(e));
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
          _error = sxMessage(e);
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
      if (mounted) prSnack(context, sxMessage(e));
    } finally {
      if (mounted) setState(() => _receiptBusy = false);
    }
  }

  Widget _summary(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, Color.lerp(cs.primary, cs.inverseSurface, 0.45) ?? cs.primary]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.purpose, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(widget.childName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.7), fontSize: 12.5)),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatMoney(widget.amount), style: TextStyle(color: cs.onPrimary, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
        ),
      ]),
    );
  }

  Widget _errorBox() => _error == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 12), child: PnNotice(text: _error!, icon: Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dashboard = ref.watch(secretaryDashboardProvider(widget.landing.schoolId));
    final momoReady = dashboard.maybeWhen(data: (d) => d.mobileMoneyConfigured, orElse: () => false);
    final momoKnownMissing = dashboard.maybeWhen(data: (d) => !d.mobileMoneyConfigured, orElse: () => false);

    Widget step;
    switch (_mode) {
      case _PayMode.choose:
        step = Column(key: const ValueKey('choose'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SxOptionTile(icon: Icons.payments_rounded, title: _s.sCashLabel, subtitle: _s.sCashSubtitle, onTap: _busy ? null : () => _recordOffline('cash')),
          const SizedBox(height: 10),
          SxOptionTile(icon: Icons.account_balance_rounded, title: _s.sBankTransferLabel, subtitle: _s.sBankTransferSubtitle, onTap: _busy ? null : () => _recordOffline('bank_transfer')),
          const SizedBox(height: 10),
          SxOptionTile(
            icon: Icons.smartphone_rounded,
            title: _s.fMobileMoney,
            subtitle: _s.sMobileMoneySubtitle,
            enabled: momoReady,
            onTap: _busy || !momoReady
                ? null
                : () => setState(() {
                      _mode = _PayMode.momoPhone;
                      _error = null;
                    }),
          ),
          if (momoKnownMissing)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(_s.sMobileMoneyUnavailableMessage, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4))),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator(minHeight: 3)),
          _errorBox(),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(_s.sNotNowLabel))),
        ]);
        break;

      case _PayMode.momoPhone:
        step = Column(key: const ValueKey('momo'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: pnDeco(_s.sPayerPhoneLabel, icon: Icons.phone_outlined),
          ),
          const SizedBox(height: 8),
          Text(_s.sPayerPhoneHelp, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4)),
          _errorBox(),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _mode = _PayMode.choose;
                        _error = null;
                      }),
              child: Text(_s.sBack),
            ),
            FilledButton(onPressed: _busy ? null : _startMomo, child: PnBusyLabel(busy: _busy, label: _s.sSendRequestLabel)),
          ]),
        ]);
        break;

      case _PayMode.waiting:
        step = Column(key: const ValueKey('wait'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(alignment: Alignment.center, children: [
                const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 3)),
                Icon(Icons.smartphone_rounded, color: cs.primary, size: 26),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text(_s.sWaitingConfirmationMessage, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_s.sUpdatesAutomaticallyMessage, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _refreshSecretaryData(ref, widget.landing.schoolId);
                Navigator.pop(context, false);
              },
              child: Text(_s.sCloseKeepsWaitingLabel),
            ),
          ),
        ]);
        break;

      case _PayMode.done:
        step = Column(key: const ValueKey('done'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: SxSuccessBadge()),
          const SizedBox(height: 12),
          Text(_s.sPaymentRecordedTitle, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          PrCard(
            color: cs.surface,
            child: Column(children: [
              SxKeyValue(label: widget.purpose, value: formatMoney(widget.amount), strong: true),
              const Divider(height: 8),
              SxKeyValue(label: _s.fMobileMoney == _methodLabel ? _s.fMobileMoney : _methodLabel, value: widget.childName),
              SxKeyValue(label: _s.sReferenceLabel, value: _receipt?.reference ?? '-'),
            ]),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _receiptBusy ? null : _downloadReceipt,
            icon: _receiptBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.receipt_long_rounded),
            label: Text(_s.fDownloadReceipt),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_s.fDone),
          ),
        ]);
        break;
    }

    return PopScope(
      canPop: _mode != _PayMode.done && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode == _PayMode.done) Navigator.pop(context, true);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_mode != _PayMode.done) ...[_summary(theme), const SizedBox(height: 16)],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child)),
              child: step,
            ),
          ]),
        ),
      ),
    );
  }
}

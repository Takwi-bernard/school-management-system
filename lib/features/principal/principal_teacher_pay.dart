import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

const _kMethods = ['cash', 'bank_transfer', 'mtn_momo', 'orange_money'];
const _kKinds = ['salary', 'bonus', 'advance', 'allowance', 'other'];

String _kindLabel(AppStrings s, String k) {
  switch (k) {
    case 'salary':
      return s.pn('Salary', 'Salaire');
    case 'bonus':
      return s.pn('Bonus', 'Prime');
    case 'advance':
      return s.pn('Advance', 'Avance');
    case 'allowance':
      return s.pn('Allowance', 'Indemnité');
    default:
      return s.pn('Other', 'Autre');
  }
}

String _payTypeLabel(AppStrings s, String t) {
  switch (t) {
    case 'monthly':
      return s.pn('Fixed monthly', 'Mensuel fixe');
    case 'hourly':
      return s.pn('Per hour', 'À l\'heure');
    default:
      return s.pn('Case by case', 'Au cas par cas');
  }
}

/// Teacher payments: each teacher can be paid in the way the principal
/// agrees with them. Every payment records why, to whom, when and where,
/// and feeds the proprietor's expenses.
class PrincipalTeacherPayPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalTeacherPayPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalTeacherPayPage> createState() => _PrincipalTeacherPayPageState();
}

class _PrincipalTeacherPayPageState extends ConsumerState<PrincipalTeacherPayPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final List<PnTeacherPayment> _history = [];
  int _historyTotal = 0;
  bool _historyLoading = true;
  bool _historyMore = false;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory(reset: true));
  }

  Future<void> _loadHistory({required bool reset}) async {
    if (reset) {
      if (_history.isEmpty) setState(() => _historyLoading = true);
    } else {
      setState(() => _historyMore = true);
    }
    try {
      final res = await ref.read(principalHubRepositoryProvider).getTeacherPayments(limit: 30, offset: reset ? 0 : _history.length);
      if (!mounted) return;
      setState(() {
        if (reset) _history.clear();
        _history.addAll(res.rows);
        _historyTotal = res.total;
        _historyLoading = false;
        _historyMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _historyLoading = false;
          _historyMore = false;
        });
      }
    }
  }

  void _refreshAll() {
    ref.invalidate(pnTeacherPayProvider);
    ref.invalidate(pnOverviewProvider);
    _loadHistory(reset: true);
  }

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  Future<void> _pay(PnTeacherPay t, String yearId) async {
    final s = _s;
    final flagged = await pnSheet<bool>(
      context,
      (_) => _PaySheet(strings: s, teacher: t, yearId: yearId, month: _month),
    );
    if (flagged == null || !mounted) return;
    _refreshAll();
    prSnack(
      context,
      flagged
          ? s.pn('Payment recorded. It is above the approval amount, so the proprietor was alerted.', 'Paiement enregistré. Il dépasse le montant d\'alerte : le promoteur a été prévenu.')
          : s.pn('Payment recorded.', 'Paiement enregistré.'),
    );
  }

  Future<void> _profile(PnTeacherPay t) async {
    final saved = await pnSheet<bool>(context, (_) => _ProfileSheet(strings: _s, schoolId: widget.schoolId, teacher: t));
    if (saved == true && mounted) {
      ref.invalidate(pnTeacherPayProvider);
      prSnack(context, _s.pn('Pay terms saved.', 'Conditions de paiement enregistrées.'));
    }
  }

  Future<void> _void(PnTeacherPayment p) async {
    final s = _s;
    final reason = await pnSheet<String>(context, (_) => _VoidSheet(strings: s, payment: p));
    if (reason == null || !mounted) return;
    try {
      await ref.read(principalHubRepositoryProvider).voidTeacherPayment(p.id, reason);
      _refreshAll();
      if (mounted) prSnack(context, s.pn('Payment cancelled. The expense was removed too.', 'Paiement annulé. La dépense a aussi été retirée.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final calendar = ref.watch(pnCalendarProvider);

    ref.listen<int>(pnTickProvider, (_, __) => _loadHistory(reset: true));

    return calendar.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnCalendarProvider)),
      data: (years) {
        if (years.isEmpty) {
          return PrPage(children: [
            PrHeader(title: s.pn('Teacher payments', 'Paiements des enseignants'), subtitle: ''),
            SizedBox(height: 300, child: PrEmpty(icon: Icons.event_busy_rounded, title: s.pn('No academic year yet', 'Aucune année scolaire'), description: s.pn('Create an academic year first.', 'Créez d\'abord une année scolaire.'))),
          ]);
        }
        final year = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
        final key = (yearId: year.id, year: _month.year, month: _month.month);
        final async = ref.watch(pnTeacherPayProvider(key));

        return PrPage(
          onRefresh: () async => _refreshAll(),
          children: [
            PrHeader(
              title: s.pn('Teacher payments', 'Paiements des enseignants'),
              subtitle: s.pn('Pay each teacher the way you agreed. Every payment is recorded and appears in the proprietor\'s expenses.', 'Payez chaque enseignant selon votre accord. Chaque paiement est enregistré et apparaît dans les dépenses du promoteur.'),
            ),
            _monthBar(),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SizedBox(height: 260, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnTeacherPayProvider(key)))),
              data: (list) => _teachers(list, year.id),
            ),
            const SizedBox(height: 24),
            _historyPanel(),
          ],
        );
      },
    );
  }

  Widget _monthBar() {
    final s = _s;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isNow = _month.year == now.year && _month.month == now.month;
    return PrCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Center(
            child: Text(pMonthLong(s, _month), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ),
        ),
        if (!isNow) TextButton(onPressed: () => setState(() => _month = DateTime(now.year, now.month, 1)), child: Text(s.pn('This month', 'Ce mois'))),
        IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
  }

  Widget _teachers(List<PnTeacherPay> list, String yearId) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (list.isEmpty) {
      return SizedBox(height: 260, child: PrEmpty(icon: Icons.badge_outlined, title: s.pn('No teachers yet', 'Aucun enseignant'), description: s.pn('Approved teachers appear here.', 'Les enseignants approuvés apparaissent ici.')));
    }

    final expected = list.fold<double>(0, (a, t) => a + t.expected);
    final paid = list.fold<double>(0, (a, t) => a + t.paidMonth);
    final balance = list.fold<double>(0, (a, t) => a + t.balance);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PrGrid(minTile: 180, max: 3, children: [
        PrStatTile(icon: Icons.event_note_outlined, label: s.pn('Expected this month', 'Attendu ce mois'), value: expected, format: pMoney),
        PrStatTile(icon: Icons.payments_outlined, label: s.pn('Paid this month', 'Payé ce mois'), value: paid, format: pMoney),
        PrStatTile(icon: Icons.account_balance_wallet_outlined, label: s.pn('Still to pay', 'Reste à payer'), value: balance, format: pMoney),
      ]),
      const SizedBox(height: 16),
      for (var i = 0; i < list.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PrReveal(
            index: i < 8 ? i : 8,
            child: PrCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  PrAvatar(photoUrl: list[i].photo, name: list[i].name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(list[i].name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        PnChip(label: _payTypeLabel(s, list[i].payType), color: list[i].hasProfile ? cs.primary : null),
                        if (list[i].payType == 'monthly') PnChip(label: pMoney(list[i].monthlyAmount)),
                        if (list[i].payType == 'hourly') PnChip(label: '${pMoney(list[i].hourlyRate)} / ${s.pn('hour', 'heure')} · ${list[i].weeklyPeriods} ${s.pn('periods/wk', 'périodes/sem.')}'),
                      ]),
                    ]),
                  ),
                  IconButton(tooltip: s.pn('Pay terms', 'Conditions de paiement'), onPressed: () => _profile(list[i]), icon: const Icon(Icons.tune_rounded)),
                ]),
                const SizedBox(height: 12),
                if (list[i].hasProfile) ...[
                  PrProgressBar(value: list[i].expected <= 0 ? 0 : list[i].paidMonth / list[i].expected, height: 6, color: list[i].balance <= 0 ? pnGood() : cs.primary),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  Expanded(
                    child: Text(
                      list[i].hasProfile
                          ? '${s.pn('Paid', 'Payé')} ${pMoney(list[i].paidMonth)} ${s.pn('of', 'sur')} ${pMoney(list[i].expected)}'
                          : '${s.pn('Paid this month', 'Payé ce mois')}: ${pMoney(list[i].paidMonth)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ),
                  if (list[i].paidOtherMonth > 0) Text('${pMoney(list[i].paidOtherMonth)} ${s.pn('other', 'autres')}', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                ]),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _pay(list[i], yearId),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: Text(list[i].balance > 0 ? '${s.pn('Pay', 'Payer')} ${pMoney(list[i].balance)}' : s.pn('Record a payment', 'Enregistrer un paiement')),
                  ),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _historyPanel() {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PnPanel(
      title: s.pn('Payment history', 'Historique des paiements'),
      subtitle: s.pn('Newest first. A cancelled payment is kept with its reason.', 'Les plus récents d\'abord. Un paiement annulé est conservé avec son motif.'),
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: _historyLoading
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : _history.isEmpty
              ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(s.pn('No payments recorded yet.', 'Aucun paiement enregistré.'), style: TextStyle(color: cs.outline))))
              : Column(children: [
                  for (final p in _history) ...[
                    Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(p.teacher, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, decoration: p.isVoided ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              PnChip(label: _kindLabel(s, p.kind), color: cs.primary),
                              PnChip(label: pMethodLabel(s, p.method)),
                              if (p.needsReview && !p.isVoided) PnChip(label: s.pn('Flagged to proprietor', 'Signalé au promoteur'), color: pnWarn(), icon: Icons.flag_rounded),
                              if (p.isVoided) PnChip(label: s.pn('Cancelled', 'Annulé'), color: pnBad()),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (p.paidAt != null) pDateTime(p.paidAt!),
                                if (p.paidTo != null) '${s.pn('to', 'à')} ${p.paidTo}',
                                if (p.place != null) p.place!,
                                if (p.reference != null) '${s.pn('ref.', 'réf.')} ${p.reference}',
                              ].join('  ·  '),
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.35),
                            ),
                            if (p.purpose != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(p.purpose!, style: theme.textTheme.bodySmall?.copyWith(height: 1.35))),
                            if (p.isVoided && p.voidReason != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('${s.pn('Reason', 'Motif')}: ${p.voidReason}', style: theme.textTheme.bodySmall?.copyWith(color: pnBad()))),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(pMoney(p.amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, decoration: p.isVoided ? TextDecoration.lineThrough : null)),
                          if (!p.isVoided) TextButton(onPressed: () => _void(p), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(s.pn('Cancel', 'Annuler'))),
                        ]),
                      ]),
                    ),
                  ],
                  if (_history.length < _historyTotal)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _historyMore
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                          : TextButton(onPressed: () => _loadHistory(reset: false), child: Text(s.pn('Show more (${_history.length} of $_historyTotal)', 'Afficher plus (${_history.length} sur $_historyTotal)'))),
                    ),
                ]),
    );
  }
}

// ============================================================ record payment

class _PaySheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final PnTeacherPay teacher;
  final String yearId;
  final DateTime month;
  const _PaySheet({required this.strings, required this.teacher, required this.yearId, required this.month});

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  String _kind = 'salary';
  String _method = 'cash';
  late final TextEditingController _amount = TextEditingController(text: widget.teacher.balance > 0 ? widget.teacher.balance.round().toString() : '');
  final _purpose = TextEditingController();
  late final TextEditingController _paidTo = TextEditingController(text: widget.teacher.name);
  final _place = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _when = DateTime.now();
  bool _busy = false;
  String? _error;

  AppStrings get _s => widget.strings;
  bool get _mobile => _method == 'mtn_momo' || _method == 'orange_money';

  @override
  void dispose() {
    _amount.dispose();
    _purpose.dispose();
    _paidTo.dispose();
    _place.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final d = await pnPickDate(context, _when, first: DateTime(DateTime.now().year - 1), last: DateTime.now().add(const Duration(days: 1)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (!mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute));
  }

  Future<void> _save() async {
    final s = _s;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.').replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = pnErr(s, 'amount_invalid'));
      return;
    }
    if (!_mobile) {
      if (_purpose.text.trim().length < 3) {
        setState(() => _error = pnErr(s, 'purpose_required'));
        return;
      }
      if (_paidTo.text.trim().isEmpty) {
        setState(() => _error = pnErr(s, 'paid_to_required'));
        return;
      }
      if (_place.text.trim().isEmpty) {
        setState(() => _error = pnErr(s, 'place_required'));
        return;
      }
      if (_method == 'bank_transfer' && _reference.text.trim().isEmpty) {
        setState(() => _error = pnErr(s, 'reference_required'));
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flagged = await ref.read(principalHubRepositoryProvider).recordTeacherPayment(
            teacherId: widget.teacher.teacherId,
            amount: amount,
            method: _method,
            kind: _kind,
            periodMonth: widget.month,
            purpose: _purpose.text,
            paidTo: _paidTo.text,
            paidAt: _when,
            place: _place.text,
            reference: _reference.text,
            notes: _notes.text,
            yearId: widget.yearId,
          );
      if (mounted) Navigator.pop(context, flagged);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = pnErr(s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    return PnSheetBody(
      title: s.pn('Pay ${widget.teacher.name}', 'Payer ${widget.teacher.name}'),
      subtitle: pMonthLong(s, widget.month),
      children: [
        PrPills<String>(values: _kKinds, selected: _kind, label: (k) => _kindLabel(s, k), onChanged: (v) => setState(() => _kind = v)),
        const SizedBox(height: 16),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: pnDeco(s.pn('Amount', 'Montant'), suffix: 'FCFA', icon: Icons.payments_outlined),
        ),
        const SizedBox(height: 16),
        Text(s.pn('How was it paid?', 'Comment a-t-il été payé ?'), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<String>(values: _kMethods, selected: _method, label: (m) => pMethodLabel(s, m), onChanged: (v) => setState(() => _method = v)),
        const SizedBox(height: 14),
        if (_mobile)
          PnNotice(
            icon: Icons.phone_android_rounded,
            text: s.pn(
              'Mobile money is record-only for now: the system does not send the money. Send it from your own phone first, then record it here so it counts as an expense.',
              'Le mobile money est pour l\'instant en simple enregistrement : le système n\'envoie pas l\'argent. Envoyez-le d\'abord depuis votre téléphone, puis enregistrez-le ici pour qu\'il compte comme dépense.',
            ),
          )
        else
          PnNotice(
            icon: Icons.fact_check_outlined,
            text: s.pn('For ${pMethodLabel(s, _method).toLowerCase()}, tell us why, who received it, and where it was handed over.', 'Pour ${pMethodLabel(s, _method).toLowerCase()}, indiquez pourquoi, qui l\'a reçu et où il a été remis.'),
          ),
        const SizedBox(height: 14),
        TextField(controller: _purpose, decoration: pnDeco(_mobile ? s.pn('Reason (optional)', 'Motif (facultatif)') : s.pn('Reason for this payment', 'Motif de ce paiement'), hint: s.pn('e.g. March salary', 'ex. salaire de mars'))),
        const SizedBox(height: 12),
        TextField(controller: _paidTo, decoration: pnDeco(_mobile ? s.pn('Received by (optional)', 'Reçu par (facultatif)') : s.pn('Received by', 'Reçu par'), icon: Icons.person_outline_rounded)),
        if (!_mobile) ...[
          const SizedBox(height: 12),
          TextField(controller: _place, decoration: pnDeco(s.pn('Place', 'Lieu'), hint: s.pn('e.g. Principal\'s office', 'ex. bureau du Directeur'), icon: Icons.place_outlined)),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          decoration: pnDeco(
            _method == 'bank_transfer' ? s.pn('Bank transfer reference', 'Référence du virement') : (_mobile ? s.pn('Transaction ID (optional)', 'ID de transaction (facultatif)') : s.pn('Receipt number (optional)', 'N° de reçu (facultatif)')),
            icon: Icons.tag_rounded,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickWhen,
          child: InputDecorator(
            decoration: pnDeco(s.pn('Date and time', 'Date et heure'), icon: Icons.schedule_rounded),
            child: Text(pDateTime(_when)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _notes, maxLines: 2, decoration: pnDeco(s.pn('Notes (optional)', 'Notes (facultatif)'))),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Record payment', 'Enregistrer le paiement'))),
      ],
    );
  }
}

// ============================================================ pay terms

class _ProfileSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final String schoolId;
  final PnTeacherPay teacher;
  const _ProfileSheet({required this.strings, required this.schoolId, required this.teacher});

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late String _type = widget.teacher.payType;
  late final TextEditingController _monthly = TextEditingController(text: widget.teacher.monthlyAmount > 0 ? widget.teacher.monthlyAmount.round().toString() : '');
  late final TextEditingController _hourly = TextEditingController(text: widget.teacher.hourlyRate > 0 ? widget.teacher.hourlyRate.round().toString() : '');
  late final TextEditingController _weeks = TextEditingController(text: widget.teacher.weeksPerMonth.toString().replaceAll(RegExp(r'\.0$'), ''));
  late final TextEditingController _notes = TextEditingController(text: widget.teacher.notes ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _monthly.dispose();
    _hourly.dispose();
    _weeks.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

  Future<void> _save() async {
    final s = widget.strings;
    if (_type == 'monthly' && _n(_monthly) <= 0) {
      setState(() => _error = pnErr(s, 'amount_invalid'));
      return;
    }
    if (_type == 'hourly' && (_n(_hourly) <= 0 || _n(_weeks) <= 0)) {
      setState(() => _error = pnErr(s, 'amount_invalid'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(principalHubRepositoryProvider).saveTeacherPayProfile(
            schoolId: widget.schoolId,
            teacherId: widget.teacher.teacherId,
            payType: _type,
            monthlyAmount: _type == 'monthly' ? _n(_monthly) : 0,
            hourlyRate: _type == 'hourly' ? _n(_hourly) : 0,
            weeksPerMonth: _n(_weeks) <= 0 ? 4 : _n(_weeks),
            notes: _notes.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = pnErr(s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final theme = Theme.of(context);
    return PnSheetBody(
      title: widget.teacher.name,
      subtitle: s.pn('How do you pay this teacher?', 'Comment payez-vous cet enseignant ?'),
      children: [
        PrPills<String>(values: const ['monthly', 'hourly', 'manual'], selected: _type, label: (t) => _payTypeLabel(s, t), onChanged: (v) => setState(() => _type = v)),
        const SizedBox(height: 16),
        if (_type == 'monthly')
          TextField(controller: _monthly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: pnDeco(s.pn('Monthly amount', 'Montant mensuel'), suffix: 'FCFA')),
        if (_type == 'hourly') ...[
          TextField(controller: _hourly, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: pnDeco(s.pn('Rate per hour', 'Taux horaire'), suffix: 'FCFA')),
          const SizedBox(height: 12),
          TextField(controller: _weeks, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: pnDeco(s.pn('Teaching weeks per month', 'Semaines de cours par mois'))),
          const SizedBox(height: 8),
          Text(
            s.pn('Expected pay = rate × the teacher\'s weekly periods in the timetable × weeks per month. It updates when the timetable changes.', 'Paie attendue = taux × périodes hebdomadaires de l\'emploi du temps × semaines par mois. Elle suit les changements d\'emploi du temps.'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4),
          ),
        ],
        if (_type == 'manual')
          Text(
            s.pn('No fixed amount. You enter the amount each time you pay.', 'Aucun montant fixe. Vous saisissez le montant à chaque paiement.'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4),
          ),
        const SizedBox(height: 14),
        TextField(controller: _notes, maxLines: 2, decoration: pnDeco(s.pn('Agreement notes (optional)', 'Notes sur l\'accord (facultatif)'))),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}

// ============================================================ cancel payment

class _VoidSheet extends StatefulWidget {
  final AppStrings strings;
  final PnTeacherPayment payment;
  const _VoidSheet({required this.strings, required this.payment});

  @override
  State<_VoidSheet> createState() => _VoidSheetState();
}

class _VoidSheetState extends State<_VoidSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PnSheetBody(
      title: s.pn('Cancel this payment?', 'Annuler ce paiement ?'),
      subtitle: '${widget.payment.teacher} · ${pMoney(widget.payment.amount)}',
      children: [
        PnNotice(color: pnWarn(), icon: Icons.warning_amber_rounded, text: s.pn('Use this only for a mistake. The matching expense is removed from the proprietor\'s books.', 'À utiliser seulement en cas d\'erreur. La dépense correspondante est retirée des comptes du promoteur.')),
        const SizedBox(height: 14),
        TextField(controller: _reason, autofocus: true, maxLines: 2, onChanged: (_) => setState(() {}), decoration: pnDeco(s.pn('Reason', 'Motif'))),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.pn('Keep it', 'Conserver'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: _reason.text.trim().length < 3 ? null : () => Navigator.pop(context, _reason.text.trim()),
          child: Text(s.pn('Cancel payment', 'Annuler le paiement')),
        ),
      ],
    );
  }
}

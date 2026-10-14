import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_expenses.dart' show kPrCategories, prCategoryIcon, prCategoryLabel;
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Expenses the principal pays for the school (and the teacher payments
/// they made). They appear in the proprietor's books, with a flag when
/// the amount is above the approval threshold.
class PrincipalExpensesPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalExpensesPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalExpensesPage> createState() => _PrincipalExpensesPageState();
}

class _PrincipalExpensesPageState extends ConsumerState<PrincipalExpensesPage> {
  static const _pageSize = 40;
  final List<PnExpense> _items = [];
  bool _loading = true;
  bool _more = false;
  bool _hasMore = false;
  Object? _error;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      if (_items.isEmpty) setState(() => _loading = true);
    } else {
      setState(() => _more = true);
    }
    try {
      final rows = await ref.read(principalHubRepositoryProvider).getMyExpenses(limit: _pageSize, offset: reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(rows);
        _hasMore = rows.length >= _pageSize;
        _loading = false;
        _more = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _add() async {
    final s = _s;
    final flagged = await pnSheet<bool>(context, (_) => _ExpenseSheet(strings: s, schoolId: widget.schoolId));
    if (flagged == null || !mounted) return;
    ref.invalidate(pnOverviewProvider);
    _load(reset: true);
    prSnack(
      context,
      flagged
          ? s.pn('Expense recorded. It is above the approval amount, so the proprietor was alerted.', 'Dépense enregistrée. Elle dépasse le montant d\'alerte : le promoteur a été prévenu.')
          : s.pn('Expense recorded.', 'Dépense enregistrée.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    ref.listen<int>(pnTickProvider, (_, __) => _load(reset: true));

    return PrPage(
      onRefresh: () => _load(reset: true),
      children: [
        PrHeader(
          title: s.pn('Expenses', 'Dépenses'),
          subtitle: s.pn('Money you spent for the school. Each one shows in the proprietor\'s expenses.', 'L\'argent dépensé pour l\'école. Chaque dépense apparaît chez le promoteur.'),
          trailing: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(s.pn('New expense', 'Nouvelle dépense'))),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          SizedBox(height: 260, child: PrError(error: _error!, strings: s, onRetry: () => _load(reset: true)))
        else if (_items.isEmpty)
          SizedBox(
            height: 300,
            child: PrEmpty(
              icon: Icons.receipt_long_outlined,
              title: s.pn('No expenses yet', 'Aucune dépense'),
              description: s.pn('Record what you pay for the school: supplies, repairs, transport…', 'Enregistrez ce que vous payez pour l\'école : fournitures, réparations, transport…'),
              action: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(s.pn('New expense', 'Nouvelle dépense'))),
            ),
          )
        else
          PrCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                _row(_items[i], theme),
              ],
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _more
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                      : TextButton(onPressed: () => _load(reset: false), child: Text(s.pn('Show more', 'Afficher plus'))),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _row(PnExpense e, ThemeData theme) {
    final s = _s;
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Icon(prCategoryIcon(e.category), size: 20, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.description, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              PnChip(label: prCategoryLabel(s, e.category)),
              PnChip(label: pMethodLabel(s, e.method)),
              if (e.source == 'teacher_payment') PnChip(label: s.pn('Teacher pay', 'Paie enseignant'), color: cs.primary),
              if (e.needsReview) PnChip(label: s.pn('Flagged to proprietor', 'Signalé au promoteur'), color: pnWarn(), icon: Icons.flag_rounded),
            ]),
            const SizedBox(height: 4),
            Text(
              [if (e.date != null) pDate(e.date!), if (e.paidTo != null) '${s.pn('to', 'à')} ${e.paidTo}', if (e.place != null) e.place!].join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text(pMoney(e.amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// ============================================================ new expense

class _ExpenseSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final String schoolId;
  const _ExpenseSheet({required this.strings, required this.schoolId});

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  String _category = 'Supplies';
  String _method = 'cash';
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _paidTo = TextEditingController();
  final _place = TextEditingController();
  final _reference = TextEditingController();
  DateTime _date = DateTime.now();
  Uint8List? _receipt;
  String _receiptName = '';
  String _receiptExt = 'jpg';
  bool _busy = false;
  String? _error;

  AppStrings get _s => widget.strings;
  bool get _mobile => _method == 'mtn_momo' || _method == 'orange_money';

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _paidTo.dispose();
    _place.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _receipt = bytes;
        _receiptName = picked.name;
        _receiptExt = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      });
    } catch (_) {
      if (mounted) prSnack(context, _s.pn('The photo could not be read. Try another one.', 'La photo n\'a pas pu être lue. Essayez-en une autre.'));
    }
  }

  Future<void> _save() async {
    final s = _s;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.').replaceAll(' ', ''));
    String? err;
    if (_description.text.trim().length < 3) {
      err = pnErr(s, 'purpose_required');
    } else if (amount == null || amount <= 0) {
      err = pnErr(s, 'amount_invalid');
    } else if (!_mobile && _paidTo.text.trim().isEmpty) {
      err = pnErr(s, 'paid_to_required');
    } else if (!_mobile && _place.text.trim().isEmpty) {
      err = pnErr(s, 'place_required');
    } else if (_method == 'bank_transfer' && _reference.text.trim().isEmpty) {
      err = pnErr(s, 'reference_required');
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(principalHubRepositoryProvider);
      String? receipt;
      if (_receipt != null) {
        receipt = await repo.uploadReceipt(schoolId: widget.schoolId, bytes: _receipt!, extension: _receiptExt);
      }
      final flagged = await repo.recordExpense(
        category: _category,
        description: _description.text,
        amount: amount!,
        date: _date,
        method: _method,
        paidTo: _paidTo.text,
        place: _place.text,
        reference: _reference.text,
        receiptRef: receipt,
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
      title: s.pn('New expense', 'Nouvelle dépense'),
      children: [
        Text(s.pn('Category', 'Catégorie'), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<String>(values: kPrCategories, selected: _category, label: (c) => prCategoryLabel(s, c), onChanged: (v) => setState(() => _category = v)),
        const SizedBox(height: 16),
        TextField(controller: _description, decoration: pnDeco(s.pn('What was it for?', 'C\'était pour quoi ?'), hint: s.pn('e.g. Chalk and markers', 'ex. craies et marqueurs'))),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: pnDeco(s.pn('Amount', 'Montant'), suffix: 'FCFA', icon: Icons.payments_outlined),
        ),
        const SizedBox(height: 16),
        Text(s.pn('How was it paid?', 'Comment a-t-il été payé ?'), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<String>(values: const ['cash', 'bank_transfer', 'mtn_momo', 'orange_money'], selected: _method, label: (m) => pMethodLabel(s, m), onChanged: (v) => setState(() => _method = v)),
        const SizedBox(height: 14),
        if (_mobile)
          PnNotice(icon: Icons.phone_android_rounded, text: s.pn('Mobile money is record-only for now: send the money from your phone, then record it here.', 'Le mobile money est pour l\'instant en simple enregistrement : envoyez l\'argent depuis votre téléphone, puis enregistrez-le ici.'))
        else
          PnNotice(icon: Icons.fact_check_outlined, text: s.pn('Say who received the money and where it was handed over.', 'Indiquez qui a reçu l\'argent et où il a été remis.')),
        const SizedBox(height: 14),
        TextField(controller: _paidTo, decoration: pnDeco(_mobile ? s.pn('Paid to (optional)', 'Payé à (facultatif)') : s.pn('Paid to', 'Payé à'), icon: Icons.person_outline_rounded)),
        if (!_mobile) ...[
          const SizedBox(height: 12),
          TextField(controller: _place, decoration: pnDeco(s.pn('Place', 'Lieu'), icon: Icons.place_outlined)),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          decoration: pnDeco(_method == 'bank_transfer' ? s.pn('Bank transfer reference', 'Référence du virement') : s.pn('Reference (optional)', 'Référence (facultatif)'), icon: Icons.tag_rounded),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final d = await pnPickDate(context, _date, last: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(decoration: pnDeco(s.pn('Date', 'Date'), icon: Icons.event_outlined), child: Text(pDate(_date))),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickReceipt,
          icon: Icon(_receipt == null ? Icons.photo_camera_outlined : Icons.check_circle_rounded),
          label: Text(_receipt == null ? s.pn('Attach a receipt photo (optional)', 'Joindre une photo du reçu (facultatif)') : _receiptName, overflow: TextOverflow.ellipsis),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      ],
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: s.pn('Record expense', 'Enregistrer la dépense'))),
      ],
    );
  }
}

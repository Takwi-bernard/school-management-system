import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import 'proprietor_format.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';

/// Canonical (language-neutral) category keys stored in the database.
const List<String> kPrCategories = [
  'Salaries',
  'Utilities',
  'Supplies',
  'Maintenance',
  'Transport',
  'Equipment',
  'Rent',
  'Events',
  'Taxes',
  'Other',
];

String prCategoryLabel(AppStrings s, String raw) {
  switch (raw) {
    case 'Salaries':
      return s.prCatSalaries;
    case 'Utilities':
      return s.prCatUtilities;
    case 'Supplies':
      return s.prCatSupplies;
    case 'Maintenance':
      return s.prCatMaintenance;
    case 'Transport':
      return s.prCatTransport;
    case 'Equipment':
      return s.prCatEquipment;
    case 'Rent':
      return s.prCatRent;
    case 'Events':
      return s.prCatEvents;
    case 'Taxes':
      return s.prCatTaxes;
    case 'Other':
      return s.prCatOther;
    default:
      return raw;
  }
}

IconData prCategoryIcon(String raw) {
  switch (raw) {
    case 'Salaries':
      return Icons.badge_outlined;
    case 'Utilities':
      return Icons.bolt_outlined;
    case 'Supplies':
      return Icons.inventory_2_outlined;
    case 'Maintenance':
      return Icons.handyman_outlined;
    case 'Transport':
      return Icons.directions_bus_outlined;
    case 'Equipment':
      return Icons.computer_outlined;
    case 'Rent':
      return Icons.home_work_outlined;
    case 'Events':
      return Icons.celebration_outlined;
    case 'Taxes':
      return Icons.account_balance_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

const List<String> _kMethods = ['cash', 'bank_transfer', 'mtn_momo', 'orange_money'];

class ProprietorExpensesPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const ProprietorExpensesPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<ProprietorExpensesPage> createState() => _ProprietorExpensesPageState();
}

class _ProprietorExpensesPageState extends ConsumerState<ProprietorExpensesPage> {
  final List<ExpenseRecord> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  int _generation = 0;
  String? _category;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _refreshAggregates() {
    ref.invalidate(financeProvider);
    ref.invalidate(budgetsProvider(widget.schoolId));
    ref.read(proprietorTickProvider.notifier).state++;
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final page = await ref.read(proprietorRepositoryProvider).getExpensesPage(schoolId: widget.schoolId, offset: 0, category: _category);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(proprietorRepositoryProvider).getExpensesPage(schoolId: widget.schoolId, offset: _items.length, category: _category);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openRecord() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordExpenseDialog(schoolId: widget.schoolId, strings: _s),
    );
    if (saved == true) {
      _refreshAggregates();
      await _reload();
    }
  }

  Future<void> _openBudget({ExpenseBudget? existing, List<ExpenseBudget> all = const []}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _BudgetDialog(schoolId: widget.schoolId, strings: _s, existing: existing, taken: all.map((b) => b.category).toSet()),
    );
    if (changed == true) _refreshAggregates();
  }

  Future<void> _openDetails(ExpenseRecord e) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExpenseDetails(expense: e, strings: _s),
    );
    if (deleted == true) {
      _refreshAggregates();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(proprietorTickProvider, (_, __) => _reload());

    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final financeAsync = ref.watch(financeProvider(12));
    final budgetsAsync = ref.watch(budgetsProvider(widget.schoolId));
    final f = financeAsync.valueOrNull;
    final budgets = budgetsAsync.valueOrNull ?? const <ExpenseBudget>[];

    double spentIn(String category) => f == null ? 0 : f.byCategoryThisMonth.where((c) => c.category == category).fold<double>(0, (a, c) => a + c.total);

    // categories offered as filters: the standard ones plus any custom ones seen
    final seen = <String>{...kPrCategories, ...?f?.byCategory.map((c) => c.category), ...budgets.map((b) => b.category)};

    final topThis = (f == null || f.byCategoryThisMonth.isEmpty) ? null : f.byCategoryThisMonth.first;

    return PrPage(
      onRefresh: () async {
        _refreshAggregates();
        await _reload();
      },
      children: [
        PrHeader(
          title: s.prExpensesTitle,
          subtitle: s.prExpensesDesc,
          trailing: FilledButton.icon(onPressed: _openRecord, icon: const Icon(Icons.add_rounded), label: Text(s.prRecordExpense)),
        ),
        if (f != null)
          PrGrid(minTile: 250, max: 3, children: [
            PrStatTile(
              icon: Icons.north_east_rounded,
              label: s.prSpentThisMonth,
              value: f.expenseThisMonth,
              format: pMoney,
              spark: f.days.map((d) => d.expense).toList(),
              footer: PrDeltaChip(delta: pDelta(f.expenseThisMonth, f.expensePrevMonth), strings: s, higherIsBetter: false),
            ),
            PrStatTile(
              icon: Icons.category_outlined,
              label: s.prTopCategory,
              value: topThis?.total ?? 0,
              format: pMoney,
              footer: Text(topThis == null ? '—' : prCategoryLabel(s, topThis.category), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
            ),
            PrStatTile(
              icon: Icons.savings_outlined,
              label: s.prBudgets,
              value: budgets.length.toDouble(),
              format: (v) => v.round().toString(),
              footer: Text(
                budgets.where((b) => spentIn(b.category) > b.monthlyLimit && b.monthlyLimit > 0).isEmpty ? s.prOnTrack : s.prOverBudget,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: budgets.where((b) => spentIn(b.category) > b.monthlyLimit && b.monthlyLimit > 0).isEmpty ? kSettled : kOverdue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        const SizedBox(height: 8),
        PrSectionTitle(
          title: s.prBudgets,
          subtitle: s.prBudgetsDesc,
          trailing: TextButton.icon(onPressed: () => _openBudget(all: budgets), icon: const Icon(Icons.add_rounded, size: 18), label: Text(s.prSetBudget)),
        ),
        if (budgets.isEmpty)
          PrCard(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.prNoBudgets, style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline))))
        else
          PrGrid(
            minTile: 300,
            max: 3,
            children: [
              for (final b in budgets)
                _BudgetCard(
                  budget: b,
                  spent: spentIn(b.category),
                  strings: s,
                  onTap: () => _openBudget(existing: b, all: budgets),
                ),
            ],
          ),
        const SizedBox(height: 8),
        PrSectionTitle(title: s.prExpenseHistory),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: PrPills<String?>(
            values: [null, ...seen],
            selected: _category,
            label: (v) => v == null ? s.prAll : prCategoryLabel(s, v),
            onChanged: (v) {
              setState(() => _category = v);
              _reload();
            },
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          Column(children: List.generate(5, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: PrSkeleton(height: 68, radius: 16))))
        else if (_error != null && _items.isEmpty)
          SizedBox(height: 240, child: PrError(error: _error!, strings: s, onRetry: _reload))
        else if (_items.isEmpty)
          SizedBox(height: 260, child: PrEmpty(icon: Icons.receipt_long_outlined, title: s.prNoExpenses, description: s.prNoExpensesHint))
        else ...[
          for (final e in _items)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _ExpenseRow(expense: e, strings: s, onTap: () => _openDetails(e))),
          if (_hasMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _loadingMore
                    ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : OutlinedButton.icon(onPressed: _loadMore, icon: const Icon(Icons.expand_more_rounded), label: Text(s.prLoadMore)),
              ),
            ),
        ],
      ],
    );
  }
}

// ============================================================ budget card

class _BudgetCard extends StatelessWidget {
  final ExpenseBudget budget;
  final double spent;
  final AppStrings strings;
  final VoidCallback onTap;
  const _BudgetCard({required this.budget, required this.spent, required this.strings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final ratio = budget.monthlyLimit <= 0 ? 0.0 : spent / budget.monthlyLimit;
    final over = ratio > 1;
    final near = !over && ratio >= 0.85;
    final color = over ? kOverdue : (near ? kPending : cs.primary);
    final label = over ? s.prOverBudget : (near ? s.prNearBudget : s.prOnTrack);

    return PrCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(prCategoryIcon(budget.category), size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(prCategoryLabel(s, budget.category), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 14),
        PrProgressBar(value: ratio, color: color, height: 9),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(s.prBudgetUsed(pMoney(spent), pMoney(budget.monthlyLimit)), style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
          Text(pPercent(ratio * 100), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: color)),
        ]),
      ]),
    );
  }
}

// ============================================================ history row

class _ExpenseRow extends StatelessWidget {
  final ExpenseRecord expense;
  final AppStrings strings;
  final VoidCallback onTap;
  const _ExpenseRow({required this.expense, required this.strings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final sub = [
      if (expense.paidTo != null && expense.paidTo!.isNotEmpty) expense.paidTo!,
      pMethodLabel(s, expense.method),
      pDate(expense.date),
    ].join(' · ');
    return PrCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
          child: Icon(prCategoryIcon(expense.category), size: 20, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prCategoryLabel(s, expense.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (expense.description != null && expense.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(expense.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
          ]),
        ),
        if (expense.needsReview) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.flag_rounded, size: 18, color: kPending)),
        if (expense.receiptRef != null && expense.receiptRef!.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.attach_file_rounded, size: 16, color: cs.outline)),
        Text(pMoney(expense.amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// ============================================================ details sheet

class _ExpenseDetails extends ConsumerStatefulWidget {
  final ExpenseRecord expense;
  final AppStrings strings;
  const _ExpenseDetails({required this.expense, required this.strings});

  @override
  ConsumerState<_ExpenseDetails> createState() => _ExpenseDetailsState();
}

class _ExpenseDetailsState extends ConsumerState<_ExpenseDetails> {
  bool _busy = false;
  String? _receiptUrl;
  bool _receiptFailed = false;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final ref0 = widget.expense.receiptRef;
    if (ref0 == null || ref0.isEmpty) return;
    try {
      final url = await ref.read(proprietorRepositoryProvider).receiptUrl(ref0);
      if (mounted) setState(() => _receiptUrl = url);
    } catch (_) {
      if (mounted) setState(() => _receiptFailed = true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(_s.prDeleteExpenseTitle),
        content: Text(_s.prDeleteExpenseBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(_s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(_s.prDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(proprietorRepositoryProvider).deleteExpense(widget.expense.id);
      if (!mounted) return;
      prSnack(context, _s.prExpenseDeleted);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, _s.prExpenseSaveError);
      }
    }
  }

  Future<void> _review() async {
    setState(() => _busy = true);
    try {
      await ref.read(proprietorRepositoryProvider).reviewExpense(widget.expense.id);
      if (!mounted) return;
      prSnack(context, _s.isFrench ? 'Dépense marquée comme examinée.' : 'Expense marked as reviewed.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, _s.prExpenseSaveError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = _s;
    final e = widget.expense;

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          ]),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 4, 22, 22 + MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(prCategoryIcon(e.category), color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(prCategoryLabel(s, e.category), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 6),
            Text(pMoney(e.amount), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: cs.primary)),
            if (e.needsReview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kPending.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: kPending.withValues(alpha: 0.35))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.flag_rounded, size: 18, color: kPending),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.isFrench ? 'Le Directeur a signalé cette dépense car son montant dépasse le seuil d\'alerte. Vérifiez-la, puis marquez-la comme examinée.' : 'The principal flagged this expense because it is above the alert amount. Check it, then mark it as reviewed.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            line(s.prExpenseDate, pDate(e.date)),
            line(s.prPaymentMethod, pMethodLabel(s, e.method)),
            if (e.paidTo != null && e.paidTo!.isNotEmpty) line(s.prColPaidTo, e.paidTo!),
            if (e.place != null && e.place!.isNotEmpty) line(s.isFrench ? 'Lieu' : 'Place', e.place!),
            if (e.description != null && e.description!.isNotEmpty) line(s.prColNote, e.description!),
            if (e.recordedBy.isNotEmpty) line(s.prRecordedBy, e.recordedBy),
            if (e.receiptRef != null && e.receiptRef!.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (_receiptUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (d) => Dialog(
                        child: InteractiveViewer(child: Image.network(_receiptUrl!, errorBuilder: (_, __, ___) => Padding(padding: const EdgeInsets.all(24), child: Text(s.prReceiptError)))),
                      ),
                    ),
                    child: Image.network(_receiptUrl!, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => SizedBox(height: 80, child: Center(child: Text(s.prReceiptError)))),
                  ),
                )
              else if (_receiptFailed)
                Text(s.prReceiptError, style: theme.textTheme.bodySmall?.copyWith(color: cs.error))
              else
                const PrSkeleton(height: 120, radius: 14),
            ],
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(s.prClose))),
              if (e.needsReview) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _review,
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 18),
                    label: Text(s.isFrench ? 'Marquer examinée' : 'Mark reviewed'),
                  ),
                ),
              ],
              // a teacher payment is cancelled by the principal, never deleted here
              if (e.source != 'teacher_payment') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                    icon: _busy && !e.needsReview ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(s.prDelete),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ============================================================ record dialog

class _RecordExpenseDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const _RecordExpenseDialog({required this.schoolId, required this.strings});

  @override
  ConsumerState<_RecordExpenseDialog> createState() => _RecordExpenseDialogState();
}

class _RecordExpenseDialogState extends ConsumerState<_RecordExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _paidTo = TextEditingController();
  final _desc = TextEditingController();
  final _custom = TextEditingController();

  String _category = kPrCategories.first;
  bool _useCustom = false;
  String _method = 'cash';
  DateTime _date = DateTime.now();
  Uint8List? _receiptBytes;
  String _receiptExt = 'jpg';
  String? _receiptName;
  bool _saving = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _amount.dispose();
    _paidTo.dispose();
    _desc.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _receiptBytes = bytes;
        _receiptName = picked.name;
        _receiptExt = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      });
    } catch (_) {
      if (mounted) prSnack(context, _s.prReceiptPickError);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      prSnack(context, _s.prInvalidAmount);
      return;
    }
    final category = _useCustom ? _custom.text.trim() : _category;
    setState(() => _saving = true);
    try {
      final repo = ref.read(proprietorRepositoryProvider);
      String? receipt;
      if (_receiptBytes != null) {
        receipt = await repo.uploadReceipt(schoolId: widget.schoolId, bytes: _receiptBytes!, extension: _receiptExt);
      }
      await repo.recordExpense(
        schoolId: widget.schoolId,
        category: category,
        description: _desc.text.trim(),
        amount: amount,
        date: _date,
        paymentMethod: _method,
        paidTo: _paidTo.text.trim(),
        receiptRef: receipt,
      );
      if (!mounted) return;
      prSnack(context, _s.prExpenseSaved);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        prSnack(context, _s.prExpenseSaveError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    InputDecoration deco(String label, {IconData? icon}) => InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.prRecordExpense, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _useCustom ? '__custom' : _category,
                decoration: deco(s.prCategory, icon: Icons.category_outlined),
                isExpanded: true,
                items: [
                  for (final c in kPrCategories) DropdownMenuItem(value: c, child: Text(prCategoryLabel(s, c))),
                  DropdownMenuItem(value: '__custom', child: Text(s.prCustomCategory)),
                ],
                onChanged: (v) => setState(() {
                  if (v == '__custom') {
                    _useCustom = true;
                  } else if (v != null) {
                    _useCustom = false;
                    _category = v;
                  }
                }),
              ),
              if (_useCustom) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _custom, decoration: deco(s.prCustomCategoryName), validator: (v) => (v == null || v.trim().isEmpty) ? s.prRequiredField : null),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
                decoration: deco(s.prAmount, icon: Icons.payments_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? s.prRequiredField : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _method,
                    decoration: deco(s.prPaymentMethod),
                    isExpanded: true,
                    items: [for (final m in _kMethods) DropdownMenuItem(value: m, child: Text(pMethodLabel(s, m), overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => _method = v ?? _method),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: InputDecorator(decoration: deco(s.prExpenseDate), child: Text(pDate(_date))),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _paidTo, decoration: deco(s.prPaidTo, icon: Icons.person_outline_rounded)),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, minLines: 2, maxLines: 3, decoration: deco(s.prDescription)),
              const SizedBox(height: 14),
              if (_receiptBytes != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_receiptBytes!, width: 48, height: 48, fit: BoxFit.cover)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_receiptName ?? s.prReceiptAttached, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    IconButton(onPressed: () => setState(() => _receiptBytes = null), icon: const Icon(Icons.close_rounded)),
                  ]),
                )
              else
                OutlinedButton.icon(onPressed: _pickReceipt, icon: const Icon(Icons.attach_file_rounded, size: 18), label: Text(s.prAttachReceipt)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(s.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(s.prSave),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================ budget dialog

class _BudgetDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  final ExpenseBudget? existing;
  final Set<String> taken;
  const _BudgetDialog({required this.schoolId, required this.strings, required this.existing, required this.taken});

  @override
  ConsumerState<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<_BudgetDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _limit = TextEditingController(text: widget.existing == null ? '' : widget.existing!.monthlyLimit.round().toString());
  late String _category;
  bool _saving = false;

  AppStrings get _s => widget.strings;

  List<String> get _choices {
    final free = kPrCategories.where((c) => !widget.taken.contains(c)).toList();
    if (widget.existing != null && !free.contains(widget.existing!.category)) free.insert(0, widget.existing!.category);
    return free;
  }

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category ?? (_choices.isNotEmpty ? _choices.first : kPrCategories.first);
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final limit = double.tryParse(_limit.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (limit == null || limit < 0) {
      prSnack(context, _s.prInvalidAmount);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(proprietorRepositoryProvider).saveBudget(schoolId: widget.schoolId, category: _category, limit: limit);
      if (!mounted) return;
      prSnack(context, _s.prBudgetSaved);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        prSnack(context, _s.prExpenseSaveError);
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      await ref.read(proprietorRepositoryProvider).deleteBudget(widget.existing!.id);
      if (!mounted) return;
      prSnack(context, _s.prBudgetRemoved);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        prSnack(context, _s.prExpenseSaveError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final choices = _choices;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.existing == null ? s.prSetBudget : s.prEditBudget, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              if (widget.existing != null)
                InputDecorator(
                  decoration: InputDecoration(labelText: s.prCategory, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(prCategoryLabel(s, _category)),
                )
              else
                DropdownButtonFormField<String>(
                  value: choices.contains(_category) ? _category : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s.prCategory, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  items: [for (final c in choices) DropdownMenuItem(value: c, child: Text(prCategoryLabel(s, c)))],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _limit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
                decoration: InputDecoration(labelText: s.prMonthlyLimit, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                validator: (v) => (v == null || v.trim().isEmpty) ? s.prRequiredField : null,
              ),
              const SizedBox(height: 20),
              Row(children: [
                if (widget.existing != null) TextButton(onPressed: _saving ? null : _remove, style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error), child: Text(s.prRemoveBudget)),
                const Spacer(),
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(s.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving || choices.isEmpty ? null : _save,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(s.prSave),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

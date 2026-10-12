import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_model.dart';
import 'proprietor_export.dart';
import 'proprietor_format.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';
import 'proprietor_expenses.dart' show prCategoryLabel;

enum _Range { month, thirty, year, custom }

/// Official statements on the school's letterhead (PDF) or as
/// spreadsheets (Excel), for any period.
class ProprietorReportsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const ProprietorReportsPage({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<ProprietorReportsPage> createState() => _ProprietorReportsPageState();
}

class _ProprietorReportsPageState extends ConsumerState<ProprietorReportsPage> {
  _Range _range = _Range.month;
  DateTimeRange? _custom;
  String? _busy;

  AppStrings get _s => widget.strings;

  DateTimeRange get _period {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
      case _Range.thirty:
        return DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today);
      case _Range.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: today);
      case _Range.custom:
        return _custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
    }
  }

  String _rangeLabel(_Range r) {
    switch (r) {
      case _Range.month:
        return _s.prThisMonth;
      case _Range.thirty:
        return _s.prLastNDays30;
      case _Range.year:
        return _s.prThisYear;
      case _Range.custom:
        return _s.prCustom;
    }
  }

  Future<void> _pickRange(_Range r) async {
    if (r != _Range.custom) {
      setState(() => _range = r);
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _custom ?? _period,
      helpText: _s.prPickRange,
    );
    if (picked != null) setState(() {
      _custom = picked;
      _range = _Range.custom;
    });
  }

  String get _periodText => '${pDate(_period.start)} – ${pDate(_period.end)}';

  String get _fileStamp {
    final p = _period;
    String d(DateTime x) => '${x.year}${x.month.toString().padLeft(2, '0')}${x.day.toString().padLeft(2, '0')}';
    return '${d(p.start)}-${d(p.end)}';
  }

  // ---------------------------------------------------------------- builders

  Future<_Table> _financial() async {
    final repo = ref.read(proprietorRepositoryProvider);
    final p = _period;
    final income = await repo.getIncomeRange(schoolId: widget.schoolId, from: p.start, to: p.end, fallbackPurpose: _s.prPaymentFallback);
    final spend = await repo.getExpensesRange(schoolId: widget.schoolId, from: p.start, to: p.end);

    final byMonth = <String, List<double>>{}; // key -> [income, expense]
    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    var cursor = DateTime(p.start.year, p.start.month, 1);
    final last = DateTime(p.end.year, p.end.month, 1);
    while (!cursor.isAfter(last)) {
      byMonth[key(cursor)] = [0, 0];
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    for (final r in income) {
      final l = r.date.toLocal();
      byMonth.putIfAbsent(key(l), () => [0, 0])[0] += r.amount;
    }
    for (final e in spend) {
      byMonth.putIfAbsent(key(e.date), () => [0, 0])[1] += e.amount;
    }

    final rows = <List<String>>[];
    var ti = 0.0, te = 0.0;
    for (final entry in byMonth.entries) {
      final parts = entry.key.split('-');
      final month = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      final i = entry.value[0], e = entry.value[1];
      ti += i;
      te += e;
      rows.add([pMonthLong(_s, month), i.round().toString(), e.round().toString(), (i - e).round().toString()]);
    }
    rows.add([_s.prTotalRow, ti.round().toString(), te.round().toString(), (ti - te).round().toString()]);
    return _Table(
      title: _s.prReportFinancial,
      sheet: _s.prFinance.length > 30 ? 'Financial' : _s.prFinance,
      headers: [_s.prColMonth, '${_s.prColIncome} (FCFA)', '${_s.prColSpending} (FCFA)', '${_s.prColNet} (FCFA)'],
      rows: rows,
      empty: income.isEmpty && spend.isEmpty,
    );
  }

  Future<_Table> _incomeTable() async {
    final p = _period;
    final list = await ref.read(proprietorRepositoryProvider).getIncomeRange(schoolId: widget.schoolId, from: p.start, to: p.end, fallbackPurpose: _s.prPaymentFallback);
    final total = list.fold<double>(0, (a, r) => a + r.amount);
    final rows = [
      for (final r in list) [pDateTime(r.date), r.studentName, r.purpose, pMethodLabel(_s, r.method), r.amount.round().toString()],
      ['', '', '', _s.prTotalRow, total.round().toString()],
    ];
    return _Table(
      title: _s.prReportIncome,
      sheet: 'Income',
      headers: [_s.prColDate, _s.prColStudent, _s.prColPurpose, _s.prColMethod, '${_s.prColAmount} (FCFA)'],
      rows: rows,
      empty: list.isEmpty,
    );
  }

  Future<_Table> _expenseTable() async {
    final p = _period;
    final list = await ref.read(proprietorRepositoryProvider).getExpensesRange(schoolId: widget.schoolId, from: p.start, to: p.end);
    final total = list.fold<double>(0, (a, e) => a + e.amount);
    final rows = [
      for (final e in list)
        [pDate(e.date), prCategoryLabel(_s, e.category), e.paidTo ?? '', e.description ?? '', pMethodLabel(_s, e.method), e.amount.round().toString()],
      ['', '', '', '', _s.prTotalRow, total.round().toString()],
    ];
    return _Table(
      title: _s.prReportExpense,
      sheet: 'Expenditure',
      headers: [_s.prColDate, _s.prColCategory, _s.prColPaidTo, _s.prColNote, _s.prColMethod, '${_s.prColAmount} (FCFA)'],
      rows: rows,
      empty: list.isEmpty,
    );
  }

  Future<_Table> _enrollmentTable() async {
    final st = await ref.read(schoolStatsProvider.future);
    final totalCount = st.byClass.fold<int>(0, (a, c) => a + c.count);
    final totalCap = st.byClass.fold<int>(0, (a, c) => a + c.capacity);
    final rows = [
      for (final c in st.byClass) [c.className, c.department, '${c.count}', c.capacity > 0 ? '${c.capacity}' : '-', c.capacity > 0 ? pPercent(c.fillRate * 100) : '-'],
      [_s.prTotalRow, '', '$totalCount', totalCap > 0 ? '$totalCap' : '-', totalCap > 0 ? pPercent(totalCount / totalCap * 100) : '-'],
    ];
    return _Table(
      title: _s.prReportEnrollment,
      sheet: 'Enrollment',
      headers: [_s.prColClass, _s.prColDepartment, _s.prColStudents, _s.prColCapacity, _s.prColFill],
      rows: rows,
      empty: st.byClass.isEmpty,
    );
  }

  Future<void> _download(String id, Future<_Table> Function() build, bool pdf, {bool dated = true}) async {
    if (_busy != null) return;
    setState(() => _busy = '$id-${pdf ? 'pdf' : 'xlsx'}');
    try {
      final t = await build();
      if (t.empty) {
        if (mounted) prSnack(context, _s.prNothingToExport);
        return;
      }
      final subtitle = dated ? '$_periodText · ${pDate(DateTime.now())}' : pDate(DateTime.now());
      final base = dated ? '$id-$_fileStamp' : id;
      if (pdf) {
        await prExportPdf(ref: ref, landing: widget.landing, fileName: '$base.pdf', title: t.title, subtitle: subtitle, headers: t.headers, rows: t.rows);
      } else {
        prExportExcel(fileName: '$base.xlsx', sheetName: t.sheet, headers: t.headers, rows: t.rows);
      }
      if (mounted) prSnack(context, _s.prExportDone);
    } catch (_) {
      if (mounted) prSnack(context, _s.prExportFailed);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget card(int index, String id, IconData icon, String title, String desc, Future<_Table> Function() build, {bool dated = true}) {
      final busyPdf = _busy == '$id-pdf';
      final busyXlsx = _busy == '$id-xlsx';
      return PrCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Text(desc, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.4)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy != null ? null : () => _download(id, build, true, dated: dated),
                icon: busyPdf ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy != null ? null : () => _download(id, build, false, dated: dated),
                icon: busyXlsx ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Excel'),
              ),
            ),
          ]),
        ]),
      );
    }

    return PrPage(
      children: [
        PrHeader(title: s.prReportsTitle, subtitle: s.prReportsIntro),
        PrReveal(
          child: PrCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.date_range_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(s.prPeriod, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(_periodText, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              PrPills<_Range>(values: _Range.values, selected: _range, label: _rangeLabel, onChanged: _pickRange),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        PrGrid(minTile: 340, max: 2, children: [
          card(0, 'financial-statement', Icons.account_balance_outlined, s.prReportFinancial, s.prReportFinancialDesc, _financial),
          card(1, 'income-statement', Icons.south_west_rounded, s.prReportIncome, s.prReportIncomeDesc, _incomeTable),
          card(2, 'expenditure-statement', Icons.north_east_rounded, s.prReportExpense, s.prReportExpenseDesc, _expenseTable),
          card(3, 'enrollment-statement', Icons.school_outlined, s.prReportEnrollment, s.prReportEnrollmentDesc, _enrollmentTable, dated: false),
        ]),
      ],
    );
  }
}

class _Table {
  final String title;
  final String sheet;
  final List<String> headers;
  final List<List<String>> rows;
  final bool empty;
  const _Table({required this.title, required this.sheet, required this.headers, required this.rows, required this.empty});
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import 'proprietor_charts.dart';
import 'proprietor_format.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';

/// Financial analysis: trends, sources, methods, categories, net result
/// and a month-by-month statement, over a period the proprietor picks.
class ProprietorFinancePage extends ConsumerStatefulWidget {
  final AppStrings strings;
  const ProprietorFinancePage({super.key, required this.strings});

  @override
  ConsumerState<ProprietorFinancePage> createState() => _ProprietorFinancePageState();
}

class _ProprietorFinancePageState extends ConsumerState<ProprietorFinancePage> {
  int _months = 12;

  AppStrings get _s => widget.strings;

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final async = ref.watch(financeProvider(_months));

    Future<void> refresh() async {
      ref.invalidate(financeProvider(_months));
      try {
        await ref.read(financeProvider(_months).future);
      } catch (_) {}
    }

    final header = PrHeader(title: s.prFinanceTitle, subtitle: s.prFinanceDesc);
    final pills = Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: PrPills<int>(values: const [3, 6, 12, 24], selected: _months, label: s.prMonths, onChanged: (v) => setState(() => _months = v)),
    );

    if (async.isLoading && !async.hasValue) return const PrPageSkeleton();
    if (async.hasError && !async.hasValue) {
      return PrError(error: async.error!, strings: s, onRetry: () => ref.invalidate(financeProvider(_months)));
    }
    final f = async.requireValue;

    return PrPage(
      onRefresh: refresh,
      children: [
        header,
        pills,
        if (!f.hasAnyMoney)
          PrCard(child: SizedBox(height: 240, child: PrEmpty(icon: Icons.insights_rounded, title: s.prNoDataYet, description: s.prNoIncomeYet)))
        else
          _Body(f: f, strings: s),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final FinanceSummary f;
  final AppStrings strings;
  const _Body({required this.f, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final spend = prSpendColor(context);
    final palette = prPalette(context);
    final n = f.months.length;
    final labels = f.months.map((m) => pMonthShort(s, m.month)).toList();
    final best = f.bestMonth;
    final retention = f.retention;

    final periodRegistration = f.months.fold<double>(0, (a, m) => a + m.registration);
    final periodInstallment = f.months.fold<double>(0, (a, m) => a + m.installment);
    final methodTotal = f.byMethod.fold<double>(0, (a, m) => a + m.total);
    final catTotal = f.byCategory.fold<double>(0, (a, c) => a + c.total);

    // ---------- sentences for "what stands out"
    final facts = <String>[];
    if (best != null) facts.add(s.prInsightBest(pMonthLong(s, best.month), pMoney(best.income)));
    if (f.byMethod.isNotEmpty && methodTotal > 0) {
      final top = f.byMethod.first;
      facts.add(s.prInsightMethodLead(pMethodLabel(s, top.method), pPercent(top.total / methodTotal * 100)));
    }
    if (f.byCategory.isNotEmpty && catTotal > 0) {
      final top = f.byCategory.first;
      facts.add(s.prInsightCategoryLead(top.category, pPercent(top.total / catTotal * 100)));
    }
    if (retention != null) facts.add(retention >= 0 ? s.prInsightRetention(pPercent(retention)) : s.prInsightNegative);

    final kpis = PrGrid(minTile: 240, children: [
      PrStatTile(
        icon: Icons.savings_outlined,
        label: s.prSavingsRate,
        value: retention ?? 0,
        format: (v) => retention == null ? '—' : pPercent(v),
        footer: Text(s.prSavingsRateHint, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline, height: 1.3)),
      ),
      PrStatTile(icon: Icons.south_west_rounded, label: s.prAvgMonthlyIncome, value: n == 0 ? 0 : f.periodIncome / n, format: pMoney),
      PrStatTile(icon: Icons.north_east_rounded, label: s.prAvgMonthlySpend, value: n == 0 ? 0 : f.periodExpense / n, format: pMoney),
      PrStatTile(
        icon: Icons.emoji_events_outlined,
        label: s.prBestMonth,
        value: best?.income ?? 0,
        format: pMoney,
        footer: Text(best == null ? '—' : pMonthLong(s, best.month), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
      ),
    ]);

    final standsOut = PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(s.prInsightLine, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        for (final line in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(width: 5, height: 5, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
              ),
              Expanded(child: Text(line, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
            ]),
          ),
      ]),
    );

    final trend = PrChartCard(
      title: s.prIncomeVsSpending,
      subtitle: s.prIncomeVsSpendingDesc,
      legend: [PrLegendItem(label: s.prIncomeSeries, color: cs.primary), PrLegendItem(label: s.prSpendingSeries, color: spend)],
      child: PrBarChart(
        height: 280,
        labels: labels,
        series: [
          PrBarSeries(name: s.prIncomeSeries, color: cs.primary, values: f.months.map((m) => m.income).toList()),
          PrBarSeries(name: s.prSpendingSeries, color: spend, values: f.months.map((m) => m.expense).toList()),
        ],
        axisFormat: pCompact,
        tipFor: (i) => PrTip(title: pMonthLong(s, f.months[i].month), rows: [
          PrTipRow(label: s.prIncomeSeries, value: pMoney(f.months[i].income), color: cs.primary),
          PrTipRow(label: s.prSpendingSeries, value: pMoney(f.months[i].expense), color: spend),
          PrTipRow(label: s.prColNet, value: pMoney(f.months[i].net), color: f.months[i].net >= 0 ? kSettled : kOverdue),
        ]),
      ),
    );

    final net = PrChartCard(
      title: s.prNetByMonth,
      subtitle: s.prNetByMonthDesc,
      child: PrBarChart(
        height: 240,
        labels: labels,
        series: [
          PrBarSeries(
            name: s.prColNet,
            color: kSettled,
            values: f.months.map((m) => m.net).toList(),
            valueColors: f.months.map((m) => m.net >= 0 ? kSettled : kOverdue).toList(),
          ),
        ],
        axisFormat: pCompact,
        tipFor: (i) => PrTip(title: pMonthLong(s, f.months[i].month), rows: [
          PrTipRow(label: s.prColNet, value: pMoney(f.months[i].net), color: f.months[i].net >= 0 ? kSettled : kOverdue),
        ]),
      ),
    );

    final sources = PrChartCard(
      title: s.prIncomeSources,
      subtitle: s.prIncomeSourcesDesc,
      child: (periodRegistration + periodInstallment) <= 0
          ? SizedBox(height: 160, child: PrEmpty(icon: Icons.pie_chart_outline_rounded, title: s.prNoIncomeYet))
          : Column(children: [
              Center(
                child: PrDonut(
                  slices: [
                    PrSlice(label: s.prRegistrationFees, value: periodRegistration, color: palette[0]),
                    PrSlice(label: s.prInstallments, value: periodInstallment, color: palette[2]),
                  ],
                  center: (h) => _DonutCenter(
                    title: h == null ? s.prTotalIncome : (h == 0 ? s.prRegistrationFees : s.prInstallments),
                    value: h == null ? pCompact(periodRegistration + periodInstallment) : pCompact(h == 0 ? periodRegistration : periodInstallment),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ValueRow(color: palette[0], label: s.prRegistrationFees, value: pMoney(periodRegistration), share: periodRegistration / (periodRegistration + periodInstallment)),
              const SizedBox(height: 10),
              _ValueRow(color: palette[2], label: s.prInstallments, value: pMoney(periodInstallment), share: periodInstallment / (periodRegistration + periodInstallment)),
            ]),
    );

    final methods = PrChartCard(
      title: s.prPaymentMethods,
      subtitle: s.prPaymentMethodsDesc,
      child: methodTotal <= 0
          ? SizedBox(height: 160, child: PrEmpty(icon: Icons.pie_chart_outline_rounded, title: s.prNoIncomeYet))
          : Column(children: [
              Center(
                child: PrDonut(
                  slices: [for (var i = 0; i < f.byMethod.length; i++) PrSlice(label: pMethodLabel(s, f.byMethod[i].method), value: f.byMethod[i].total, color: palette[i % palette.length])],
                  center: (h) => _DonutCenter(
                    title: h == null ? s.prAllTime : pMethodLabel(s, f.byMethod[h].method),
                    value: h == null ? '${f.paymentsCount} ${s.prPayments}' : pPercent(f.byMethod[h].total / methodTotal * 100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < f.byMethod.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _ValueRow(color: palette[i % palette.length], label: pMethodLabel(s, f.byMethod[i].method), value: pMoney(f.byMethod[i].total), share: f.byMethod[i].total / methodTotal),
              ],
            ]),
    );

    final categories = PrChartCard(
      title: s.prSpendByCategory,
      subtitle: s.prSpendByCategoryDesc,
      child: catTotal <= 0
          ? SizedBox(height: 140, child: PrEmpty(icon: Icons.receipt_long_outlined, title: s.prNoSpendingYet))
          : Column(children: [
              for (var i = 0; i < f.byCategory.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _CategoryBar(label: f.byCategory[i].category, total: f.byCategory[i].total, count: f.byCategory[i].count, share: f.byCategory[i].total / catTotal, color: palette[i % palette.length]),
              ],
            ]),
    );

    final table = PrChartCard(title: s.prMonthlyTable, child: _StatementTable(f: f, strings: s));

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      Widget twoUp(Widget a, Widget b) => wide
          ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)]))
          : Column(children: [a, const SizedBox(height: 14), b]);

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        kpis,
        const SizedBox(height: 14),
        if (facts.isNotEmpty) PrReveal(child: standsOut),
        if (facts.isNotEmpty) const SizedBox(height: 14),
        PrReveal(child: trend),
        const SizedBox(height: 14),
        PrReveal(child: net),
        const SizedBox(height: 14),
        twoUp(PrReveal(child: sources), PrReveal(index: 1, child: methods)),
        const SizedBox(height: 14),
        PrReveal(child: categories),
        const SizedBox(height: 14),
        PrReveal(child: table),
      ]);
    });
  }
}

class _DonutCenter extends StatelessWidget {
  final String title;
  final String value;
  const _DonutCenter({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
    ]);
  }
}

class _ValueRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final double share;
  const _ValueRow({required this.color, required this.label, required this.value, required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
      SizedBox(width: 40, child: Text(pPercent(share * 100), textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
    ]);
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final double total;
  final int count;
  final double share;
  final Color color;
  const _CategoryBar({required this.label, required this.total, required this.count, required this.share, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(pMoney(total), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        SizedBox(width: 40, child: Text(pPercent(share * 100), textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
      ]),
      const SizedBox(height: 7),
      PrProgressBar(value: share, color: color, height: 8),
    ]);
  }
}

class _StatementTable extends StatelessWidget {
  final FinanceSummary f;
  final AppStrings strings;
  const _StatementTable({required this.f, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final head = theme.textTheme.labelMedium?.copyWith(color: cs.outline, fontWeight: FontWeight.w800);

    Widget cell(String text, {TextStyle? style, int flex = 3, TextAlign align = TextAlign.right}) => Expanded(
          flex: flex,
          child: Align(
            alignment: align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: style)),
          ),
        );

    // newest first
    final rows = f.months.reversed.toList();
    final totalIncome = f.periodIncome;
    final totalExpense = f.periodExpense;

    return Column(children: [
      Row(children: [
        cell(s.prColMonth, style: head, flex: 3, align: TextAlign.left),
        cell(s.prColIncome, style: head),
        cell(s.prColSpending, style: head),
        cell(s.prColNet, style: head),
      ]),
      const SizedBox(height: 8),
      Divider(height: 1, color: cs.outlineVariant),
      for (final m in rows) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(children: [
            cell(pMonthLong(s, m.month), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), flex: 3, align: TextAlign.left),
            cell(pMoney(m.income), style: theme.textTheme.bodySmall),
            cell(pMoney(m.expense), style: theme.textTheme.bodySmall),
            cell(pMoney(m.net), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: m.net == 0 ? null : (m.net > 0 ? kSettled : kOverdue))),
          ]),
        ),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          cell(s.prTotalRow, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900), flex: 3, align: TextAlign.left),
          cell(pMoney(totalIncome), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
          cell(pMoney(totalExpense), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
          cell(pMoney(totalIncome - totalExpense), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: totalIncome - totalExpense >= 0 ? kSettled : kOverdue)),
        ]),
      ),
    ]);
  }
}
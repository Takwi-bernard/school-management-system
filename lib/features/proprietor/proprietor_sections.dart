import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';

String _money(double v) => '${v.toStringAsFixed(0)} FCFA';
String _shortMonth(DateTime d) => const ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'][d.month - 1];
String _monthLabel(DateTime d) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];

Widget _sectionHeader(BuildContext context, String title, String subtitle) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
    ]),
  );
}

Widget _card(BuildContext context, {required Widget child, IconData? icon}) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard(this.stat);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [stat.color.withValues(alpha: 0.18), stat.color.withValues(alpha: 0.06)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(stat.icon, color: stat.color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stat.value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(stat.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

Widget _chartCardHeader(BuildContext context, IconData icon, String title) {
  final theme = Theme.of(context);
  return Row(children: [
    Icon(icon, size: 18, color: theme.colorScheme.primary),
    const SizedBox(width: 8),
    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
  ]);
}

// ============================================================
// 1. OVERVIEW
// ============================================================

class OverviewSection extends ConsumerWidget {
  final String schoolId;
  const OverviewSection({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(schoolSnapshotProvider(schoolId));
    final financeAsync = ref.watch(financialOverviewProvider(schoolId));
    final actorsAsync = ref.watch(activeActorsProvider(schoolId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(schoolSnapshotProvider(schoolId));
        ref.invalidate(financialOverviewProvider(schoolId));
        ref.invalidate(activeActorsProvider(schoolId));
      },
      child: ListView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        children: [
                    financeAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (f) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NET POSITION · ALL TIME', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(_money(f.netPosition), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.south_west_rounded, color: Colors.white.withValues(alpha: 0.9), size: 16),
                  const SizedBox(width: 4),
                  Text('${_money(f.incomeThisMonth)} in', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 18),
                  Icon(Icons.north_east_rounded, color: Colors.white.withValues(alpha: 0.9), size: 16),
                  const SizedBox(width: 4),
                  Text('${_money(f.expenditureThisMonth)} out', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
                Text('this month', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
              ]),
            ),
          ),
          _sectionHeader(context, 'Overview', 'A snapshot of everything happening right now, live from the database.'),
          snapshotAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('$e'),
            data: (s) => _StatGrid(stats: [
              _Stat('Active students', '${s.totalStudents}', Icons.groups_rounded, theme.colorScheme.primary),
              _Stat('Classes', '${s.totalClasses}', Icons.class_outlined, theme.colorScheme.secondary),
              _Stat('Departments', '${s.totalDepartments}', Icons.account_tree_outlined, Colors.teal),
              _Stat('Awaiting registration fee', '${s.admissionsAwaitingPayment}', Icons.payments_outlined, Colors.redAccent),
              _Stat('Awaiting Principal approval', '${s.admissionsUnderReview}', Icons.fact_check_outlined, Colors.indigo),
            ]),
          ),
          const SizedBox(height: 10),
          financeAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (f) => _StatGrid(stats: [
              _Stat('Income this month', _money(f.incomeThisMonth), Icons.trending_up_rounded, Colors.green.shade700),
              _Stat('Net position (all time)', _money(f.netPosition), Icons.account_balance_wallet_outlined, f.netPosition >= 0 ? Colors.green.shade700 : Colors.red),
            ]),
          ),
          const SizedBox(height: 10),
          actorsAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (a) => _StatGrid(stats: [
              _Stat('Teachers', '${a.teachersApproved}', Icons.school_outlined, Colors.deepPurple),
              _Stat('Parents', '${a.parents}', Icons.family_restroom_outlined, Colors.brown),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.7,
        children: stats.map((s) => _StatCard(s)).toList(),
      );
    });
  }
}

// ============================================================
// 7. AI INSIGHTS
// ============================================================

class AiInsightsSection extends ConsumerStatefulWidget {
  final String schoolId;
  const AiInsightsSection({super.key, required this.schoolId});

  @override
  ConsumerState<AiInsightsSection> createState() => _AiInsightsSectionState();
}

class _AiInsightsSectionState extends ConsumerState<AiInsightsSection> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await ref.read(proprietorRepositoryProvider).generateReport(widget.schoolId);
      ref.invalidate(latestAiReportProvider(widget.schoolId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(latestAiReportProvider(widget.schoolId));

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        Row(children: [
          Expanded(child: _sectionHeader(context, 'AI Insights', 'A plain-language read of how the school is doing, generated from the real numbers above.')),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_generating ? 'Analyzing...' : 'Generate New Analysis'),
          ),
        ]),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (report) {
            if (report == null) {
              return _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.insights_rounded, color: theme.colorScheme.outline, size: 32),
                const SizedBox(height: 10),
                const Text('No analysis has been generated yet. Tap "Generate New Analysis" above.'),
              ]));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Last generated ${report.generatedAt.day}/${report.generatedAt.month}/${report.generatedAt.year} at ${report.generatedAt.hour.toString().padLeft(2, '0')}:${report.generatedAt.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 14),
              _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _chartCardHeader(context, Icons.summarize_rounded, 'Summary'),
                const SizedBox(height: 10),
                Text(report.summary, style: theme.textTheme.bodyMedium),
              ])),
              if (report.strengths.isNotEmpty)
                _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _chartCardHeader(context, Icons.thumb_up_alt_outlined, 'Strengths'),
                  const SizedBox(height: 10),
                  ...report.strengths.map((s) => _bullet(s, Colors.green.shade700)),
                ])),
              if (report.concerns.isNotEmpty)
                _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _chartCardHeader(context, Icons.warning_amber_rounded, 'Concerns'),
                  const SizedBox(height: 10),
                  ...report.concerns.map((s) => _bullet(s, Colors.orange.shade800)),
                ])),
              if (report.recommendations.isNotEmpty)
                _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _chartCardHeader(context, Icons.lightbulb_outline_rounded, 'Recommendations'),
                  const SizedBox(height: 10),
                  ...report.recommendations.map((s) => _bullet(s, Theme.of(context).colorScheme.primary)),
                ])),
            ]);
          },
        ),
      ],
    );
  }

  Widget _bullet(String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(margin: const EdgeInsets.only(top: 6), width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}

// ============================================================
// 2. FINANCIAL OVERVIEW
// ============================================================

class FinancialOverviewSection extends ConsumerWidget {
  final String schoolId;
  const FinancialOverviewSection({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(financialOverviewProvider(schoolId));

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        _sectionHeader(context, 'Financial Overview', 'Income, expenditure, and the school\'s net position over the last 12 months.'),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (f) {
            final maxVal = [
              ...f.incomeTrend.map((p) => p.value),
              ...f.expenditureTrend.map((p) => p.value),
            ].fold(1.0, (a, b) => a > b ? a : b);

            return Column(children: [
              _StatGrid(stats: [
                _Stat('Total income', _money(f.totalIncome), Icons.south_west_rounded, Colors.green.shade700),
                _Stat('Total expenditure', _money(f.totalExpenditure), Icons.north_east_rounded, Colors.red),
                _Stat('Net position', _money(f.netPosition), Icons.account_balance_wallet_outlined, f.netPosition >= 0 ? Colors.green.shade700 : Colors.red),
              ]),
              const SizedBox(height: 8),
              _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Income vs Expenditure (last 12 months)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: BarChart(BarChartData(
                    maxY: maxVal * 1.2,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= f.incomeTrend.length) return const SizedBox();
                          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(_shortMonth(f.incomeTrend[i].month), style: const TextStyle(fontSize: 10)));
                        },
                      )),
                    ),
                    barGroups: List.generate(f.incomeTrend.length, (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: f.incomeTrend[i].value, color: theme.colorScheme.primary, width: 7, borderRadius: BorderRadius.circular(3)),
                      BarChartRodData(toY: f.expenditureTrend[i].value, color: Colors.redAccent, width: 7, borderRadius: BorderRadius.circular(3)),
                    ])),
                  )),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _legendDot(theme.colorScheme.primary), const SizedBox(width: 6), const Text('Income', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 18),
                  _legendDot(Colors.redAccent), const SizedBox(width: 6), const Text('Expenditure', style: TextStyle(fontSize: 12)),
                ]),
              ])),
              _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Income by Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Row(children: [
                  SizedBox(
                    height: 160, width: 160,
                    child: PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(value: f.registrationIncome, color: theme.colorScheme.primary, title: '', radius: 50),
                        PieChartSectionData(value: f.installmentIncome, color: theme.colorScheme.secondary, title: '', radius: 50),
                      ],
                    )),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _pieLegendRow(theme.colorScheme.primary, 'Registration fees', f.registrationIncome, f.totalIncome),
                      const SizedBox(height: 8),
                      _pieLegendRow(theme.colorScheme.secondary, 'Installments', f.installmentIncome, f.totalIncome),
                    ]),
                  ),
                ]),
              ])),
            ]);
          },
        ),
      ],
    );
  }

  Widget _legendDot(Color color) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _pieLegendRow(Color color, String label, double value, double total) {
    final pct = total > 0 ? (value / total * 100) : 0;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
    ]);
  }
}

// ============================================================
// 3. INCOME HISTORY
// ============================================================

class IncomeHistorySection extends ConsumerWidget {
  final String schoolId;
  const IncomeHistorySection({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(incomeHistoryProvider(schoolId));

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        _sectionHeader(context, 'Income History', 'Every successful payment received through the system, most recent first.'),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (rows) {
            if (rows.isEmpty) return Text('No income recorded yet.', style: theme.textTheme.bodyMedium);
            return Column(children: rows.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.south_west_rounded, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.childName.isEmpty ? 'Unknown' : r.childName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${r.purpose} · ${r.method} · ${r.date.day}/${r.date.month}/${r.date.year}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ]),
                ),
                Text(_money(r.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.green)),
              ]),
            )).toList());
          },
        ),
      ],
    );
  }
}

// ============================================================
// 4. EXPENDITURE
// ============================================================

class ExpenditureSection extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  const ExpenditureSection({super.key, required this.schoolId, required this.landing});

  @override
  ConsumerState<ExpenditureSection> createState() => _ExpenditureSectionState();
}

class _ExpenditureSectionState extends ConsumerState<ExpenditureSection> {
  Future<void> _openRecordDialog() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _RecordExpenseDialog(schoolId: widget.schoolId));
    if (saved == true) ref.invalidate(expensesProvider(widget.schoolId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(expensesProvider(widget.schoolId));

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        Row(children: [
          Expanded(child: _sectionHeader(context, 'Expenditure', 'Every expense recorded for this school.')),
          FilledButton.icon(onPressed: _openRecordDialog, icon: const Icon(Icons.add_rounded), label: const Text('Record Expense')),
        ]),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (rows) {
            if (rows.isEmpty) return Text('No expenses recorded yet.', style: theme.textTheme.bodyMedium);

            final byCategory = <String, double>{};
            for (final r in rows) {
              byCategory[r.category] = (byCategory[r.category] ?? 0) + r.amount;
            }
            final colors = [theme.colorScheme.primary, theme.colorScheme.secondary, Colors.orange, Colors.teal, Colors.purple, Colors.brown];
            final categories = byCategory.keys.toList();

            return Column(children: [
              if (categories.isNotEmpty)
                _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('By Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Row(children: [
                    SizedBox(
                      height: 160, width: 160,
                      child: PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: List.generate(categories.length, (i) => PieChartSectionData(
                          value: byCategory[categories[i]], color: colors[i % colors.length], title: '', radius: 50,
                        )),
                      )),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(categories.length, (i) {
                        final total = byCategory.values.fold(0.0, (a, b) => a + b);
                        final pct = total > 0 ? byCategory[categories[i]]! / total * 100 : 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(categories[i], style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                        );
                      })),
                    ),
                  ]),
                ])),
              ...rows.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [ const
                  Icon(Icons.north_east_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.category, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (r.description != null && r.description!.isNotEmpty) Text(r.description!, style: theme.textTheme.bodySmall),
                      Text('${r.paidTo ?? 'Unspecified'} · ${r.method} · ${r.date.day}/${r.date.month}/${r.date.year}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ]),
                  ),
                  Text(_money(r.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.red)),
                ]),
              )),
            ]);
          },
        ),
      ],
    );
  }
}

class _RecordExpenseDialog extends ConsumerStatefulWidget {
  final String schoolId;
  const _RecordExpenseDialog({required this.schoolId});

  @override
  ConsumerState<_RecordExpenseDialog> createState() => _RecordExpenseDialogState();
}

class _RecordExpenseDialogState extends ConsumerState<_RecordExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _paidTo = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'cash';
  XFile? _receipt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _category.dispose();
    _description.dispose();
    _amount.dispose();
    _paidTo.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _receipt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final repo = ref.read(proprietorRepositoryProvider);
      String? receiptUrl;
      if (_receipt != null) {
        final bytes = await _receipt!.readAsBytes();
        final ext = _receipt!.name.contains('.') ? _receipt!.name.split('.').last : 'jpg';
        receiptUrl = await repo.uploadReceipt(schoolId: widget.schoolId, bytes: bytes, extension: ext);
      }
      await repo.recordExpense(
        schoolId: widget.schoolId,
        category: _category.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        amount: amount,
        date: _date,
        paymentMethod: _method,
        paidTo: _paidTo.text.trim().isEmpty ? null : _paidTo.text.trim(),
        receiptUrl: receiptUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record an Expense'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category (e.g. Utilities, Maintenance)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
              const SizedBox(height: 10),
              TextFormField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (FCFA)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _paidTo, decoration: const InputDecoration(labelText: 'Paid to (vendor / person, optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                  DropdownMenuItem(value: 'mtn_momo', child: Text('MTN Mobile Money')),
                  DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
                ],
                onChanged: (v) => setState(() => _method = v ?? 'cash'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickReceipt,
                icon: const Icon(Icons.receipt_outlined),
                label: Text(_receipt == null ? 'Attach receipt (optional)' : 'Receipt attached'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================
// 5. GROWTH & STATISTICS
// ============================================================

class GrowthStatisticsSection extends ConsumerWidget {
  final String schoolId;
  const GrowthStatisticsSection({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final growthAsync = ref.watch(growthByYearProvider(schoolId));
    final enrollmentAsync = ref.watch(enrollmentByClassProvider(schoolId));

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        _sectionHeader(context, 'Growth & Statistics', 'How the school\'s population has changed year over year, and current enrollment by class.'),
        growthAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (years) {
            if (years.isEmpty) return Text('No academic years recorded yet.', style: theme.textTheme.bodyMedium);
            final maxVal = years.map((y) => y.studentCount).fold(1, (a, b) => a > b ? a : b).toDouble();

            String growthLine = '';
            if (years.length >= 2) {
              final prev = years[years.length - 2];
              final curr = years.last;
              final diff = curr.studentCount - prev.studentCount;
              growthLine = '${prev.yearName}: ${prev.studentCount} students  →  ${curr.yearName}: ${curr.studentCount} students  (${diff >= 0 ? '+' : ''}$diff)';
            }

            return _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Student Population by Academic Year', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (growthLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(growthLine, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  maxY: maxVal * 1.25,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= years.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(years[i].yearName, style: const TextStyle(fontSize: 10)));
                      },
                    )),
                  ),
                  barGroups: List.generate(years.length, (i) => BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: years[i].studentCount.toDouble(),
                      color: years[i].isCurrent ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      width: 24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ])),
                )),
              ),
            ]));
          },
        ),
        Text('Enrollment by Class (current year)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        enrollmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (classes) {
            if (classes.isEmpty) return Text('No classes configured yet.', style: theme.textTheme.bodySmall);
            return Column(children: classes.map((c) {
              final ratio = c.capacity > 0 ? (c.studentCount / c.capacity).clamp(0.0, 1.0) : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${c.className} · ${c.departmentName}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${c.studentCount}/${c.capacity}', style: theme.textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 7)),
                ]),
              );
            }).toList());
          },
        ),
      ],
    );
  }
}

// ============================================================
// 6. SCHOOL ACTORS
// ============================================================

class ActiveActorsSection extends ConsumerWidget {
  final String schoolId;
  const ActiveActorsSection({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(activeActorsProvider(schoolId));

    return ListView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      children: [
        _sectionHeader(context, 'School Actors', 'Everyone currently participating in the school\'s system.'),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (a) {
            final total = (a.principals + a.secretaries + a.proprietors + a.teachersApproved + a.parents).toDouble();
            final slices = [
              (label: 'Principals', value: a.principals, color: theme.colorScheme.primary),
              (label: 'Secretaries', value: a.secretaries, color: theme.colorScheme.secondary),
              (label: 'Proprietors', value: a.proprietors, color: Colors.teal),
              (label: 'Teachers', value: a.teachersApproved, color: Colors.deepPurple),
              (label: 'Parents', value: a.parents, color: Colors.brown),
            ];

            return Column(children: [
              _StatGrid(stats: [
                _Stat('Principals', '${a.principals}', Icons.badge_outlined, theme.colorScheme.primary),
                _Stat('Secretaries', '${a.secretaries}', Icons.badge_outlined, theme.colorScheme.secondary),
                _Stat('Proprietors', '${a.proprietors}', Icons.badge_outlined, Colors.teal),
                _Stat('Teachers (approved)', '${a.teachersApproved}', Icons.school_outlined, Colors.deepPurple),
                _Stat('Teachers (pending)', '${a.teachersPending}', Icons.hourglass_top_rounded, Colors.orange),
                _Stat('Parents', '${a.parents}', Icons.family_restroom_outlined, Colors.brown),
              ]),
              const SizedBox(height: 10),
              if (total > 0)
                _card(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Who makes up the school', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Row(children: [
                    SizedBox(
                      height: 170, width: 170,
                      child: PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: slices.where((s) => s.value > 0).map((s) => PieChartSectionData(value: s.value.toDouble(), color: s.color, title: '', radius: 50)).toList(),
                      )),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: slices.where((s) => s.value > 0).map((s) {
                        final pct = s.value / total * 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                        );
                      }).toList()),
                    ),
                  ]),
                ])),
            ]);
          },
        ),
      ],
    );
  }
}
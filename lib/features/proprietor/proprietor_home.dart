import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_providers.dart';
import '../landing/landing_model.dart';
import '../landing/landing_providers.dart';
import '../parent/parent_models.dart' show buildSchoolTheme;
import 'proprietor_charts.dart';
import 'proprietor_expenses.dart';
import 'proprietor_finance.dart';
import 'proprietor_format.dart';
import 'proprietor_income.dart';
import 'proprietor_insights.dart';
import 'proprietor_models.dart';
import 'proprietor_profile.dart';
import 'proprietor_providers.dart';
import 'proprietor_reports.dart';
import 'proprietor_school.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';

const int kPrNavOverview = 0;
const int kPrNavFinance = 1;
const int kPrNavIncome = 2;
const int kPrNavExpenses = 3;
const int kPrNavSchool = 4;
const int kPrNavInsights = 5;
const int kPrNavReports = 6;
const int kPrNavProfile = 7;

class ProprietorHome extends ConsumerWidget {
  const ProprietorHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider);
    final strings = AppStrings(ref.watch(activeLocaleProvider));

    return landing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (school) {
        final sessionAsync = ref.watch(sessionProfileProvider(school.schoolId));
        return sessionAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (session) {
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/sign-in'));
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (session.role != 'proprietor') {
              return Scaffold(
                body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(strings.prWrongRole, textAlign: TextAlign.center))),
              );
            }
            return Theme(
              data: buildSchoolTheme(school.primaryColor, school.secondaryColor),
              child: _ProprietorShell(landing: school, strings: strings),
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final String description;
  final int index;
  const _NavItem({required this.icon, required this.activeIcon, required this.title, required this.description, required this.index});
}

class _ProprietorShell extends ConsumerStatefulWidget {
  final LandingModel landing;
  final AppStrings strings;
  const _ProprietorShell({required this.landing, required this.strings});

  @override
  ConsumerState<_ProprietorShell> createState() => _ProprietorShellState();
}

class _ProprietorShellState extends ConsumerState<_ProprietorShell> {
  int _selected = kPrNavOverview;
  bool _signingOut = false;

  AppStrings get _s => widget.strings;
  String get _schoolId => widget.landing.schoolId;

  void _navigate(int i) => setState(() => _selected = i);

  List<_NavItem> _items() => [
        _NavItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, title: _s.prOverview, description: _s.prOverviewDesc, index: kPrNavOverview),
        _NavItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, title: _s.prFinance, description: _s.prFinanceDesc, index: kPrNavFinance),
        _NavItem(icon: Icons.south_west_rounded, activeIcon: Icons.south_west_rounded, title: _s.prIncome, description: _s.prIncomeDesc, index: kPrNavIncome),
        _NavItem(icon: Icons.north_east_rounded, activeIcon: Icons.north_east_rounded, title: _s.prExpenses, description: _s.prExpensesDesc, index: kPrNavExpenses),
        _NavItem(icon: Icons.school_outlined, activeIcon: Icons.school_rounded, title: _s.prSchool, description: _s.prSchoolDesc, index: kPrNavSchool),
        _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, title: _s.prInsights, description: _s.prInsightsDesc, index: kPrNavInsights),
        _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description_rounded, title: _s.prReports, description: _s.prReportsDesc, index: kPrNavReports),
        _NavItem(icon: Icons.account_circle_outlined, activeIcon: Icons.account_circle_rounded, title: _s.prProfile, description: _s.prProfileDesc, index: kPrNavProfile),
      ];

  Widget _bodyFor(int index) {
    switch (index) {
      case kPrNavFinance:
        return ProprietorFinancePage(strings: _s);
      case kPrNavIncome:
        return ProprietorIncomePage(schoolId: _schoolId, strings: _s);
      case kPrNavExpenses:
        return ProprietorExpensesPage(schoolId: _schoolId, strings: _s);
      case kPrNavSchool:
        return ProprietorSchoolPage(strings: _s);
      case kPrNavInsights:
        return ProprietorInsightsPage(schoolId: _schoolId, strings: _s);
      case kPrNavReports:
        return ProprietorReportsPage(schoolId: _schoolId, landing: widget.landing, strings: _s);
      case kPrNavProfile:
        return ProprietorProfilePage(strings: _s);
      default:
        return ProprietorOverviewPage(schoolId: _schoolId, strings: _s, onNavigate: _navigate);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_s.signOutConfirmTitle),
        content: Text(_s.signOutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(_s.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    final started = DateTime.now();
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    // Keeps every Proprietor number live for as long as the shell is open.
    ref.watch(proprietorRealtimeProvider(_schoolId));

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = ref.watch(proprietorProfileProvider).valueOrNull;
    final pendingTeachers = ref.watch(schoolStatsProvider).valueOrNull?.teachersPending ?? 0;
    final items = _items();

    Widget sidebar({required bool collapsed, required bool isDrawer}) => _Sidebar(
          items: items,
          selected: _selected,
          collapsed: collapsed,
          profile: profile,
          pendingTeachers: pendingTeachers,
          strings: _s,
          onPick: (i) {
            if (isDrawer) Navigator.pop(context);
            _navigate(i);
          },
          onSignOut: () {
            if (isDrawer) Navigator.pop(context);
            _confirmSignOut();
          },
        );

    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(_selected), child: _bodyFor(_selected)),
    );

    return Stack(fit: StackFit.expand, children: [
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 760;
        final isTablet = width >= 760 && width < 1100;

        final appBar = AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: isMobile,
          titleSpacing: 14,
          shape: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
          title: Row(children: [
            if (widget.landing.logoUrl.isNotEmpty)
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: cs.outlineVariant)),
                child: Image.network(widget.landing.logoUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: cs.primary, size: 18)),
              ),
            Expanded(
              child: Text(widget.landing.schoolName, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ]),
          actions: [
            if (!isMobile) Padding(padding: const EdgeInsets.only(right: 16), child: PrLiveDot(label: _s.prLive, color: kSettled)),
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _navigate(kPrNavProfile),
                  child: PrAvatar(photoUrl: profile?.photoUrl, name: profile?.fullName ?? '', radius: 16),
                ),
              ),
          ],
        );

        if (isMobile) {
          return Scaffold(
            appBar: appBar,
            drawer: Drawer(child: sidebar(collapsed: false, isDrawer: true)),
            body: body,
          );
        }

        return Scaffold(
          appBar: appBar,
          body: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isTablet ? 84 : 292,
              child: sidebar(collapsed: isTablet, isDrawer: false),
            ),
            Expanded(child: ClipRect(child: body)),
          ]),
        );
      }),
      if (_signingOut)
        Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(_s.signingOut, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

// ============================================================ sidebar

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selected;
  final bool collapsed;
  final ProprietorProfile? profile;
  final int pendingTeachers;
  final AppStrings strings;
  final void Function(int) onPick;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.collapsed,
    required this.profile,
    required this.pendingTeachers,
    required this.strings,
    required this.onPick,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Derived from the theme's inverse surface: contrast is guaranteed
    // against any school's palette.
    final bg = theme.colorScheme.inverseSurface;
    final fg = theme.colorScheme.onInverseSurface;

    Widget iconFor(_NavItem item, bool active) {
      final icon = Icon(active ? item.activeIcon : item.icon, color: active ? fg : fg.withValues(alpha: 0.72), size: 22);
      if (item.index == kPrNavSchool && pendingTeachers > 0) return Badge(label: Text('$pendingTeachers'), child: icon);
      return icon;
    }

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 12 : 20, 20, collapsed ? 12 : 20, 16),
            child: collapsed
                ? Center(child: PrAvatar(photoUrl: profile?.photoUrl, name: profile?.fullName ?? '', radius: 22, onDark: true))
                : Row(children: [
                    PrAvatar(photoUrl: profile?.photoUrl, name: profile?.fullName ?? '', radius: 24, onDark: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(strings.welcomeBack, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12)),
                        Text(
                          profile?.fullName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(strings.prRole, style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 11.5)),
                      ]),
                    ),
                  ]),
          ),
          Divider(color: fg.withValues(alpha: 0.12), height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 12),
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _NavTile(
                      item: item,
                      active: item.index == selected,
                      collapsed: collapsed,
                      fg: fg,
                      icon: iconFor(item, item.index == selected),
                      onTap: () => onPick(item.index),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: fg.withValues(alpha: 0.12), height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 10),
            child: collapsed
                ? Tooltip(
                    message: strings.signOut,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onSignOut,
                      child: SizedBox(height: 48, child: Icon(Icons.logout_rounded, color: fg.withValues(alpha: 0.8))),
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onSignOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(children: [
                        Icon(Icons.logout_rounded, color: fg.withValues(alpha: 0.8), size: 20),
                        const SizedBox(width: 14),
                        Text(strings.signOut, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool collapsed;
  final Color fg;
  final Widget icon;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.active, required this.collapsed, required this.fg, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(color: active ? fg.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: collapsed
          ? SizedBox(height: 48, child: Center(child: icon))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: active ? fg : fg.withValues(alpha: 0.82), fontWeight: active ? FontWeight.w800 : FontWeight.w600, fontSize: 14),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: active ? 18 : 0,
                  decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4)),
                ),
              ]),
            ),
    );
    final inkwell = InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: tile);
    return collapsed ? Tooltip(message: item.title, child: inkwell) : inkwell;
  }
}

// ============================================================ overview

class _Alert {
  final IconData icon;
  final String text;
  final Color color;
  final int? target;
  const _Alert({required this.icon, required this.text, required this.color, this.target});
}

class ProprietorOverviewPage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  final void Function(int) onNavigate;
  const ProprietorOverviewPage({super.key, required this.schoolId, required this.strings, required this.onNavigate});

  List<_Alert> _alerts(FinanceSummary f, SchoolStats st, List<ExpenseBudget> budgets) {
    final out = <_Alert>[];
    for (final b in budgets) {
      if (b.monthlyLimit <= 0) continue;
      final spent = f.byCategoryThisMonth.where((c) => c.category == b.category).fold<double>(0, (a, c) => a + c.total);
      if (spent > b.monthlyLimit) {
        out.add(_Alert(icon: Icons.warning_amber_rounded, text: strings.prOverBudgetAlert(b.category), color: kOverdue, target: kPrNavExpenses));
      }
    }
    final d = pDelta(f.expenseThisMonth, f.expensePrevMonth);
    if (d != null && d > 25) {
      out.add(_Alert(icon: Icons.trending_up_rounded, text: strings.prSpendingUpAlert, color: kPending, target: kPrNavFinance));
    }
    if (st.teachersPending > 0) {
      out.add(_Alert(icon: Icons.how_to_reg_outlined, text: strings.prPendingTeachersAlert(st.teachersPending), color: kPending, target: kPrNavSchool));
    }
    if (st.awaitingPayment > 0) {
      out.add(_Alert(icon: Icons.hourglass_top_rounded, text: strings.prAdmissionsAlert(st.awaitingPayment), color: kPending, target: kPrNavSchool));
    }
    for (final c in st.byClass) {
      if (c.isFull) {
        out.add(_Alert(icon: Icons.event_seat_outlined, text: strings.prCapacityAlert(c.className), color: kPending, target: kPrNavSchool));
        break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final financeAsync = ref.watch(financeProvider(12));
    final statsAsync = ref.watch(schoolStatsProvider);
    final budgets = ref.watch(budgetsProvider(schoolId)).valueOrNull ?? const <ExpenseBudget>[];
    final profile = ref.watch(proprietorProfileProvider).valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(financeProvider);
      ref.invalidate(schoolStatsProvider);
      ref.invalidate(budgetsProvider(schoolId));
      try {
        await Future.wait([ref.read(financeProvider(12).future), ref.read(schoolStatsProvider.future)]);
      } catch (_) {}
    }

    final header = PrHeader(
      title: '${pGreeting(s)}${(profile?.fullName ?? '').isEmpty ? '' : ', ${profile!.fullName.split(' ').first}'}',
      subtitle: s.prOverviewDesc,
      trailing: IconButton.filledTonal(onPressed: refresh, tooltip: s.prRefresh, icon: const Icon(Icons.refresh_rounded)),
    );

    if (financeAsync.isLoading && !financeAsync.hasValue || statsAsync.isLoading && !statsAsync.hasValue) {
      return const PrPageSkeleton();
    }
    if (financeAsync.hasError && !financeAsync.hasValue) {
      return PrError(error: financeAsync.error!, strings: s, onRetry: () => ref.invalidate(financeProvider));
    }
    if (statsAsync.hasError && !statsAsync.hasValue) {
      return PrError(error: statsAsync.error!, strings: s, onRetry: () => ref.invalidate(schoolStatsProvider));
    }
    final f = financeAsync.requireValue;
    final st = statsAsync.requireValue;
    final alerts = _alerts(f, st, budgets);
    final dayLabels = f.days.map((d) => '${d.day.day}/${d.day.month}').toList();
    final monthLabels = f.months.map((m) => pMonthShort(s, m.month)).toList();
    final spend = prSpendColor(context);

    return PrPage(
      onRefresh: refresh,
      children: [
        header,
        PrReveal(child: _Hero(f: f, strings: s)),
        const SizedBox(height: 16),
        PrGrid(minTile: 250, children: [
          PrStatTile(
            icon: Icons.south_west_rounded,
            label: s.prIncomeThisMonth,
            value: f.incomeThisMonth,
            format: pMoney,
            spark: f.days.map((d) => d.income).toList(),
            footer: PrDeltaChip(delta: pDelta(f.incomeThisMonth, f.incomePrevMonth), strings: s),
            onTap: () => onNavigate(kPrNavIncome),
          ),
          PrStatTile(
            icon: Icons.north_east_rounded,
            label: s.prExpenseThisMonth,
            value: f.expenseThisMonth,
            format: pMoney,
            spark: f.days.map((d) => d.expense).toList(),
            footer: PrDeltaChip(delta: pDelta(f.expenseThisMonth, f.expensePrevMonth), strings: s, higherIsBetter: false),
            onTap: () => onNavigate(kPrNavExpenses),
          ),
          PrStatTile(
            icon: Icons.bolt_rounded,
            label: s.prCollectedToday,
            value: f.incomeToday,
            format: pMoney,
            onTap: () => onNavigate(kPrNavIncome),
          ),
          PrStatTile(
            icon: Icons.groups_2_outlined,
            label: s.prActiveStudents,
            value: st.students.toDouble(),
            format: (v) => v.round().toString(),
            footer: Text(
              st.capacity > 0 ? '${st.capacityUsed.toStringAsFixed(0)}% ${s.prCapacityUsed.toLowerCase()}' : '${st.classes} ${s.prClasses.toLowerCase()}',
              style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
            ),
            onTap: () => onNavigate(kPrNavSchool),
          ),
        ]),
        const SizedBox(height: 16),
        if (alerts.isNotEmpty) ...[
          PrSectionTitle(title: s.prNeedsAttention),
          PrReveal(child: _AlertList(alerts: alerts, onNavigate: onNavigate)),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final left = PrChartCard(
            title: s.prIncomeVsSpending,
            subtitle: s.prIncomeVsSpendingDesc,
            legend: [PrLegendItem(label: s.prIncomeSeries, color: cs.primary), PrLegendItem(label: s.prSpendingSeries, color: spend)],
            child: f.months.every((m) => m.income == 0 && m.expense == 0)
                ? SizedBox(height: 200, child: PrEmpty(icon: Icons.bar_chart_rounded, title: s.prNoDataYet))
                : PrBarChart(
                    labels: monthLabels,
                    series: [
                      PrBarSeries(name: s.prIncomeSeries, color: cs.primary, values: f.months.map((m) => m.income).toList()),
                      PrBarSeries(name: s.prSpendingSeries, color: spend, values: f.months.map((m) => m.expense).toList()),
                    ],
                    axisFormat: pCompact,
                    tipFor: (i) => PrTip(
                      title: pMonthLong(s, f.months[i].month),
                      rows: [
                        PrTipRow(label: s.prIncomeSeries, value: pMoney(f.months[i].income), color: cs.primary),
                        PrTipRow(label: s.prSpendingSeries, value: pMoney(f.months[i].expense), color: spend),
                      ],
                    ),
                  ),
          );
          final right = PrChartCard(
            title: s.prCashFlow30,
            subtitle: s.prCashFlow30Desc,
            legend: [PrLegendItem(label: s.prIncomeSeries, color: cs.primary), PrLegendItem(label: s.prSpendingSeries, color: spend)],
            child: f.days.every((d) => d.income == 0 && d.expense == 0)
                ? SizedBox(height: 200, child: PrEmpty(icon: Icons.show_chart_rounded, title: s.prNoDataYet))
                : PrLineChart(
                    labels: dayLabels,
                    series: [
                      PrLineSeries(name: s.prIncomeSeries, color: cs.primary, values: f.days.map((d) => d.income).toList()),
                      PrLineSeries(name: s.prSpendingSeries, color: spend, values: f.days.map((d) => d.expense).toList()),
                    ],
                    axisFormat: pCompact,
                    tipFor: (i) => PrTip(
                      title: pDate(f.days[i].day),
                      rows: [
                        PrTipRow(label: s.prIncomeSeries, value: pMoney(f.days[i].income), color: cs.primary),
                        PrTipRow(label: s.prSpendingSeries, value: pMoney(f.days[i].expense), color: spend),
                      ],
                    ),
                  ),
          );
          if (!wide) return Column(children: [PrReveal(child: left), const SizedBox(height: 14), PrReveal(index: 1, child: right)]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: PrReveal(child: left)),
            const SizedBox(width: 14),
            Expanded(child: PrReveal(index: 1, child: right)),
          ]);
        }),
        const SizedBox(height: 16),
        _PipelineAndCapacity(st: st, strings: s, onNavigate: onNavigate),
        const SizedBox(height: 8),
        PrSectionTitle(title: s.prQuickLinks),
        PrGrid(minTile: 230, max: 4, children: [
          _QuickLink(icon: Icons.insights_rounded, title: s.prFinance, desc: s.prFinanceDesc, onTap: () => onNavigate(kPrNavFinance)),
          _QuickLink(icon: Icons.add_card_rounded, title: s.prRecordExpense, desc: s.prExpensesDesc, onTap: () => onNavigate(kPrNavExpenses)),
          _QuickLink(icon: Icons.auto_awesome_rounded, title: s.prInsights, desc: s.prInsightsDesc, onTap: () => onNavigate(kPrNavInsights)),
          _QuickLink(icon: Icons.description_rounded, title: s.prReports, desc: s.prReportsDesc, onTap: () => onNavigate(kPrNavReports)),
        ]),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final FinanceSummary f;
  final AppStrings strings;
  const _Hero({required this.f, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final on = cs.onPrimary;
    final positive = f.netThisMonth >= 0;
    final total = f.totalIncome + f.totalExpense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), cs.primary)]),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 620;
        final figures = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(strings.prHeroLabel, style: theme.textTheme.labelLarge?.copyWith(color: on.withValues(alpha: 0.78), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PrCountUp(value: f.net, format: pMoney, style: theme.textTheme.displaySmall?.copyWith(color: on, fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
          const SizedBox(height: 6),
          Text(strings.prHeroHint, style: theme.textTheme.bodySmall?.copyWith(color: on.withValues(alpha: 0.72), height: 1.4)),
        ]);
        final breakdown = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PrSplitBar(parts: [PrSlice(label: '', value: f.totalIncome, color: on), PrSlice(label: '', value: f.totalExpense, color: on.withValues(alpha: 0.35))], height: 10),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _HeroFigure(label: strings.prTotalIncome, value: pMoney(f.totalIncome), dot: on)),
            Expanded(child: _HeroFigure(label: strings.prTotalExpense, value: pMoney(f.totalExpense), dot: on.withValues(alpha: 0.35))),
          ]),
          if (total > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: on.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: on),
                const SizedBox(width: 8),
                Flexible(child: Text(positive ? strings.prSurplusNote : strings.prDeficitNote, style: theme.textTheme.labelMedium?.copyWith(color: on, fontWeight: FontWeight.w700))),
              ]),
            ),
          ],
        ]);
        if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [figures, const SizedBox(height: 20), breakdown]);
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 5, child: figures),
          const SizedBox(width: 28),
          Expanded(flex: 5, child: breakdown),
        ]);
      }),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final String label;
  final String value;
  final Color dot;
  const _HeroFigure({required this.label, required this.value, required this.dot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: on.withValues(alpha: 0.78)), overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: theme.textTheme.titleMedium?.copyWith(color: on, fontWeight: FontWeight.w800))),
    ]);
  }
}

class _AlertList extends StatelessWidget {
  final List<_Alert> alerts;
  final void Function(int) onNavigate;
  const _AlertList({required this.alerts, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        for (var i = 0; i < alerts.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          InkWell(
            onTap: alerts[i].target == null ? null : () => onNavigate(alerts[i].target!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: alerts[i].color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(alerts[i].icon, size: 16, color: alerts[i].color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(alerts[i].text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                if (alerts[i].target != null) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _PipelineAndCapacity extends StatelessWidget {
  final SchoolStats st;
  final AppStrings strings;
  final void Function(int) onNavigate;
  const _PipelineAndCapacity({required this.st, required this.strings, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;

    final pipeline = PrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.prAdmissionPipeline, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(s.prAdmissionPipelineDesc, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.35)),
        const SizedBox(height: 18),
        _PipelineRow(icon: Icons.hourglass_top_rounded, label: s.prAwaitingFee, count: st.awaitingPayment, total: st.awaitingPayment + st.underReview),
        const SizedBox(height: 14),
        _PipelineRow(icon: Icons.fact_check_outlined, label: s.prUnderReview, count: st.underReview, total: st.awaitingPayment + st.underReview),
      ]),
    );

    final capacity = PrCard(
      child: Row(children: [
        PrGauge(
          value: st.capacity <= 0 ? 0 : st.students / st.capacity,
          color: cs.primary,
          size: 128,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PrCountUp(value: st.capacityUsed, format: (v) => '${v.round()}%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.prCapacityUsed, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${st.students} ${s.prOf} ${st.capacity} ${s.prStudentsShort}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${st.classes} ${s.prClasses.toLowerCase()} · ${st.departments} ${s.prDepartments.toLowerCase()}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 10),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () => onNavigate(kPrNavSchool),
              child: Text('${s.prSchool}  →'),
            ),
          ]),
        ),
      ]),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 820) return Column(children: [PrReveal(child: capacity), const SizedBox(height: 14), PrReveal(index: 1, child: pipeline)]);
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: PrReveal(child: capacity)),
          const SizedBox(width: 14),
          Expanded(child: PrReveal(index: 1, child: pipeline)),
        ]),
      );
    });
  }
}

class _PipelineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int total;
  const _PipelineRow({required this.icon, required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        PrCountUp(value: count.toDouble(), format: (v) => v.round().toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 8),
      PrProgressBar(value: total <= 0 ? 0 : count / total, height: 6),
    ]);
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.title, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(desc, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
      ]),
    );
  }
}
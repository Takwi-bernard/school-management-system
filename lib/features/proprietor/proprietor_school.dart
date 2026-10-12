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

/// Enrollment, capacity, growth, gender balance and the people behind
/// the school, from one aggregated call.
class ProprietorSchoolPage extends ConsumerWidget {
  final AppStrings strings;
  const ProprietorSchoolPage({super.key, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final async = ref.watch(schoolStatsProvider);

    Future<void> refresh() async {
      ref.invalidate(schoolStatsProvider);
      try {
        await ref.read(schoolStatsProvider.future);
      } catch (_) {}
    }

    if (async.isLoading && !async.hasValue) return const PrPageSkeleton();
    if (async.hasError && !async.hasValue) {
      return PrError(error: async.error!, strings: s, onRetry: () => ref.invalidate(schoolStatsProvider));
    }
    final st = async.requireValue;

    return PrPage(
      onRefresh: refresh,
      children: [
        PrHeader(title: s.prSchoolTitle, subtitle: s.prSchoolDesc),
        _Content(st: st, strings: s),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final SchoolStats st;
  final AppStrings strings;
  const _Content({required this.st, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = prPalette(context);

    // ---------- growth
    final years = st.byYear;
    String? growthNote;
    if (years.length >= 2) {
      final prev = years[years.length - 2].count;
      final last = years.last.count;
      final d = pDelta(last.toDouble(), prev.toDouble());
      if (d != null) growthNote = s.prGrowthNote(pSigned(d));
    }

    final kpis = PrGrid(minTile: 220, children: [
      PrStatTile(icon: Icons.groups_2_outlined, label: s.prActiveStudents, value: st.students.toDouble(), format: (v) => v.round().toString()),
      PrStatTile(icon: Icons.class_outlined, label: s.prClasses, value: st.classes.toDouble(), format: (v) => v.round().toString()),
      PrStatTile(icon: Icons.account_tree_outlined, label: s.prDepartments, value: st.departments.toDouble(), format: (v) => v.round().toString()),
      PrStatTile(
        icon: Icons.event_seat_outlined,
        label: s.prCapacityUsed,
        value: st.capacityUsed,
        format: (v) => '${v.round()}%',
        footer: PrProgressBar(value: st.capacityUsed / 100, height: 6),
      ),
    ]);

    // ---------- enrollment by class
    final byClass = PrChartCard(
      title: s.prEnrollmentByClass,
      subtitle: s.prEnrollmentByClassDesc,
      child: st.byClass.isEmpty
          ? SizedBox(height: 160, child: PrEmpty(icon: Icons.class_outlined, title: s.prNoClasses))
          : Column(children: [
              for (var i = 0; i < st.byClass.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _ClassRow(c: st.byClass[i], strings: s),
              ],
            ]),
    );

    // ---------- departments
    final deptTotal = st.byDepartment.fold<int>(0, (a, d) => a + d.count);
    final departments = PrChartCard(
      title: s.prEnrollmentByDept,
      child: deptTotal <= 0
          ? SizedBox(height: 160, child: PrEmpty(icon: Icons.pie_chart_outline_rounded, title: s.prNoDataYet))
          : Column(children: [
              Center(
                child: PrDonut(
                  slices: [for (var i = 0; i < st.byDepartment.length; i++) PrSlice(label: st.byDepartment[i].department, value: st.byDepartment[i].count.toDouble(), color: palette[i % palette.length])],
                  center: (h) => _Center(
                    title: h == null ? s.prStudentsShort : (st.byDepartment[h].department.isEmpty ? '—' : st.byDepartment[h].department),
                    value: h == null ? '$deptTotal' : '${st.byDepartment[h].count}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < st.byDepartment.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _Legend(
                  color: palette[i % palette.length],
                  label: st.byDepartment[i].department.isEmpty ? '—' : st.byDepartment[i].department,
                  value: '${st.byDepartment[i].count}',
                  share: deptTotal == 0 ? 0 : st.byDepartment[i].count / deptTotal,
                ),
              ],
            ]),
    );

    // ---------- growth
    final growth = PrChartCard(
      title: s.prGrowth,
      subtitle: s.prGrowthDesc,
      legend: years.any((y) => y.isCurrent) ? [PrLegendItem(label: s.prCurrentYear, color: cs.primary), PrLegendItem(label: s.prYoY, color: cs.primary.withValues(alpha: 0.4))] : const [],
      child: years.isEmpty
          ? SizedBox(height: 160, child: PrEmpty(icon: Icons.timeline_rounded, title: s.prNoYears))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PrBarChart(
                height: 240,
                labels: years.map((y) => y.yearName).toList(),
                series: [
                  PrBarSeries(
                    name: s.prStudentsShort,
                    color: cs.primary,
                    values: years.map((y) => y.count.toDouble()).toList(),
                    valueColors: years.map((y) => y.isCurrent ? cs.primary : cs.primary.withValues(alpha: 0.4)).toList(),
                  ),
                ],
                axisFormat: (v) => v.round().toString(),
                tipFor: (i) => PrTip(title: years[i].yearName, rows: [PrTipRow(label: s.prStudentsShort, value: '${years[i].count}', color: cs.primary)]),
              ),
              if (growthNote != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.trending_up_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(growthNote, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                ]),
              ],
            ]),
    );

    // ---------- gender
    final genderTotal = st.byGender.fold<int>(0, (a, g) => a + g.count);
    String genderLabel(String g) => g == 'male' ? s.prMale : (g == 'female' ? s.prFemale : s.prUnknown);
    final gender = PrChartCard(
      title: s.prGender,
      child: genderTotal <= 0
          ? SizedBox(height: 160, child: PrEmpty(icon: Icons.pie_chart_outline_rounded, title: s.prNoDataYet))
          : Column(children: [
              Center(
                child: PrDonut(
                  slices: [for (var i = 0; i < st.byGender.length; i++) PrSlice(label: genderLabel(st.byGender[i].gender), value: st.byGender[i].count.toDouble(), color: palette[(i * 2) % palette.length])],
                  center: (h) => _Center(
                    title: h == null ? s.prStudentsShort : genderLabel(st.byGender[h].gender),
                    value: h == null ? '$genderTotal' : pPercent(st.byGender[h].count / genderTotal * 100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < st.byGender.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _Legend(color: palette[(i * 2) % palette.length], label: genderLabel(st.byGender[i].gender), value: '${st.byGender[i].count}', share: st.byGender[i].count / genderTotal),
              ],
            ]),
    );

    // ---------- community
    final community = [
      _Person(Icons.workspace_premium_outlined, s.prProprietors, st.proprietors, false),
      _Person(Icons.shield_outlined, s.prPrincipals, st.principals, false),
      _Person(Icons.assignment_ind_outlined, s.prSecretaries, st.secretaries, false),
      _Person(Icons.menu_book_outlined, s.prTeachers, st.teachersApproved, false),
      _Person(Icons.how_to_reg_outlined, s.prTeachersPending, st.teachersPending, true),
      _Person(Icons.family_restroom_outlined, s.prParents, st.parents, false),
    ];

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      Widget twoUp(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => wide
          ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: flexA, child: a), const SizedBox(width: 14), Expanded(flex: flexB, child: b)]))
          : Column(children: [a, const SizedBox(height: 14), b]);

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        kpis,
        const SizedBox(height: 14),
        twoUp(PrReveal(child: byClass), PrReveal(index: 1, child: departments), flexA: 6, flexB: 4),
        const SizedBox(height: 14),
        twoUp(PrReveal(child: growth), PrReveal(index: 1, child: gender), flexA: 6, flexB: 4),
        PrSectionTitle(title: s.prTeam, subtitle: s.prTeamDesc),
        PrGrid(minTile: 200, max: 3, children: [for (final p in community) _PersonCard(p: p)]),
      ]);
    });
  }
}

class _Person {
  final IconData icon;
  final String label;
  final int count;
  final bool warn;
  const _Person(this.icon, this.label, this.count, this.warn);
}

class _PersonCard extends StatelessWidget {
  final _Person p;
  const _PersonCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = (p.warn && p.count > 0) ? kPending : cs.primary;
    return PrCard(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(12)),
          child: Icon(p.icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PrCountUp(value: p.count.toDouble(), format: (v) => v.round().toString(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final ClassFill c;
  final AppStrings strings;
  const _ClassRow({required this.c, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final color = c.isFull ? kPending : cs.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: c.className, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (c.department.isNotEmpty) TextSpan(text: '  ${c.department}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (c.isFull)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: kPending.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(s.prFull, style: theme.textTheme.labelSmall?.copyWith(color: kPending, fontWeight: FontWeight.w800)),
            ),
          ),
        Text(c.capacity > 0 ? '${c.count} / ${c.capacity}' : '${c.count}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 7),
      PrProgressBar(value: c.capacity > 0 ? c.fillRate : (c.count > 0 ? 1 : 0), color: color, height: 8),
      if (c.capacity > 0 && !c.isFull)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c.seatsLeft} ${s.prSeatsLeft}', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline))),
    ]);
  }
}

class _Center extends StatelessWidget {
  final String title;
  final String value;
  const _Center({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final double share;
  const _Legend({required this.color, required this.label, required this.value, required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
      Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(width: 10),
      SizedBox(width: 40, child: Text(pPercent(share * 100), textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
    ]);
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_charts.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Which teachers have entered, submitted and had approved their marks
/// for a sequence: the principal's view of "who is late".
class PrincipalTrackerPage extends ConsumerStatefulWidget {
  final AppStrings strings;
  const PrincipalTrackerPage({super.key, required this.strings});

  @override
  ConsumerState<PrincipalTrackerPage> createState() => _PrincipalTrackerPageState();
}

class _PrincipalTrackerPageState extends ConsumerState<PrincipalTrackerPage> {
  String? _yearId;
  String? _periodId;
  bool _onlyLate = false;

  AppStrings get _s => widget.strings;

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final calendar = ref.watch(pnCalendarProvider);

    return calendar.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnCalendarProvider)),
      data: (years) {
        if (years.isEmpty) {
          return PrPage(children: [
            PrHeader(title: s.pn('Marks tracker', 'Suivi des notes'), subtitle: s.pn('See who has entered marks.', 'Voyez qui a saisi ses notes.')),
            SizedBox(height: 300, child: PrEmpty(icon: Icons.event_busy_rounded, title: s.pn('No academic year yet', 'Aucune année scolaire'), description: s.pn('Create an academic year with sequences in the calendar first.', 'Créez d\'abord une année scolaire avec des séquences dans le calendrier.'))),
          ]);
        }
        final current = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
        _yearId ??= current.id;
        final year = years.firstWhere((y) => y.id == _yearId, orElse: () => current);
        final periods = [
          for (final t in year.terms)
            for (final q in t.sequences) (id: q.id, label: '${t.name} · ${q.name}', open: q.isOpen, due: q.marksDue),
        ];

        if (_periodId == null || !periods.any((p) => p.id == _periodId)) {
          // default: the open sequence that is due soonest, else the first open, else the last
          final open = periods.where((p) => p.open).toList();
          open.sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
          _periodId = open.isNotEmpty ? open.first.id : (periods.isNotEmpty ? periods.last.id : null);
        }

        return PrPage(
          onRefresh: () async => ref.invalidate(pnTrackerProvider),
          children: [
            PrHeader(
              title: s.pn('Marks tracker', 'Suivi des notes'),
              subtitle: s.pn('Progress of every teacher, class and subject for one sequence. Updates live.', 'Avancement de chaque enseignant, classe et matière pour une séquence. Mise à jour en direct.'),
            ),
            LayoutBuilder(builder: (context, c) {
              final yearDd = DropdownButtonFormField<String>(
                initialValue: year.id,
                isExpanded: true,
                decoration: pnDeco(s.pn('Academic year', 'Année scolaire')),
                items: [for (final y in years) DropdownMenuItem(value: y.id, child: Text(y.name))],
                onChanged: (v) => setState(() {
                  _yearId = v;
                  _periodId = null;
                }),
              );
              final periodDd = DropdownButtonFormField<String>(
                initialValue: _periodId,
                isExpanded: true,
                decoration: pnDeco(s.pn('Sequence', 'Séquence')),
                items: [for (final p in periods) DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _periodId = v),
              );
              if (c.maxWidth < 560) return Column(children: [yearDd, const SizedBox(height: 12), periodDd]);
              return Row(children: [Expanded(child: yearDd), const SizedBox(width: 12), Expanded(flex: 2, child: periodDd)]);
            }),
            const SizedBox(height: 16),
            if (_periodId == null)
              SizedBox(height: 260, child: PrEmpty(icon: Icons.timeline_rounded, title: s.pn('No sequences yet', 'Aucune séquence'), description: s.pn('Add sequences to this year in the calendar.', 'Ajoutez des séquences à cette année dans le calendrier.')))
            else
              ref.watch(pnTrackerProvider(_periodId!)).when(
                    loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => SizedBox(height: 260, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnTrackerProvider(_periodId!)))),
                    data: _body,
                  ),
          ],
        );
      },
    );
  }

  Widget _body(List<PnTrackerRow> rows) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (rows.isEmpty) {
      return SizedBox(height: 260, child: PrEmpty(icon: Icons.assignment_ind_outlined, title: s.pn('No teaching assignments', 'Aucune affectation'), description: s.pn('No teacher is assigned to a class and subject yet.', 'Aucun enseignant n\'est encore affecté à une classe et une matière.')));
    }

    final expected = rows.fold<int>(0, (a, r) => a + r.expected);
    final approved = rows.fold<int>(0, (a, r) => a + r.approved);
    final submitted = rows.fold<int>(0, (a, r) => a + r.submitted);
    final draft = rows.fold<int>(0, (a, r) => a + r.draft);
    final rejected = rows.fold<int>(0, (a, r) => a + r.rejected);
    final missing = (expected - approved - submitted - draft - rejected).clamp(0, 1 << 30).toInt();
    final late = rows.where((r) => !r.complete).toList();
    final shown = _onlyLate ? late : rows;

    // group by teacher
    final byTeacher = <String, List<PnTrackerRow>>{};
    for (final r in shown) {
      byTeacher.putIfAbsent(r.teacher, () => []).add(r);
    }
    final teachers = byTeacher.keys.toList()..sort();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PrGrid(minTile: 170, max: 4, children: [
        PrStatTile(icon: Icons.donut_large_rounded, label: s.pn('Overall', 'Global'), value: expected == 0 ? 0 : approved / expected * 100, format: (v) => '${v.toStringAsFixed(0)}%'),
        PrStatTile(icon: Icons.check_circle_outline_rounded, label: s.pn('Approved', 'Approuvées'), value: approved.toDouble(), format: (v) => '${v.round()}'),
        PrStatTile(icon: Icons.hourglass_top_rounded, label: s.pn('Waiting for you', 'En attente de vous'), value: submitted.toDouble(), format: (v) => '${v.round()}'),
        PrStatTile(icon: Icons.warning_amber_rounded, label: s.pn('Not started', 'Non commencées'), value: missing.toDouble(), format: (v) => '${v.round()}'),
      ]),
      const SizedBox(height: 14),
      PrSplitBar(parts: [
        PrSlice(label: s.pn('Approved', 'Approuvées'), value: approved.toDouble(), color: pnGood()),
        PrSlice(label: s.pn('Submitted', 'Soumises'), value: submitted.toDouble(), color: cs.primary),
        PrSlice(label: s.pn('Draft', 'Brouillon'), value: draft.toDouble(), color: pnWarn()),
        PrSlice(label: s.pn('Rejected', 'Rejetées'), value: rejected.toDouble(), color: pnBad()),
        PrSlice(label: s.pn('Missing', 'Manquantes'), value: missing.toDouble(), color: cs.outlineVariant),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        FilterChip(
          label: Text(s.pn('Only unfinished (${late.length})', 'Seulement non terminés (${late.length})')),
          selected: _onlyLate,
          onSelected: (v) => setState(() => _onlyLate = v),
        ),
      ]),
      const SizedBox(height: 12),
      if (teachers.isEmpty)
        Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(s.pn('Everyone is done. Well done!', 'Tout le monde a terminé. Bravo !'), style: TextStyle(color: cs.outline))))
      else
        for (var i = 0; i < teachers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PrReveal(index: i < 8 ? i : 8, child: _TeacherBlock(name: teachers[i], rows: byTeacher[teachers[i]]!, strings: s)),
          ),
    ]);
  }
}

class _TeacherBlock extends StatelessWidget {
  final String name;
  final List<PnTrackerRow> rows;
  final AppStrings strings;
  const _TeacherBlock({required this.name, required this.rows, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final expected = rows.fold<int>(0, (a, r) => a + r.expected);
    final approved = rows.fold<int>(0, (a, r) => a + r.approved);
    final ratio = expected == 0 ? 0.0 : approved / expected;
    final phone = rows.map((r) => r.phone).firstWhere((p) => p != null && p.isNotEmpty, orElse: () => null);

    return PrCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PrAvatar(name: name, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              if (phone != null)
                InkWell(
                  onTap: () => prCopy(context, phone, s.pn('Phone number copied', 'Numéro copié')),
                  child: Text(phone, style: theme.textTheme.bodySmall?.copyWith(color: cs.primary)),
                ),
            ]),
          ),
          Text('${(ratio * 100).round()}%', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: ratio >= 0.999 ? pnGood() : null)),
        ]),
        const SizedBox(height: 10),
        PrProgressBar(value: ratio, height: 6, color: ratio >= 0.999 ? pnGood() : cs.primary),
        const SizedBox(height: 8),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.subject, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(r.className, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                ]),
              ),
              Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.end, children: [
                if (r.approved > 0) PnChip(label: '${r.approved} ${s.pn('approved', 'approuvées')}', color: pnGood()),
                if (r.submitted > 0) PnChip(label: '${r.submitted} ${s.pn('submitted', 'soumises')}', color: cs.primary),
                if (r.draft > 0) PnChip(label: '${r.draft} ${s.pn('draft', 'brouillon')}', color: pnWarn()),
                if (r.rejected > 0) PnChip(label: '${r.rejected} ${s.pn('rejected', 'rejetées')}', color: pnBad()),
                if (r.approved + r.submitted + r.draft + r.rejected == 0) PnChip(label: s.pn('Not started', 'Non commencé'), color: pnBad()),
              ]),
            ]),
          ),
      ]),
    );
  }
}

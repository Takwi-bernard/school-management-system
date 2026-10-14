import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Academic calendar: years, terms and sequences, all owned by the
/// principal. Terms and sequences belong to one academic year, so a new
/// year starts with its own dates and marks deadlines.
class PrincipalCalendarPage extends ConsumerWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalCalendarPage({super.key, required this.schoolId, required this.strings});

  void _refresh(WidgetRef ref) {
    ref.invalidate(pnCalendarProvider);
    ref.invalidate(pnOverviewProvider);
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? done}) async {
    try {
      await action();
      _refresh(ref);
      if (done != null && context.mounted) prSnack(context, done);
    } catch (e) {
      if (context.mounted) prSnack(context, pnErr(strings, e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final async = ref.watch(pnCalendarProvider);

    return async.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnCalendarProvider)),
      data: (years) {
        final current = years.where((y) => y.isCurrent).cast<PnYear?>().firstWhere((_) => true, orElse: () => null);
        return PrPage(
          onRefresh: () async {
            _refresh(ref);
            try {
              await ref.read(pnCalendarProvider.future);
            } catch (_) {}
          },
          children: [
            PrHeader(
              title: s.pn('Academic calendar', 'Calendrier scolaire'),
              subtitle: s.pn('Create academic years, set their terms and sequences, and choose which year the school is working in.',
                  'Créez les années scolaires, définissez leurs trimestres et séquences, et choisissez l\'année de travail de l\'école.'),
              trailing: FilledButton.icon(
                onPressed: () => _openNewYear(context, ref, years),
                icon: const Icon(Icons.add_rounded),
                label: Text(s.pn('New academic year', 'Nouvelle année scolaire')),
              ),
            ),
            if (current != null) PrReveal(child: _YearEndGuide(year: current, years: years, strings: s)),
            if (years.isEmpty)
              SizedBox(
                height: 320,
                child: PrEmpty(
                  icon: Icons.event_note_outlined,
                  title: s.pn('No academic year yet', 'Aucune année scolaire pour l\'instant'),
                  description: s.pn('Create your first academic year to begin.', 'Créez votre première année scolaire pour commencer.'),
                ),
              ),
            for (var i = 0; i < years.length; i++) ...[
              PrReveal(index: i, child: _YearCard(year: years[i], strings: s, page: this)),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ actions

  Future<void> _openNewYear(BuildContext context, WidgetRef ref, List<PnYear> years) async {
    final created = await pnSheet<bool>(context, (_) => _NewYearSheet(strings: strings, years: years, ref: ref));
    if (created == true) _refresh(ref);
  }

  Future<void> activateYear(BuildContext context, WidgetRef ref, PnYear y) async {
    final s = strings;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Make ${y.name} the active year?', 'Activer ${y.name} ?'),
      message: s.pn(
        'Everything in the school (enrolment, marks, fees, timetable) will now work in ${y.name}. The previous year stays available as history.',
        'Toute l\'école (inscriptions, notes, frais, emploi du temps) fonctionnera désormais dans ${y.name}. L\'année précédente reste disponible dans l\'historique.',
      ),
      confirmLabel: s.pn('Activate', 'Activer'),
    );
    if (!ok || !context.mounted) return;
    await _run(context, ref, () => ref.read(principalHubRepositoryProvider).setCurrentYear(y.id), done: s.pn('${y.name} is now the active year.', '${y.name} est maintenant l\'année active.'));
  }

  Future<void> editYear(BuildContext context, WidgetRef ref, PnYear y) async {
    final changed = await pnSheet<bool>(context, (_) => _YearEditSheet(strings: strings, year: y));
    if (changed == true) _refresh(ref);
  }

  Future<void> editTerm(BuildContext context, WidgetRef ref, PnYear y, PnTerm? t) async {
    final changed = await pnSheet<bool>(context, (_) => _TermEditSheet(strings: strings, year: y, term: t));
    if (changed == true) _refresh(ref);
  }

  Future<void> editSequence(BuildContext context, WidgetRef ref, PnTerm t, PnSequence? q) async {
    final changed = await pnSheet<bool>(context, (_) => _SequenceEditSheet(strings: strings, term: t, sequence: q));
    if (changed == true) _refresh(ref);
  }

  Future<void> deleteTerm(BuildContext context, WidgetRef ref, PnTerm t) async {
    final s = strings;
    final ok = await pnConfirm(context, s,
        title: s.pn('Delete ${t.name}?', 'Supprimer ${t.name} ?'),
        message: s.pn('Its sequences will be deleted too. This is only possible while no marks exist.', 'Ses séquences seront aussi supprimées. Possible uniquement tant qu\'aucune note n\'existe.'),
        confirmLabel: s.pn('Delete', 'Supprimer'),
        destructive: true);
    if (!ok || !context.mounted) return;
    await _run(context, ref, () => ref.read(principalHubRepositoryProvider).deleteTerm(t.id));
  }

  Future<void> deleteSequence(BuildContext context, WidgetRef ref, PnSequence q) async {
    final s = strings;
    final ok = await pnConfirm(context, s,
        title: s.pn('Delete ${q.name}?', 'Supprimer ${q.name} ?'),
        message: s.pn('This is only possible while no marks exist for it.', 'Possible uniquement tant qu\'aucune note n\'existe pour elle.'),
        confirmLabel: s.pn('Delete', 'Supprimer'),
        destructive: true);
    if (!ok || !context.mounted) return;
    await _run(context, ref, () => ref.read(principalHubRepositoryProvider).deleteSequence(q.id));
  }

  Future<void> setCurrentTerm(BuildContext context, WidgetRef ref, PnTerm t) async {
    await _run(context, ref, () => ref.read(principalHubRepositoryProvider).setCurrentTerm(t.id), done: strings.pn('${t.name} is now the current term.', '${t.name} est maintenant le trimestre en cours.'));
  }

  Future<void> toggleOpen(BuildContext context, WidgetRef ref, PnSequence q, bool open) async {
    await _run(context, ref, () => ref.read(principalHubRepositoryProvider).setSequenceOpen(q.id, open));
  }
}

// ============================================================ year-end guide

class _YearEndGuide extends StatelessWidget {
  final PnYear year;
  final List<PnYear> years;
  final AppStrings strings;
  const _YearEndGuide({required this.year, required this.years, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final end = year.end;
    if (end == null) return const SizedBox.shrink();
    final days = end.difference(DateTime.now()).inDays;
    final hasNext = years.any((y) => y.start != null && year.start != null && y.start!.isAfter(year.start!));
    if (days > 60 && hasNext) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PnPanel(
        title: s.pn('Closing ${year.name}', 'Clôture de ${year.name}'),
        subtitle: days >= 0
            ? s.pn('The year ends in $days days. Follow these steps in order.', 'L\'année se termine dans $days jours. Suivez ces étapes dans l\'ordre.')
            : s.pn('The year has ended. Finish these steps.', 'L\'année est terminée. Terminez ces étapes.'),
        child: Column(children: [
          _Step(n: 1, done: false, text: s.pn('Generate the annual report cards (Rankings & report cards, scope "Year").', 'Générez les bulletins annuels (Classements et bulletins, portée « Année »).')),
          _Step(n: 2, done: hasNext, text: s.pn('Create the next academic year (button above). Fees are copied for you.', 'Créez l\'année scolaire suivante (bouton ci-dessus). Les frais sont copiés pour vous.')),
          _Step(n: 3, done: false, text: s.pn('Run Promotion to place every student in next year\'s classes.', 'Lancez la Promotion pour placer chaque élève dans les classes de l\'année suivante.')),
          _Step(n: 4, done: false, text: s.pn('Activate the new year on its card below.', 'Activez la nouvelle année sur sa carte ci-dessous.')),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final bool done;
  final String text;
  const _Step({required this.n, required this.done, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? pnGood() : cs.primary.withValues(alpha: 0.12)),
          child: done ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: cs.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, decoration: done ? TextDecoration.lineThrough : null, color: done ? cs.outline : null))),
      ]),
    );
  }
}

// ============================================================ year card

class _YearCard extends ConsumerWidget {
  final PnYear year;
  final AppStrings strings;
  final PrincipalCalendarPage page;
  const _YearCard({required this.year, required this.strings, required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final range = (year.start != null && year.end != null) ? '${pDate(year.start!)} – ${pDate(year.end!)}' : '';

    return PrCard(
      padding: EdgeInsets.zero,
      color: year.isCurrent ? cs.primary.withValues(alpha: 0.05) : null,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: year.isCurrent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(year.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            if (year.isCurrent) PnChip(label: s.pn('Active', 'Active'), color: pnGood(), icon: Icons.check_circle_rounded),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('$range  ·  ${year.students} ${s.pn('students', 'élèves')}  ·  ${year.terms.length} ${s.pn('terms', 'trimestres')}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          ),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!year.isCurrent) FilledButton.icon(onPressed: () => page.activateYear(context, ref, year), icon: const Icon(Icons.bolt_rounded, size: 18), label: Text(s.pn('Make active', 'Activer'))),
              OutlinedButton.icon(onPressed: () => page.editYear(context, ref, year), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(s.pn('Edit year', 'Modifier l\'année'))),
              OutlinedButton.icon(onPressed: () => page.editTerm(context, ref, year, null), icon: const Icon(Icons.add_rounded, size: 18), label: Text(s.pn('Add term', 'Ajouter un trimestre'))),
            ]),
            if (year.feesSet == 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PnNotice(
                  text: s.pn('No fees are set for this year yet. Set them in School setup → School fees.', 'Aucun frais n\'est défini pour cette année. Définissez-les dans Organisation → Frais scolaires.'),
                  icon: Icons.warning_amber_rounded,
                  color: pnWarn(),
                ),
              ),
            const SizedBox(height: 14),
            for (final t in year.terms) _TermBlock(year: year, term: t, strings: s, page: page),
            if (year.terms.isEmpty) Text(s.pn('No terms yet.', 'Aucun trimestre pour l\'instant.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}

class _TermBlock extends ConsumerWidget {
  final PnYear year;
  final PnTerm term;
  final AppStrings strings;
  final PrincipalCalendarPage page;
  const _TermBlock({required this.year, required this.term, required this.strings, required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final range = (term.start != null && term.end != null) ? '${pDate(term.start!)} – ${pDate(term.end!)}' : s.pn('Dates not set', 'Dates non définies');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(term.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (term.isCurrent) PnChip(label: s.pn('Current term', 'Trimestre en cours'), color: cs.primary),
              ]),
              const SizedBox(height: 2),
              Text(range, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: s.pn('Term actions', 'Actions du trimestre'),
            onSelected: (v) {
              if (v == 'edit') page.editTerm(context, ref, year, term);
              if (v == 'current') page.setCurrentTerm(context, ref, term);
              if (v == 'seq') page.editSequence(context, ref, term, null);
              if (v == 'delete') page.deleteTerm(context, ref, term);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(s.pn('Edit term', 'Modifier le trimestre'))),
              if (!term.isCurrent) PopupMenuItem(value: 'current', child: Text(s.pn('Set as current term', 'Définir comme trimestre en cours'))),
              PopupMenuItem(value: 'seq', child: Text(s.pn('Add sequence', 'Ajouter une séquence'))),
              PopupMenuItem(value: 'delete', child: Text(s.pn('Delete term', 'Supprimer le trimestre'))),
            ],
          ),
        ]),
        const SizedBox(height: 6),
        if (term.sequences.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.pn('No sequences yet.', 'Aucune séquence pour l\'instant.'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
        for (final q in term.sequences)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: cs.outline),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => page.editSequence(context, ref, term, q),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(q.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (q.start != null && q.end != null) '${pDate(q.start!)} – ${pDate(q.end!)}',
                          if (q.marksDue != null) '${s.pn('Marks due', 'Notes avant le')} ${pDate(q.marksDue!)}',
                        ].join('  ·  '),
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ]),
                  ),
                ),
              ),
              Tooltip(
                message: q.isOpen ? s.pn('Marks entry is open', 'La saisie des notes est ouverte') : s.pn('Marks entry is closed', 'La saisie des notes est fermée'),
                child: Switch(value: q.isOpen, onChanged: (v) => page.toggleOpen(context, ref, q, v)),
              ),
              IconButton(
                tooltip: s.pn('Delete sequence', 'Supprimer la séquence'),
                onPressed: q.hasMarks ? null : () => page.deleteSequence(context, ref, q),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ============================================================ date field

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  const _DateField({required this.label, required this.value, required this.onChanged, this.clearable = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final d = await pnPickDate(context, value);
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: pnDeco(label, icon: Icons.calendar_today_outlined),
        child: Row(children: [
          Expanded(child: Text(value == null ? '–' : pDate(value!))),
          if (clearable && value != null) InkWell(onTap: () => onChanged(null), child: Icon(Icons.close_rounded, size: 18, color: cs.outline)),
        ]),
      ),
    );
  }
}

// ============================================================ sheets

class _YearEditSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final PnYear year;
  const _YearEditSheet({required this.strings, required this.year});

  @override
  ConsumerState<_YearEditSheet> createState() => _YearEditSheetState();
}

class _YearEditSheetState extends ConsumerState<_YearEditSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.year.name);
  late DateTime? _start = widget.year.start;
  late DateTime? _end = widget.year.end;
  bool _busy = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_start == null || _end == null) {
      prSnack(context, _s.pn('Choose both dates.', 'Choisissez les deux dates.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(principalHubRepositoryProvider).updateYear(id: widget.year.id, name: _name.text, start: _start!, end: _end!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, pnErr(_s, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PnSheetBody(
      title: _s.pn('Edit academic year', 'Modifier l\'année scolaire'),
      children: [
        TextField(controller: _name, decoration: pnDeco(_s.pn('Year name', 'Nom de l\'année'), hint: '2026-2027')),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('Start date', 'Date de début'), value: _start, onChanged: (d) => setState(() => _start = d)),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('End date', 'Date de fin'), value: _end, onChanged: (d) => setState(() => _end = d)),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: _s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}

class _TermEditSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final PnYear year;
  final PnTerm? term;
  const _TermEditSheet({required this.strings, required this.year, this.term});

  @override
  ConsumerState<_TermEditSheet> createState() => _TermEditSheetState();
}

class _TermEditSheetState extends ConsumerState<_TermEditSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.term?.name ?? '${widget.strings.pn('Term', 'Trimestre')} ${widget.year.terms.length + 1}');
  late DateTime? _start = widget.term?.start;
  late DateTime? _end = widget.term?.end;
  bool _busy = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(principalHubRepositoryProvider).upsertTerm(yearId: widget.year.id, termId: widget.term?.id, name: _name.text, start: _start, end: _end);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, pnErr(_s, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PnSheetBody(
      title: widget.term == null ? _s.pn('Add term', 'Ajouter un trimestre') : _s.pn('Edit term', 'Modifier le trimestre'),
      children: [
        TextField(controller: _name, decoration: pnDeco(_s.pn('Term name', 'Nom du trimestre'))),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('Start date', 'Date de début'), value: _start, onChanged: (d) => setState(() => _start = d), clearable: true),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('End date', 'Date de fin'), value: _end, onChanged: (d) => setState(() => _end = d), clearable: true),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: _s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}

class _SequenceEditSheet extends ConsumerStatefulWidget {
  final AppStrings strings;
  final PnTerm term;
  final PnSequence? sequence;
  const _SequenceEditSheet({required this.strings, required this.term, this.sequence});

  @override
  ConsumerState<_SequenceEditSheet> createState() => _SequenceEditSheetState();
}

class _SequenceEditSheetState extends ConsumerState<_SequenceEditSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.sequence?.name ?? '${widget.strings.pn('Sequence', 'Séquence')} ${widget.term.sequences.length + 1}');
  late DateTime? _start = widget.sequence?.start;
  late DateTime? _end = widget.sequence?.end;
  late DateTime? _due = widget.sequence?.marksDue;
  bool _busy = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(principalHubRepositoryProvider).upsertSequence(
            termId: widget.term.id,
            periodId: widget.sequence?.id,
            name: _name.text,
            start: _start,
            end: _end,
            marksDue: _due,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, pnErr(_s, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PnSheetBody(
      title: widget.sequence == null ? _s.pn('Add sequence', 'Ajouter une séquence') : _s.pn('Edit sequence', 'Modifier la séquence'),
      subtitle: widget.term.name,
      children: [
        TextField(controller: _name, decoration: pnDeco(_s.pn('Sequence name', 'Nom de la séquence'))),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('Start date', 'Date de début'), value: _start, onChanged: (d) => setState(() => _start = d), clearable: true),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('End date', 'Date de fin'), value: _end, onChanged: (d) => setState(() => _end = d), clearable: true),
        const SizedBox(height: 12),
        _DateField(label: _s.pn('Teachers must submit marks by', 'Les enseignants doivent soumettre les notes avant le'), value: _due, onChanged: (d) => setState(() => _due = d), clearable: true),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _save, child: PnBusyLabel(busy: _busy, label: _s.pn('Save', 'Enregistrer'))),
      ],
    );
  }
}

// ============================================================ new year wizard

class _NewYearSheet extends StatefulWidget {
  final AppStrings strings;
  final List<PnYear> years;
  final WidgetRef ref;
  const _NewYearSheet({required this.strings, required this.years, required this.ref});

  @override
  State<_NewYearSheet> createState() => _NewYearSheetState();
}

class _NewYearSheetState extends State<_NewYearSheet> {
  late final TextEditingController _name;
  late DateTime _start;
  late DateTime _end;
  int _terms = 3;
  int _seqs = 2;
  String? _copyFrom;
  bool _activate = false;
  bool _busy = false;

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    final latest = widget.years.isEmpty ? null : widget.years.first; // calendar is newest-first
    final nextStartYear = latest?.end != null ? latest!.end!.year : DateTime.now().year;
    _start = DateTime(nextStartYear, 9, 1);
    _end = DateTime(nextStartYear + 1, 6, 30);
    _name = TextEditingController(text: '$nextStartYear-${nextStartYear + 1}');
    _copyFrom = latest?.id;
    _activate = widget.years.isEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Even split of the year into terms, and of each term into sequences.
  List<PnTermDraft> _build() {
    final totalDays = _end.difference(_start).inDays;
    final termLen = totalDays ~/ _terms;
    final out = <PnTermDraft>[];
    for (var t = 0; t < _terms; t++) {
      final ts = _start.add(Duration(days: termLen * t));
      final te = t == _terms - 1 ? _end : _start.add(Duration(days: termLen * (t + 1) - 1));
      final draft = PnTermDraft(name: '${_s.pn('Term', 'Trimestre')} ${t + 1}', start: ts, end: te);
      final seqLen = (te.difference(ts).inDays) ~/ _seqs;
      for (var q = 0; q < _seqs; q++) {
        final qs = ts.add(Duration(days: seqLen * q));
        final qe = q == _seqs - 1 ? te : ts.add(Duration(days: seqLen * (q + 1) - 1));
        draft.sequences.add(PnSeqDraft(name: '${_s.pn('Sequence', 'Séquence')} ${t * _seqs + q + 1}', start: qs, end: qe, marksDue: qe.add(const Duration(days: 7))));
      }
      out.add(draft);
    }
    return out;
  }

  Future<void> _create() async {
    if (!_end.isAfter(_start)) {
      prSnack(context, _s.pn('The end date must be after the start date.', 'La date de fin doit être postérieure à la date de début.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.ref.read(principalHubRepositoryProvider).createYear(
            name: _name.text,
            start: _start,
            end: _end,
            terms: _build(),
            makeCurrent: _activate,
            copyFeesFrom: _copyFrom,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        prSnack(context, pnErr(_s, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return PnSheetBody(
      title: s.pn('New academic year', 'Nouvelle année scolaire'),
      subtitle: s.pn('Terms and sequences are created for you and can be adjusted afterwards.', 'Les trimestres et séquences sont créés pour vous et peuvent être ajustés ensuite.'),
      children: [
        TextField(controller: _name, decoration: pnDeco(s.pn('Year name', 'Nom de l\'année'), hint: '2027-2028')),
        const SizedBox(height: 12),
        _DateField(label: s.pn('Start date', 'Date de début'), value: _start, onChanged: (d) => setState(() => _start = d ?? _start)),
        const SizedBox(height: 12),
        _DateField(label: s.pn('End date', 'Date de fin'), value: _end, onChanged: (d) => setState(() => _end = d ?? _end)),
        const SizedBox(height: 16),
        Text(s.pn('Terms in the year', 'Trimestres dans l\'année'), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<int>(values: const [1, 2, 3, 4], selected: _terms, label: (v) => '$v', onChanged: (v) => setState(() => _terms = v)),
        const SizedBox(height: 16),
        Text(s.pn('Sequences in each term', 'Séquences par trimestre'), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<int>(values: const [1, 2, 3, 4], selected: _seqs, label: (v) => '$v', onChanged: (v) => setState(() => _seqs = v)),
        if (widget.years.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _copyFrom,
            decoration: pnDeco(s.pn('Copy school fees from', 'Copier les frais scolaires de')),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(s.pn('Do not copy', 'Ne pas copier'))),
              for (final y in widget.years) DropdownMenuItem<String?>(value: y.id, child: Text(y.name)),
            ],
            onChanged: (v) => setState(() => _copyFrom = v),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _activate,
          onChanged: (v) => setState(() => _activate = v),
          title: Text(s.pn('Make this the active year now', 'Activer cette année maintenant')),
          subtitle: Text(s.pn('Leave off if you are still closing the current year.', 'Laissez désactivé si vous clôturez encore l\'année en cours.')),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(onPressed: _busy ? null : _create, child: PnBusyLabel(busy: _busy, label: s.pn('Create year', 'Créer l\'année'))),
      ],
    );
  }
}

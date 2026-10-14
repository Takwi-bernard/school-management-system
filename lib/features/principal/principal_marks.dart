import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';
import 'principal_kit.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

// ============================================================
// MARKS ENTRY WINDOW: open / close each sequence, set due dates
// ============================================================

class MarksWindowPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const MarksWindowPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<MarksWindowPage> createState() => _MarksWindowPageState();
}

class _MarksWindowPageState extends ConsumerState<MarksWindowPage> {
  String? _yearId;
  final Set<String> _busy = {};

  AppStrings get _s => widget.strings;

  Future<void> _toggle(PnSequence seq, bool open) async {
    setState(() => _busy.add(seq.id));
    try {
      await ref.read(principalHubRepositoryProvider).setSequenceOpen(seq.id, open);
      ref.invalidate(pnCalendarProvider);
      ref.invalidate(pnOverviewProvider);
      if (mounted) {
        prSnack(
          context,
          open
              ? _s.pn('${seq.name} is open: teachers can enter marks.', '${seq.name} est ouverte : les enseignants peuvent saisir les notes.')
              : _s.pn('${seq.name} is closed. Marks already entered are kept.', '${seq.name} est fermée. Les notes déjà saisies sont conservées.'),
        );
      }
    } catch (e) {
      if (mounted) prSnack(context, pnErr(_s, e));
    } finally {
      if (mounted) setState(() => _busy.remove(seq.id));
    }
  }

  Future<void> _setDue(PnTerm term, PnSequence seq) async {
    final now = DateTime.now();
    final picked = await pnPickDate(context, seq.marksDue ?? now.add(const Duration(days: 14)), first: DateTime(now.year - 1), last: DateTime(now.year + 2));
    if (picked == null) return;
    setState(() => _busy.add(seq.id));
    try {
      await ref.read(principalHubRepositoryProvider).upsertSequence(
            termId: term.id,
            periodId: seq.id,
            name: seq.name,
            start: seq.start,
            end: seq.end,
            marksDue: picked,
          );
      ref.invalidate(pnCalendarProvider);
      if (mounted) prSnack(context, _s.pn('Due date saved.', 'Date limite enregistrée.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(_s, e));
    } finally {
      if (mounted) setState(() => _busy.remove(seq.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final cal = ref.watch(pnCalendarProvider);
    return PrPage(
      maxWidth: 900,
      onRefresh: () async => ref.refresh(pnCalendarProvider.future),
      children: [
        PrHeader(
          title: s.pn('Marks entry window', 'Fenêtre de saisie des notes'),
          subtitle: s.pn(
            'Teachers can only enter or submit marks while a sequence is open. Closing a sequence never deletes marks already entered.',
            'Les enseignants ne peuvent saisir ou soumettre des notes que lorsqu’une séquence est ouverte. Fermer une séquence ne supprime jamais les notes déjà saisies.',
          ),
        ),
        const SizedBox(height: 18),
        PnAsync<List<PnYear>>(
          value: cal,
          strings: s,
          onRetry: () => ref.invalidate(pnCalendarProvider),
          isEmpty: (d) => d.isEmpty,
          empty: PnEmpty(
            icon: Icons.event_busy_rounded,
            title: s.pn('No academic year yet', 'Aucune année scolaire'),
            text: s.pn('Create the academic year and its sequences in the Calendar first.', 'Créez d’abord l’année scolaire et ses séquences dans le Calendrier.'),
          ),
          builder: (years) {
            final year = years.firstWhere((y) => y.id == _yearId, orElse: () => years.firstWhere((y) => y.isCurrent, orElse: () => years.first));
            final terms = year.terms;
            final total = terms.fold<int>(0, (a, t) => a + t.sequences.length);
            final open = terms.fold<int>(0, (a, t) => a + t.sequences.where((q) => q.isOpen).length);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (years.length > 1) ...[
                PrPills<PnYear>(values: years, selected: year, label: (y) => y.name, onChanged: (y) => setState(() => _yearId = y.id)),
                const SizedBox(height: 14),
              ],
              PrReveal(
                child: PnNotice(
                  icon: open > 0 ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: open > 0 ? pnGood() : pnWarn(),
                  text: open > 0
                      ? s.pn('$open of $total sequences are open for marks entry.', '$open séquence(s) sur $total ouverte(s) pour la saisie des notes.')
                      : s.pn('No sequence is open: teachers cannot enter marks right now.', 'Aucune séquence ouverte : les enseignants ne peuvent pas saisir de notes.'),
                ),
              ),
              const SizedBox(height: 16),
              if (total == 0)
                PnEmpty(icon: Icons.view_week_rounded, title: s.pn('No sequences in ${year.name}', 'Aucune séquence en ${year.name}'), text: s.pn('Add sequences to the terms in the Calendar.', 'Ajoutez des séquences aux trimestres dans le Calendrier.'))
              else
                for (var ti = 0; ti < terms.length; ti++) ...[
                  if (terms[ti].sequences.isNotEmpty) ...[
                    PrSectionTitle(title: terms[ti].name, subtitle: terms[ti].isCurrent ? s.pn('Current term', 'Trimestre en cours') : null),
                    for (var qi = 0; qi < terms[ti].sequences.length; qi++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SequenceRow(
                          index: qi,
                          strings: s,
                          seq: terms[ti].sequences[qi],
                          busy: _busy.contains(terms[ti].sequences[qi].id),
                          onToggle: (v) => _toggle(terms[ti].sequences[qi], v),
                          onDue: () => _setDue(terms[ti], terms[ti].sequences[qi]),
                        ),
                      ),
                  ],
                ],
            ]);
          },
        ),
      ],
    );
  }
}

class _SequenceRow extends StatelessWidget {
  final AppStrings strings;
  final PnSequence seq;
  final bool busy;
  final int index;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDue;
  const _SequenceRow({required this.strings, required this.seq, required this.busy, required this.index, required this.onToggle, required this.onDue});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final due = seq.marksDue;
    final overdue = due != null && seq.isOpen && due.isBefore(DateTime.now());
    return PrReveal(
      index: index,
      child: PrCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 520;
          final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(seq.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: PnChip(
                  key: ValueKey(seq.isOpen),
                  label: seq.isOpen ? s.pn('Open', 'Ouverte') : s.pn('Closed', 'Fermée'),
                  color: seq.isOpen ? pnGood() : cs.outline,
                  icon: seq.isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                ),
              ),
              if (overdue) ...[const SizedBox(width: 6), PnChip(label: s.pn('Past due', 'En retard'), color: pnBad())],
            ]),
            const SizedBox(height: 4),
            Text(
              due == null ? s.pn('No due date set', 'Aucune date limite') : s.pn('Marks due ${pDate(due)}', 'Notes attendues le ${pDate(due)}'),
              style: theme.textTheme.bodySmall?.copyWith(color: overdue ? pnBad() : cs.outline),
            ),
            if (seq.hasMarks)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(s.pn('Marks already entered', 'Des notes sont déjà saisies'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
          ]);
          final controls = Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(onPressed: busy ? null : onDue, icon: const Icon(Icons.event_rounded, size: 17), label: Text(s.pn('Due date', 'Date limite'))),
            const SizedBox(width: 4),
            busy ? const SizedBox(width: 48, height: 24, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))) : Switch(value: seq.isOpen, onChanged: onToggle),
          ]);
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: controls)]);
          }
          return Row(children: [Expanded(child: info), controls]);
        }),
      ),
    );
  }
}

// ============================================================
// MARKS REVIEW: sequence > class > subject > marks
// ============================================================

class MarksReviewPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const MarksReviewPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<MarksReviewPage> createState() => _MarksReviewPageState();
}

class _MarksReviewPageState extends ConsumerState<MarksReviewPage> {
  String? _periodId;
  String? _periodName;
  String? _classId;
  String? _className;
  String? _subjectId;
  String? _subjectName;
  final Set<String> _selected = {};
  bool _busy = false;

  AppStrings get _s => widget.strings;

  void _go({String? period, String? periodName, bool keepPeriod = true, String? classId, String? className, String? subjectId, String? subjectName}) {
    setState(() {
      if (!keepPeriod || period != null) {
        _periodId = period;
        _periodName = periodName;
      }
      _classId = classId;
      _className = className;
      _subjectId = subjectId;
      _subjectName = subjectName;
      _selected.clear();
    });
  }

  void _refreshAll() {
    final p = _periodId;
    if (p == null) return;
    ref.invalidate(pnReviewSummaryProvider(p));
    if (_classId != null && _subjectId != null) {
      ref.invalidate(marksForClassSubjectProvider((examPeriodId: p, classId: _classId!, subjectId: _subjectId!)));
    }
    ref.invalidate(pnOverviewProvider);
  }

  Future<void> _approve({List<String>? ids, String? classId, String? subjectId, required int count, required String label}) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Approve $count mark${count == 1 ? '' : 's'}?', 'Approuver $count note${count == 1 ? '' : 's'} ?'),
      message: s.pn(
        '$label. Approved marks become official. Report cards are not generated or published automatically.',
        '$label. Les notes approuvées deviennent officielles. Les bulletins ne sont ni générés ni publiés automatiquement.',
      ),
      confirmLabel: s.pn('Approve', 'Approuver'),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await ref.read(principalHubRepositoryProvider).approveMarks(periodId: _periodId!, classId: classId, subjectId: subjectId, ids: ids);
      _selected.clear();
      _refreshAll();
      if (mounted) prSnack(context, s.pn('$n mark${n == 1 ? '' : 's'} approved.', '$n note${n == 1 ? '' : 's'} approuvée${n == 1 ? '' : 's'}.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendBack(SubmittedMark m) async {
    final s = _s;
    final ctrl = TextEditingController();
    final res = await pnSheet<String>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => PnSheetBody(
          title: s.pn('Send back ${m.studentName}’s mark', 'Renvoyer la note de ${m.studentName}'),
          subtitle: s.pn('${m.teacherName} will see your note and can correct and resubmit.', '${m.teacherName} verra votre remarque et pourra corriger puis soumettre à nouveau.'),
          children: [
            TextField(controller: ctrl, maxLines: 3, autofocus: true, onChanged: (_) => set(() {}), decoration: pnDeco(s.pn('What needs to be corrected?', 'Que faut-il corriger ?'))),
          ],
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.pn('Cancel', 'Annuler'))),
            FilledButton.icon(
              onPressed: ctrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, ctrl.text.trim()),
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(s.pn('Send back', 'Renvoyer')),
            ),
          ],
        ),
      ),
    );
    if (res == null || !mounted) return;
    try {
      await ref.read(principalRepositoryProvider).sendBackMarks([m.id], res);
      _refreshAll();
      if (mounted) prSnack(context, s.pn('Sent back to the teacher.', 'Renvoyée à l’enseignant.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  Future<void> _discard(SubmittedMark m) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Discard this mark?', 'Supprimer cette note ?'),
      message: s.pn('${m.studentName}’s ${m.subjectName} mark will be permanently deleted. This cannot be undone.', 'La note de ${m.studentName} en ${m.subjectName} sera définitivement supprimée. Cette action est irréversible.'),
      confirmLabel: s.pn('Discard permanently', 'Supprimer définitivement'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(principalRepositoryProvider).discardMark(m.id);
      _refreshAll();
      if (mounted) prSnack(context, s.pn('Mark discarded.', 'Note supprimée.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final cal = ref.watch(pnCalendarProvider);
    final stage = _periodId == null ? 'p' : (_classId == null ? 'c' : (_subjectId == null ? 's' : 'm'));
    return PrPage(
      maxWidth: 960,
      onRefresh: () async {
        _refreshAll();
        await ref.refresh(pnCalendarProvider.future);
      },
      children: [
        PrHeader(
          title: s.pn('Marks review', 'Validation des notes'),
          subtitle: s.pn('Pick a sequence, then a class and a subject. Marks are approved one subject at a time.', 'Choisissez une séquence, puis une classe et une matière. Les notes sont validées matière par matière.'),
        ),
        const SizedBox(height: 14),
        PnAsync<List<PnYear>>(
          value: cal,
          strings: s,
          onRetry: () => ref.invalidate(pnCalendarProvider),
          isEmpty: (d) => d.isEmpty,
          empty: PnEmpty(icon: Icons.event_busy_rounded, title: s.pn('No academic year yet', 'Aucune année scolaire')),
          builder: (years) {
            final year = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
            final seqs = [for (final t in year.terms) ...t.sequences];
            if (seqs.isEmpty) {
              return PnEmpty(icon: Icons.view_week_rounded, title: s.pn('No sequences yet', 'Aucune séquence'), text: s.pn('Create sequences in the Calendar first.', 'Créez d’abord des séquences dans le Calendrier.'));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PrPills<PnSequence?>(
                values: [...seqs],
                selected: seqs.cast<PnSequence?>().firstWhere((q) => q!.id == _periodId, orElse: () => null),
                label: (q) => q?.name ?? '',
                onChanged: (q) => _go(period: q!.id, periodName: q.name, keepPeriod: false),
              ),
              const SizedBox(height: 14),
              if (_periodId != null)
                PnCrumbs(
                  labels: [_periodName ?? '', if (_className != null) _className!, if (_subjectName != null) _subjectName!],
                  onTap: (i) {
                    if (i == 0) _go();
                    if (i == 1) _go(classId: _classId, className: _className);
                  },
                ),
              const SizedBox(height: 8),
              PnStage(
                stageKey: stage + (_classId ?? '') + (_subjectId ?? '') + (_periodId ?? ''),
                child: _periodId == null
                    ? PnEmpty(icon: Icons.touch_app_rounded, title: s.pn('Choose a sequence', 'Choisissez une séquence'), text: s.pn('The classes with marks waiting will appear here.', 'Les classes ayant des notes en attente apparaîtront ici.'))
                    : _stage(),
              ),
            ]);
          },
        ),
      ],
    );
  }

  Widget _stage() {
    final s = _s;
    final summary = ref.watch(pnReviewSummaryProvider(_periodId!));
    if (_classId != null && _subjectId != null) return _marksStage();
    return PnAsync<List<Map<String, dynamic>>>(
      value: summary,
      strings: s,
      onRetry: () => ref.invalidate(pnReviewSummaryProvider(_periodId!)),
      builder: (rows) {
        if (_classId == null) {
          final byClass = <String, _Agg>{};
          for (final r in rows) {
            final a = byClass.putIfAbsent(pnS(r['class_id']), () => _Agg(pnS(r['class_name'])));
            a.add(r);
          }
          final list = byClass.entries.toList();
          final waiting = list.where((e) => e.value.submitted > 0).toList();
          if (list.isEmpty) {
            return PnEmpty(icon: Icons.inbox_rounded, title: s.pn('No marks in this sequence yet', 'Aucune note dans cette séquence'), text: s.pn('Teachers have not submitted any marks for it.', 'Les enseignants n’ont encore soumis aucune note.'));
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (waiting.isEmpty) PnNotice(icon: Icons.verified_rounded, color: pnGood(), text: s.pn('Everything submitted has been reviewed.', 'Tout ce qui a été soumis a été examiné.')),
            const SizedBox(height: 8),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PnPickTile(
                  index: i,
                  icon: Icons.groups_rounded,
                  title: list[i].value.name,
                  subtitle: s.pn('${list[i].value.approved} approved · ${list[i].value.rejected} sent back', '${list[i].value.approved} approuvées · ${list[i].value.rejected} renvoyées'),
                  badge: list[i].value.submitted > 0 ? s.pn('${list[i].value.submitted} waiting', '${list[i].value.submitted} en attente') : s.pn('Done', 'Terminé'),
                  badgeColor: list[i].value.submitted > 0 ? pnWarn() : pnGood(),
                  onTap: () => _go(classId: list[i].key, className: list[i].value.name),
                ),
              ),
          ]);
        }
        final subs = rows.where((r) => pnS(r['class_id']) == _classId).toList();
        final waiting = subs.fold<int>(0, (a, r) => a + pnI(r['submitted']));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (waiting > 0)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _approve(classId: _classId, count: waiting, label: s.pn('Every waiting mark of $_className', 'Toutes les notes en attente de $_className')),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(s.pn('Approve whole class ($waiting)', 'Approuver toute la classe ($waiting)')),
              ),
            ),
          const SizedBox(height: 10),
          for (var i = 0; i < subs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PnPickTile(
                index: i,
                icon: Icons.menu_book_rounded,
                title: pnS(subs[i]['subject_name']),
                subtitle: s.pn('${pnI(subs[i]['approved'])} approved · ${pnI(subs[i]['rejected'])} sent back', '${pnI(subs[i]['approved'])} approuvées · ${pnI(subs[i]['rejected'])} renvoyées'),
                badge: pnI(subs[i]['submitted']) > 0 ? s.pn('${pnI(subs[i]['submitted'])} waiting', '${pnI(subs[i]['submitted'])} en attente') : s.pn('Done', 'Terminé'),
                badgeColor: pnI(subs[i]['submitted']) > 0 ? pnWarn() : pnGood(),
                onTap: () => _go(classId: _classId, className: _className, subjectId: pnS(subs[i]['subject_id']), subjectName: pnS(subs[i]['subject_name'])),
              ),
            ),
        ]);
      },
    );
  }

  Widget _marksStage() {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final key = (examPeriodId: _periodId!, classId: _classId!, subjectId: _subjectId!);
    final marks = ref.watch(marksForClassSubjectProvider(key));
    return PnAsync<List<SubmittedMark>>(
      value: marks,
      strings: s,
      onRetry: () => ref.invalidate(marksForClassSubjectProvider(key)),
      isEmpty: (d) => d.isEmpty,
      empty: PnEmpty(
        icon: Icons.verified_rounded,
        title: s.pn('All marks here are reviewed', 'Toutes les notes sont examinées'),
        action: OutlinedButton.icon(onPressed: () => _go(classId: _classId, className: _className), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(s.pn('Back to subjects', 'Retour aux matières'))),
      ),
      builder: (list) {
        final sel = _selected.where((id) => list.any((m) => m.id == id)).toSet();
        final avg = list.isEmpty ? null : list.fold<double>(0, (a, m) => a + m.score) / list.length;
        final low = list.where((m) => m.score < 10).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PrReveal(
            child: PrCard(
              child: Wrap(spacing: 24, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _mini(s.pn('Waiting', 'En attente'), '${list.length}'),
                _mini(s.pn('Average', 'Moyenne'), pnAvg(avg)),
                _mini(s.pn('Below 10', 'Sous 10'), '$low', color: low > 0 ? pnWarn() : null),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (sel.isNotEmpty) ...[
                    OutlinedButton(onPressed: _busy ? null : () => _approve(ids: sel.toList(), count: sel.length, label: s.pn('The ${sel.length} selected marks', 'Les ${sel.length} notes sélectionnées')), child: Text(s.pn('Approve selected (${sel.length})', 'Approuver la sélection (${sel.length})'))),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _approve(classId: _classId, subjectId: _subjectId, count: list.length, label: s.pn('All marks of $_subjectName in $_className', 'Toutes les notes de $_subjectName en $_className')),
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(s.pn('Approve all', 'Tout approuver')),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Checkbox(
              value: sel.length == list.length && list.isNotEmpty,
              tristate: sel.isNotEmpty && sel.length < list.length,
              onChanged: (v) => setState(() {
                if (sel.length == list.length) {
                  _selected.clear();
                } else {
                  _selected..clear()..addAll(list.map((m) => m.id));
                }
              }),
            ),
            Text(s.pn('Select all', 'Tout sélectionner'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          ]),
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrReveal(
                index: i > 10 ? 10 : i,
                child: PrCard(
                  padding: const EdgeInsets.fromLTRB(6, 10, 8, 10),
                  color: sel.contains(list[i].id) ? cs.primary.withValues(alpha: 0.06) : null,
                  child: Row(children: [
                    Checkbox(value: sel.contains(list[i].id), onChanged: (v) => setState(() => v == true ? _selected.add(list[i].id) : _selected.remove(list[i].id))),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(list[i].studentName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(s.pn('Coef. ${list[i].coefficient} · ${list[i].teacherName}', 'Coef. ${list[i].coefficient} · ${list[i].teacherName}'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if ((list[i].remarks ?? '').isNotEmpty) Text(list[i].remarks!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      ]),
                    ),
                    Text(list[i].score.toStringAsFixed(list[i].score == list[i].score.roundToDouble() ? 0 : 2), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: list[i].score < 10 ? pnBad() : cs.onSurface)),
                    Text('/20', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                    const SizedBox(width: 4),
                    IconButton(icon: Icon(Icons.check_circle_outline_rounded, color: pnGood()), tooltip: s.pn('Approve', 'Approuver'), onPressed: _busy ? null : () => _approve(ids: [list[i].id], count: 1, label: '${list[i].studentName}: ${list[i].score}')),
                    IconButton(icon: const Icon(Icons.reply_rounded), tooltip: s.pn('Send back', 'Renvoyer'), onPressed: () => _sendBack(list[i])),
                    IconButton(icon: Icon(Icons.delete_outline_rounded, color: cs.error), tooltip: s.pn('Discard', 'Supprimer'), onPressed: () => _discard(list[i])),
                  ]),
                ),
              ),
            ),
        ]);
      },
    );
  }

  Widget _mini(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: color)),
    ]);
  }
}

class _Agg {
  final String name;
  int submitted = 0;
  int approved = 0;
  int rejected = 0;
  _Agg(this.name);
  void add(Map<String, dynamic> r) {
    submitted += pnI(r['submitted']);
    approved += pnI(r['approved']);
    rejected += pnI(r['rejected']);
  }
}

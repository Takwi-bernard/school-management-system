import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';
import 'principal_promotion_planner.dart';

typedef _PromoKey = ({String from, String to});

final _promoDataProvider = FutureProvider.autoDispose.family<PnPromoData, _PromoKey>((ref, k) {
  return ref.watch(principalHubRepositoryProvider).getPromotionData(k.from, k.to);
});

/// Year-end promotion: set the pass mark, preview where every student
/// goes, adjust anyone, then apply the whole thing in one safe step.
class PrincipalPromotionPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalPromotionPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalPromotionPage> createState() => _PrincipalPromotionPageState();
}

class _PrincipalPromotionPageState extends ConsumerState<PrincipalPromotionPage> {
  String? _from;
  String? _to;
  final _pass = TextEditingController();
  final _margin = TextEditingController();
  bool _balance = true;
  bool _seeded = false;

  final Map<String, PnManual> _manual = {};
  final Set<String> _excluded = {};
  String? _classFilter;
  String _show = 'all'; // all | promoted | repeat | graduated | attention
  bool _busy = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _pass.dispose();
    _margin.dispose();
    super.dispose();
  }

  double get _passValue => double.tryParse(_pass.text.replaceAll(',', '.')) ?? 10;
  double get _marginValue => double.tryParse(_margin.text.replaceAll(',', '.')) ?? 1;

  void _toast(String m) {
    if (mounted) prSnack(context, m);
  }

  void _resetPlanState() {
    _manual.clear();
    _excluded.clear();
    _classFilter = null;
    _seeded = false;
  }

  Future<void> _saveDefaults() async {
    final s = _s;
    try {
      final repo = ref.read(principalHubRepositoryProvider);
      final cur = await ref.read(pnSettingsProvider(widget.schoolId).future);
      await repo.saveSettings(widget.schoolId, PnSettings(passMark: _passValue, margin: _marginValue, threshold: cur.threshold, balance: _balance));
      ref.invalidate(pnSettingsProvider(widget.schoolId));
      ref.invalidate(pnOverviewProvider);
      _toast(s.pn('Saved as the school\'s default pass mark.', 'Enregistré comme barre de passage par défaut de l\'école.'));
    } catch (e) {
      _toast(pnErr(s, e));
    }
  }

  Future<void> _apply(PnPromoData data, PnPlan plan) async {
    final s = _s;
    final rows = plan.rows.where((r) => r.applicable).toList();
    if (rows.isEmpty || _from == null || _to == null) return;
    final promoted = rows.where((r) => r.outcome == PnOutcome.promoted).length;
    final repeat = rows.where((r) => r.outcome == PnOutcome.repeat).length;
    final grad = rows.where((r) => r.outcome == PnOutcome.graduated).length;

    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Apply promotion to ${rows.length} students?', 'Appliquer la promotion à ${rows.length} élèves ?'),
      message: s.pn(
        '$promoted promoted, $repeat repeating, $grad graduating. Students are enrolled in their new classes for the new year. You can undo this run later, as long as no marks were entered for them.',
        '$promoted promus, $repeat redoublants, $grad diplômés. Les élèves sont inscrits dans leurs nouvelles classes pour la nouvelle année. Vous pourrez annuler cette opération tant qu\'aucune note n\'a été saisie pour eux.',
      ),
      confirmLabel: s.pn('Apply', 'Appliquer'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await ref.read(principalHubRepositoryProvider).applyPromotion(
            fromYear: _from!,
            toYear: _to!,
            passMark: _passValue,
            decisions: [
              for (final r in rows)
                {
                  'student_id': r.student.id,
                  'from_class_id': r.student.classId,
                  'to_class_id': r.toClassId,
                  'outcome': r.outcome == PnOutcome.promoted ? 'promoted' : (r.outcome == PnOutcome.repeat ? 'repeat' : 'graduated'),
                  'average': r.student.average,
                  'source': r.manual ? 'manual' : 'auto',
                },
            ],
          );
      _manual.clear();
      _excluded.clear();
      ref.invalidate(_promoDataProvider);
      ref.invalidate(pnPromotionHistoryProvider);
      ref.invalidate(pnOverviewProvider);
      ref.invalidate(pnBoardProvider);
      _toast(s.pn(
        'Done: ${pnI(res['promoted'])} promoted, ${pnI(res['repeated'])} repeating, ${pnI(res['graduated'])} graduated.',
        'Terminé : ${pnI(res['promoted'])} promus, ${pnI(res['repeated'])} redoublants, ${pnI(res['graduated'])} diplômés.',
      ));
    } catch (e) {
      _toast(pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo(PnPromotionRun run) async {
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Undo this promotion?', 'Annuler cette promotion ?'),
      message: s.pn('The new-year enrolments created by this run are removed and graduates return to active. This is blocked once marks exist in the new year.', 'Les inscriptions de la nouvelle année créées par cette opération sont supprimées et les diplômés redeviennent actifs. Impossible dès que des notes existent dans la nouvelle année.'),
      confirmLabel: s.pn('Undo', 'Annuler'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(principalHubRepositoryProvider).undoPromotion(run.id);
      ref.invalidate(_promoDataProvider);
      ref.invalidate(pnPromotionHistoryProvider);
      ref.invalidate(pnOverviewProvider);
      _toast(s.pn('Promotion undone.', 'Promotion annulée.'));
    } catch (e) {
      _toast(pnErr(s, e));
    }
  }

  Future<void> _decide(PnPlanRow r, PnPromoData data, PnPlan plan) async {
    final res = await pnSheet<Object>(context, (_) => _DecisionSheet(strings: _s, row: r, data: data, plan: plan));
    if (res == null || !mounted) return;
    setState(() {
      if (res == 'reset') {
        _manual.remove(r.student.id);
      } else if (res is PnManual) {
        _manual[r.student.id] = res;
        _excluded.remove(r.student.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final calendar = ref.watch(pnCalendarProvider);

    return calendar.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnCalendarProvider)),
      data: (years) {
        if (years.length < 2) {
          return PrPage(children: [
            PrHeader(title: s.pn('Promotion', 'Promotion'), subtitle: s.pn('Move students up at the end of the year.', 'Faites passer les élèves en classe supérieure en fin d\'année.')),
            SizedBox(
              height: 300,
              child: PrEmpty(
                icon: Icons.event_repeat_rounded,
                title: s.pn('Create next year first', 'Créez d\'abord l\'année suivante'),
                description: s.pn('Promotion moves students from one academic year to another. Create the new year in the Academic calendar, then come back here.', 'La promotion fait passer les élèves d\'une année scolaire à une autre. Créez la nouvelle année dans le Calendrier scolaire, puis revenez ici.'),
              ),
            ),
          ]);
        }
        // years are newest-first
        final current = years.firstWhere((y) => y.isCurrent, orElse: () => years[1]);
        _from ??= current.id;
        _to ??= years.firstWhere((y) => y.start != null && current.start != null && y.start!.isAfter(current.start!), orElse: () => years.first).id;

        final key = (_from != null && _to != null && _from != _to) ? (from: _from!, to: _to!) : null;
        final dataAsync = key == null ? null : ref.watch(_promoDataProvider(key));

        PnPromoData? data = dataAsync?.valueOrNull;
        if (data != null && !_seeded) {
          _pass.text = data.passMark.toStringAsFixed(data.passMark == data.passMark.roundToDouble() ? 0 : 1);
          _margin.text = data.margin.toStringAsFixed(data.margin == data.margin.roundToDouble() ? 0 : 1);
          _balance = data.balance;
          _seeded = true;
        }

        PnPlan? plan;
        if (data != null) {
          plan = PnPlanner(data: data, passMark: _passValue, margin: _marginValue, balance: _balance, manual: Map.of(_manual), excluded: Set.of(_excluded)).plan();
        }

        return Stack(children: [
          PrPage(
            onRefresh: () async {
              ref.invalidate(_promoDataProvider);
              ref.invalidate(pnPromotionHistoryProvider);
            },
            children: [
              PrHeader(
                title: s.pn('Promotion', 'Promotion'),
                subtitle: s.pn('Set the pass mark, preview where every student goes, adjust anyone, then apply. Nothing changes until you press Apply.', 'Définissez la barre de passage, visualisez la destination de chaque élève, ajustez au besoin, puis appliquez. Rien ne change avant d\'appuyer sur Appliquer.'),
              ),
              _setup(years),
              const SizedBox(height: 16),
              if (key == null)
                PnNotice(text: s.pn('Choose two different years.', 'Choisissez deux années différentes.'), icon: Icons.info_outline_rounded)
              else
                dataAsync!.when(
                  loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => SizedBox(height: 240, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(_promoDataProvider(key)))),
                  data: (d) => _preview(d, plan ?? PnPlanner(data: d, passMark: _passValue, margin: _marginValue, balance: _balance).plan()),
                ),
              const SizedBox(height: 24),
              _history(),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: Container(color: Colors.black26, alignment: Alignment.center, child: const CircularProgressIndicator()),
            ),
        ]);
      },
    );
  }

  // ------------------------------------------------------------ setup

  Widget _setup(List<PnYear> years) {
    final s = _s;
    Widget yearDd(String label, String? value, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: pnDeco(label),
          items: [for (final y in years) DropdownMenuItem(value: y.id, child: Text(y.name))],
          onChanged: onChanged,
        );

    return PrReveal(
      child: PnPanel(
        title: s.pn('1. Years and rules', '1. Années et règles'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, c) {
            final a = yearDd(s.pn('Promote students from', 'Promouvoir les élèves de'), _from, (v) => setState(() {
                  _from = v;
                  _resetPlanState();
                }));
            final b = yearDd(s.pn('into the year', 'vers l\'année'), _to, (v) => setState(() {
                  _to = v;
                  _resetPlanState();
                }));
            final pass = TextField(
              controller: _pass,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: pnDeco(s.pn('Pass mark (out of 20)', 'Barre de passage (sur 20)')),
            );
            final margin = TextField(
              controller: _margin,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: pnDeco(s.pn('Borderline margin', 'Marge limite'), hint: s.pn('e.g. 1 = 9 to 9.99', 'ex. 1 = 9 à 9,99')),
            );
            if (c.maxWidth < 640) {
              return Column(children: [a, const SizedBox(height: 12), b, const SizedBox(height: 12), pass, const SizedBox(height: 12), margin]);
            }
            return Column(children: [
              Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: pass), const SizedBox(width: 12), Expanded(child: margin)]),
            ]);
          }),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _balance,
            onChanged: (v) => setState(() => _balance = v),
            title: Text(s.pn('Spread students evenly across classes', 'Répartir équitablement les élèves entre les classes')),
            subtitle: Text(s.pn('Used when the matching class (1A → 2A) does not exist or is full.', 'Utilisé quand la classe correspondante (1A → 2A) n\'existe pas ou est pleine.')),
          ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _saveDefaults, icon: const Icon(Icons.save_outlined, size: 18), label: Text(s.pn('Save as the school default', 'Enregistrer par défaut pour l\'école')))),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ preview

  Widget _preview(PnPromoData data, PnPlan plan) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final classes = {for (final c in data.classes) c.id: c};

    bool shown(PnPlanRow r) {
      if (_classFilter != null && r.student.classId != _classFilter) return false;
      switch (_show) {
        case 'promoted':
          return r.outcome == PnOutcome.promoted;
        case 'repeat':
          return r.outcome == PnOutcome.repeat;
        case 'graduated':
          return r.outcome == PnOutcome.graduated;
        case 'attention':
          return r.flag == PnFlag.borderline || r.flag == PnFlag.noSeat || r.flag == PnFlag.noAverage || r.flag == PnFlag.crossDepartment;
        default:
          return true;
      }
    }

    final visible = plan.rows.where(shown).toList();
    final applicable = plan.rows.where((r) => r.applicable).toList();
    final fromClasses = data.classes.where((c) => data.students.any((st) => st.classId == c.id)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PrGrid(minTile: 170, max: 5, children: [
        PrStatTile(icon: Icons.trending_up_rounded, label: s.pn('Promoted', 'Promus'), value: plan.count(PnOutcome.promoted).toDouble(), format: (v) => '${v.round()}'),
        PrStatTile(icon: Icons.replay_rounded, label: s.pn('Repeating', 'Redoublants'), value: plan.count(PnOutcome.repeat).toDouble(), format: (v) => '${v.round()}', footer: plan.borderline > 0 ? Text('${plan.borderline} ${s.pn('borderline', 'limites')}', style: theme.textTheme.labelSmall?.copyWith(color: pnWarn())) : null),
        PrStatTile(icon: Icons.school_outlined, label: s.pn('Graduating', 'Diplômés'), value: plan.count(PnOutcome.graduated).toDouble(), format: (v) => '${v.round()}'),
        PrStatTile(icon: Icons.help_outline_rounded, label: s.pn('Need a decision', 'À décider'), value: (plan.held + plan.noSeat).toDouble(), format: (v) => '${v.round()}'),
        PrStatTile(icon: Icons.check_circle_outline_rounded, label: s.pn('Already placed', 'Déjà placés'), value: plan.alreadyPlaced.toDouble(), format: (v) => '${v.round()}'),
      ]),
      const SizedBox(height: 16),
      if (plan.noSeat > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PnNotice(
            color: pnWarn(),
            icon: Icons.event_seat_outlined,
            text: s.pn('${plan.noSeat} student(s) have no free seat (or no class exists at their next level). Raise a class capacity, create the class, or choose a class manually on their row.', '${plan.noSeat} élève(s) n\'ont pas de place libre (ou aucune classe n\'existe à leur niveau suivant). Augmentez une capacité, créez la classe, ou choisissez une classe manuellement sur sa ligne.'),
          ),
        ),
      if (plan.held > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PnNotice(
            icon: Icons.hourglass_empty_rounded,
            text: s.pn('${plan.held} student(s) have no annual average yet (no report cards). Generate the annual report cards first, or decide for them manually.', '${plan.held} élève(s) n\'ont pas encore de moyenne annuelle (pas de bulletins). Générez d\'abord les bulletins annuels, ou décidez manuellement.'),
          ),
        ),
      _capacity(data, plan),
      const SizedBox(height: 16),
      PnPanel(
        title: s.pn('2. Review each student', '2. Vérifier chaque élève'),
        subtitle: s.pn('Tap a student to choose a different outcome or class. Untick anyone you do not want to include in this run.', 'Touchez un élève pour choisir un autre résultat ou une autre classe. Décochez ceux que vous ne voulez pas inclure.'),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String?>(
                initialValue: _classFilter,
                isExpanded: true,
                decoration: pnDeco(s.pn('Class', 'Classe')),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(s.pn('All classes', 'Toutes les classes'))),
                  for (final c in fromClasses) DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _classFilter = v),
              ),
              const SizedBox(height: 12),
              PrPills<String>(
                values: const ['all', 'promoted', 'repeat', 'graduated', 'attention'],
                selected: _show,
                label: (v) {
                  switch (v) {
                    case 'promoted':
                      return s.pn('Promoted', 'Promus');
                    case 'repeat':
                      return s.pn('Repeating', 'Redoublants');
                    case 'graduated':
                      return s.pn('Graduating', 'Diplômés');
                    case 'attention':
                      return s.pn('Needs attention', 'À vérifier');
                    default:
                      return s.pn('Everyone', 'Tous');
                  }
                },
                onChanged: (v) => setState(() => _show = v),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                TextButton(
                  onPressed: () => setState(() {
                    for (final r in visible) {
                      _excluded.remove(r.student.id);
                    }
                  }),
                  child: Text(s.pn('Select all shown', 'Tout sélectionner')),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    for (final r in visible) {
                      _excluded.add(r.student.id);
                    }
                  }),
                  child: Text(s.pn('Clear all shown', 'Tout désélectionner')),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(s.pn('Nobody matches this filter.', 'Personne ne correspond à ce filtre.'), style: TextStyle(color: cs.outline))))
          else
            for (var i = 0; i < visible.length; i++) ...[
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
              _StudentRow(
                row: visible[i],
                strings: s,
                classes: classes,
                passMark: _passValue,
                onToggle: (v) => setState(() {
                  if (v) {
                    _excluded.remove(visible[i].student.id);
                  } else {
                    _excluded.add(visible[i].student.id);
                  }
                }),
                onTap: () => _decide(visible[i], data, plan),
              ),
            ],
        ]),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: applicable.isEmpty || _busy ? null : () => _apply(data, plan),
          icon: const Icon(Icons.check_rounded),
          label: Text(s.pn('Apply promotion (${applicable.length})', 'Appliquer la promotion (${applicable.length})')),
        ),
      ),
    ]);
  }

  Widget _capacity(PnPromoData data, PnPlan plan) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final targets = data.classes.where((c) => (plan.planned[c.id] ?? 0) > 0 || c.enrolledTo > 0).toList()
      ..sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.name.compareTo(b.name));
    if (targets.isEmpty) return const SizedBox.shrink();

    return PnPanel(
      title: s.pn('Where they will go', 'Où ils iront'),
      subtitle: s.pn('Seats in each class of the new year after this promotion.', 'Places dans chaque classe de la nouvelle année après cette promotion.'),
      child: Column(children: [
        for (final c in targets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(c.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                Text('${c.enrolledTo + (plan.planned[c.id] ?? 0)}${c.max > 0 ? ' / ${c.max}' : ''}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: (c.max > 0 && c.enrolledTo + (plan.planned[c.id] ?? 0) > c.max) ? pnBad() : cs.outline)),
              ]),
              const SizedBox(height: 5),
              PrProgressBar(value: c.max <= 0 ? 0 : (c.enrolledTo + (plan.planned[c.id] ?? 0)) / c.max, height: 7, color: (c.max > 0 && c.enrolledTo + (plan.planned[c.id] ?? 0) >= c.max) ? pnWarn() : cs.primary),
            ]),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------ history

  Widget _history() {
    final s = _s;
    final async = ref.watch(pnPromotionHistoryProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (runs) {
        if (runs.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return PnPanel(
          title: s.pn('Promotion history', 'Historique des promotions'),
          child: Column(children: [
            for (final r in runs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r.from} → ${r.to}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${r.promoted} ${s.pn('promoted', 'promus')} · ${r.repeated} ${s.pn('repeating', 'redoublants')} · ${r.graduated} ${s.pn('graduated', 'diplômés')}  ·  ${r.createdAt == null ? '' : pDateTime(r.createdAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ]),
                  ),
                  if (r.isUndone) PnChip(label: s.pn('Undone', 'Annulée'), color: theme.colorScheme.outline) else TextButton(onPressed: () => _undo(r), child: Text(s.pn('Undo', 'Annuler'))),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

// ============================================================ student row

class _StudentRow extends StatelessWidget {
  final PnPlanRow row;
  final AppStrings strings;
  final Map<String, PnPromoClass> classes;
  final double passMark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  const _StudentRow({required this.row, required this.strings, required this.classes, required this.passMark, required this.onToggle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final from = row.from?.name ?? '';
    final to = row.toClassId == null ? null : classes[row.toClassId!]?.name;
    final placed = row.flag == PnFlag.alreadyPlaced;

    String outcomeText;
    Color outcomeColor;
    switch (row.outcome) {
      case PnOutcome.promoted:
        outcomeText = s.pn('Promoted', 'Promu');
        outcomeColor = pnGood();
        break;
      case PnOutcome.repeat:
        outcomeText = s.pn('Repeats', 'Redouble');
        outcomeColor = pnWarn();
        break;
      case PnOutcome.graduated:
        outcomeText = s.pn('Graduates', 'Diplômé');
        outcomeColor = cs.primary;
        break;
      case PnOutcome.held:
        outcomeText = s.pn('Undecided', 'À décider');
        outcomeColor = cs.outline;
        break;
    }
    if (placed) {
      outcomeText = s.pn('Already placed', 'Déjà placé');
      outcomeColor = cs.outline;
    }

    final flagChips = <Widget>[
      if (row.flag == PnFlag.borderline) PnChip(label: s.pn('Borderline', 'Limite'), color: pnWarn(), icon: Icons.balance_rounded),
      if (row.flag == PnFlag.noSeat) PnChip(label: s.pn('No seat', 'Sans place'), color: pnBad(), icon: Icons.event_seat_outlined),
      if (row.flag == PnFlag.noAverage) PnChip(label: s.pn('No average', 'Sans moyenne'), color: cs.outline),
      if (row.flag == PnFlag.crossDepartment) PnChip(label: s.pn('Other department', 'Autre département'), color: cs.primary),
      if (row.manual) PnChip(label: s.pn('Manual', 'Manuel'), color: cs.primary, icon: Icons.edit_outlined),
    ];

    return InkWell(
      onTap: placed ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(children: [
          Checkbox(value: row.include, onChanged: placed || (!row.include && row.outcome == PnOutcome.held) ? null : (v) => onToggle(v ?? false)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.student.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                [from, if (to != null) '→ $to' else if (row.outcome == PnOutcome.graduated) '→ ${s.pn('left the school', 'sort de l\'école')}'].where((e) => e.isNotEmpty).join('  '),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [PnChip(label: outcomeText, color: outcomeColor), ...flagChips]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(pnAvg(row.student.average), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: row.student.average == null ? cs.outline : null)),
            Text(row.student.termsCounted == -1 ? s.pn('annual', 'annuelle') : (row.student.termsCounted > 0 ? '${row.student.termsCounted} ${s.pn('term(s)', 'trim.')}' : ''), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
          ]),
          if (!placed) Icon(Icons.chevron_right_rounded, color: cs.outline),
        ]),
      ),
    );
  }
}

// ============================================================ decision sheet

class _DecisionSheet extends StatefulWidget {
  final AppStrings strings;
  final PnPlanRow row;
  final PnPromoData data;
  final PnPlan plan;
  const _DecisionSheet({required this.strings, required this.row, required this.data, required this.plan});

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  late PnOutcome _outcome = widget.row.outcome == PnOutcome.held ? PnOutcome.repeat : widget.row.outcome;
  late String? _class = widget.row.toClassId;

  AppStrings get _s => widget.strings;

  int _free(PnPromoClass c) {
    if (c.max <= 0) return 9999;
    final planned = widget.plan.planned[c.id] ?? 0;
    // the student's own current planned seat is theirs to keep
    final mine = widget.row.toClassId == c.id ? 1 : 0;
    return c.max - c.enrolledTo - planned + mine;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final r = widget.row;
    final needsClass = _outcome == PnOutcome.promoted || _outcome == PnOutcome.repeat;
    final fromLevel = r.from?.level ?? 0;
    final candidates = widget.data.classes.where((c) => _outcome == PnOutcome.promoted ? c.level > fromLevel : c.level >= fromLevel).toList()
      ..sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.name.compareTo(b.name));
    if (_class != null && !candidates.any((c) => c.id == _class)) _class = null;

    return PnSheetBody(
      title: r.student.fullName,
      subtitle: '${r.from?.name ?? ''}  ·  ${s.pn('Average', 'Moyenne')} ${pnAvg(r.student.average)}',
      children: [
        Text(s.pn('Outcome', 'Résultat'), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        PrPills<PnOutcome>(
          values: const [PnOutcome.promoted, PnOutcome.repeat, PnOutcome.graduated, PnOutcome.held],
          selected: _outcome,
          label: (v) {
            switch (v) {
              case PnOutcome.promoted:
                return s.pn('Promote', 'Promouvoir');
              case PnOutcome.repeat:
                return s.pn('Repeat', 'Redoubler');
              case PnOutcome.graduated:
                return s.pn('Graduate', 'Diplômer');
              case PnOutcome.held:
                return s.pn('Decide later', 'Décider plus tard');
            }
          },
          onChanged: (v) => setState(() => _outcome = v),
        ),
        if (needsClass) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _class,
            isExpanded: true,
            decoration: pnDeco(s.pn('Class in the new year', 'Classe dans la nouvelle année')),
            items: [
              for (final c in candidates)
                DropdownMenuItem(
                  value: c.id,
                  enabled: _free(c) > 0,
                  child: Text('${c.name}  ·  ${_free(c) >= 9999 ? s.pn('no limit', 'sans limite') : '${_free(c)} ${s.pn('free', 'libres')}'}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _class = v),
          ),
        ],
      ],
      actions: [
        if (r.manual) TextButton(onPressed: () => Navigator.pop(context, 'reset'), child: Text(s.pn('Back to automatic', 'Revenir à l\'automatique'))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(
          onPressed: needsClass && _class == null ? null : () => Navigator.pop(context, PnManual(_outcome, needsClass ? _class : null)),
          child: Text(s.pn('Save', 'Enregistrer')),
        ),
      ],
    );
  }
}

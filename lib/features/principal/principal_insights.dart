import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_charts.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';
import 'principal_kit.dart';

// ============================================================
// PERFORMANCE ANALYTICS + AI INSIGHTS
// One database call per sequence draws every chart on the page.
// ============================================================

enum _InsightTab { performance, ai }

class PrincipalInsightsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalInsightsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalInsightsPage> createState() => _PrincipalInsightsPageState();
}

class _PrincipalInsightsPageState extends ConsumerState<PrincipalInsightsPage> {
  _InsightTab _tab = _InsightTab.performance;
  String? _period; // null = latest sequence that has marks

  // AI state
  final _question = TextEditingController();
  bool _generating = false;
  bool _asking = false;
  String? _answer;
  String? _asked;
  String? _aiError;

  AppStrings get _s => widget.strings;
  String get _lang => _s.isFrench ? 'fr' : 'en';

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _generate(String? periodId) async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _aiError = null;
    });
    try {
      await ref.read(principalHubRepositoryProvider).generateAiReport(lang: _lang, periodId: periodId);
      ref.invalidate(pnAiReportProvider(widget.schoolId));
      await ref.read(pnAiReportProvider(widget.schoolId).future);
    } catch (e) {
      if (mounted) setState(() => _aiError = _clean(e));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _ask(String? periodId, [String? preset]) async {
    final q = (preset ?? _question.text).trim();
    if (q.isEmpty || _asking) return;
    if (preset != null) _question.text = preset;
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _answer = null;
      _asked = q;
      _aiError = null;
    });
    try {
      final a = await ref.read(principalHubRepositoryProvider).askAi(lang: _lang, question: q, periodId: periodId);
      if (mounted) setState(() => _answer = a);
    } catch (e) {
      if (mounted) setState(() => _aiError = _clean(e));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final async = ref.watch(pnAnalyticsProvider(_period));
    return PrPage(
      onRefresh: () async {
        ref.invalidate(pnAnalyticsProvider(_period));
        ref.invalidate(pnAiReportProvider(widget.schoolId));
      },
      children: [
        PrHeader(
          title: s.pn('Performance & insights', 'Performance et analyses'),
          subtitle: s.pn('How the school is doing, sequence by sequence, with an AI reading of the numbers.', 'Où en est l’établissement, séquence par séquence, avec une lecture des chiffres par l’IA.'),
        ),
        const SizedBox(height: 4),
        PrPills<_InsightTab>(
          values: _InsightTab.values,
          selected: _tab,
          label: (t) => t == _InsightTab.performance ? s.pn('Performance', 'Performance') : s.pn('AI insights', 'Analyses IA'),
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 16),
        PnAsync<PnAnalytics>(
          value: async,
          strings: s,
          skeletonRows: 4,
          onRetry: () => ref.invalidate(pnAnalyticsProvider(_period)),
          builder: (a) {
            final effective = _period ?? a.periodId;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim), child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey('${_tab.name}-$effective'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _periodPicker(a),
                  const SizedBox(height: 16),
                  if (_tab == _InsightTab.performance) _performance(a) else _ai(a),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------ period picker

  Widget _periodPicker(PnAnalytics a) {
    final s = _s;
    final withMarks = a.periods.where((p) => p.hasMarks).toList();
    if (withMarks.length < 2) return const SizedBox.shrink();
    final selected = withMarks.any((p) => p.id == (_period ?? a.periodId)) ? (_period ?? a.periodId) : null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: PrPills<String?>(
        values: withMarks.map((p) => p.id as String?).toList(),
        selected: selected,
        label: (id) => withMarks.firstWhere((p) => p.id == id, orElse: () => withMarks.first).name,
        onChanged: (id) => setState(() => _period = id),
      ),
    );
  }

  // ------------------------------------------------------ performance

  Color _tone(double? avg, double pass) {
    if (avg == null) return Colors.grey;
    if (avg >= pass + 2) return pnGood();
    if (avg >= pass) return pnWarn();
    return pnBad();
  }

  Widget _performance(PnAnalytics a) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!a.hasMarks) {
      return PrCard(
        child: PnEmpty(
          icon: Icons.insights_rounded,
          title: s.pn('No approved marks yet', 'Aucune note approuvée pour le moment'),
          text: s.pn('Charts appear as soon as marks are approved for a sequence.${a.marksWaiting > 0 ? ' ${a.marksWaiting} marks are waiting for your review.' : ''}',
              'Les graphiques apparaissent dès que des notes sont approuvées pour une séquence.${a.marksWaiting > 0 ? ' ${a.marksWaiting} notes attendent votre révision.' : ''}'),
        ),
      );
    }

    final trend = a.trend.where((t) => t.average != null).toList();
    final classes = a.classes;
    final subjects = a.subjects;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ---- headline numbers
      PrGrid(minTile: 170, max: 4, children: [
        PrStatTile(
          icon: Icons.grade_rounded,
          label: s.pn('School average', 'Moyenne de l’école'),
          value: a.average ?? 0,
          format: (v) => '${v.toStringAsFixed(2)} / 20',
          footer: Text(s.pn('Pass mark ${a.passMark.toStringAsFixed(a.passMark % 1 == 0 ? 0 : 1)}', 'Moyenne requise ${a.passMark.toStringAsFixed(a.passMark % 1 == 0 ? 0 : 1)}'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ),
        PrStatTile(
          icon: Icons.verified_rounded,
          label: s.pn('Pass rate', 'Taux de réussite'),
          value: a.passRate ?? 0,
          format: (v) => '${v.toStringAsFixed(1)}%',
          footer: Text(s.pn('${a.students} students ranked', '${a.students} élèves classés'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ),
        PrStatTile(
          icon: Icons.warning_amber_rounded,
          label: s.pn('Below pass mark', 'Sous la moyenne'),
          value: a.atRiskCount.toDouble(),
          format: (v) => v.round().toString(),
          footer: Text(s.pn('students need support', 'élèves à accompagner'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ),
        PrStatTile(
          icon: Icons.payments_rounded,
          label: s.pn('Fees collected', 'Frais encaissés'),
          value: a.collectionRate ?? 0,
          format: (v) => a.collectionRate == null ? '–' : '${v.toStringAsFixed(0)}%',
          footer: Text(a.debtors == 0 ? s.pn('No overdue balances', 'Aucun impayé') : s.pn('${a.debtors} with overdue balances', '${a.debtors} avec des impayés'), style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ),
      ]),
      if (a.marksWaiting > 0) ...[
        const SizedBox(height: 14),
        PnNotice(
          icon: Icons.hourglass_top_rounded,
          color: pnWarn(),
          text: s.pn('${a.marksWaiting} marks for this sequence are still waiting for review, so these figures may change.', '${a.marksWaiting} notes de cette séquence attendent encore une révision ; ces chiffres peuvent donc évoluer.'),
        ),
      ],
      const SizedBox(height: 16),

      // ---- trend
      if (trend.length >= 2)
        PrReveal(
          index: 0,
          child: PnPanel(
            title: s.pn('Progress through the year', 'Évolution dans l’année'),
            subtitle: s.pn('Average (out of 20) per sequence', 'Moyenne (sur 20) par séquence'),
            child: PrLineChart(
              height: 220,
              labels: trend.map((t) => t.name).toList(),
              series: [PrLineSeries(name: s.pn('Average', 'Moyenne'), color: cs.primary, values: trend.map((t) => t.average ?? 0).toList())],
              axisFormat: (v) => v.toStringAsFixed(0),
              tipFor: (i) => PrTip(title: trend[i].name, rows: [
                PrTipRow(label: s.pn('Average', 'Moyenne'), value: '${(trend[i].average ?? 0).toStringAsFixed(2)} / 20', color: cs.primary),
                PrTipRow(label: s.pn('Pass rate', 'Réussite'), value: '${(trend[i].passRate ?? 0).toStringAsFixed(1)}%', color: pnGood()),
                PrTipRow(label: s.pn('Students', 'Élèves'), value: '${trend[i].students}', color: cs.outline),
              ]),
            ),
          ),
        ),
      if (trend.length >= 2) const SizedBox(height: 16),

      // ---- classes + distribution
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 860;
        final classesPanel = PrReveal(
          index: 1,
          child: PnPanel(
            title: s.pn('Classes', 'Classes'),
            subtitle: s.pn('Average per class, best first', 'Moyenne par classe, de la meilleure à la plus faible'),
            child: _barRows(classes, a.passMark, showTeachers: false),
          ),
        );
        final distPanel = PrReveal(
          index: 2,
          child: PnPanel(
            title: s.pn('How marks are spread', 'Répartition des moyennes'),
            subtitle: s.pn('Number of students in each average band', 'Nombre d’élèves par tranche de moyenne'),
            child: PrBarChart(
              height: 220,
              labels: a.distribution.map((e) => e.key).toList(),
              series: [
                PrBarSeries(
                  name: s.pn('Students', 'Élèves'),
                  color: cs.primary,
                  values: a.distribution.map((e) => e.value.toDouble()).toList(),
                  valueColors: [
                    for (final e in a.distribution) _bandColor(e.key, a.passMark),
                  ],
                ),
              ],
              axisFormat: (v) => v.round().toString(),
              tipFor: (i) => PrTip(title: '${a.distribution[i].key} / 20', rows: [
                PrTipRow(label: s.pn('Students', 'Élèves'), value: '${a.distribution[i].value}', color: _bandColor(a.distribution[i].key, a.passMark)),
              ]),
            ),
          ),
        );
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: classesPanel),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: distPanel),
          ]);
        }
        return Column(children: [classesPanel, const SizedBox(height: 16), distPanel]);
      }),
      const SizedBox(height: 16),

      // ---- subjects
      PrReveal(
        index: 3,
        child: PnPanel(
          title: s.pn('Subjects', 'Matières'),
          subtitle: s.pn('Average mark and share of marks at or above the pass mark', 'Note moyenne et part des notes au-dessus de la moyenne requise'),
          child: _barRows(subjects, a.passMark, showTeachers: false, passLabel: true),
        ),
      ),
      const SizedBox(height: 16),

      // ---- gender
      if (a.gender.length >= 2) ...[
        PrReveal(
          index: 4,
          child: PnPanel(
            title: s.pn('Girls and boys', 'Filles et garçons'),
            child: Row(children: [
              for (var i = 0; i < a.gender.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _genderTile(a.gender[i], a.passMark)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ],

      // ---- teachers
      if (a.teachers.isNotEmpty) ...[
        PrReveal(
          index: 5,
          child: PnPanel(
            title: s.pn('Marks given by teacher', 'Notes attribuées par enseignant'),
            subtitle: s.pn('These describe the marks a teacher gave, not teaching quality. Very high or very low figures are a reason to review an assessment, not to judge.', 'Ces chiffres décrivent les notes attribuées, pas la qualité de l’enseignement. Des valeurs très hautes ou très basses invitent à revoir l’évaluation, pas à juger.'),
            child: Column(children: [
              for (var i = 0; i < a.teachers.length; i++) _teacherRow(a.teachers[i], a.passMark),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ],

      // ---- people
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 860;
        final risk = PrReveal(
          index: 6,
          child: PnPanel(
            title: s.pn('Needs support', 'À accompagner'),
            subtitle: s.pn('Lowest averages in this sequence', 'Moyennes les plus basses de cette séquence'),
            child: a.atRisk.isEmpty
                ? PnEmpty(icon: Icons.celebration_rounded, title: s.pn('Everyone is at or above the pass mark', 'Tous les élèves sont au-dessus de la moyenne requise'))
                : Column(children: [for (final p in a.atRisk) _personRow(p, pnBad())]),
          ),
        );
        final top = PrReveal(
          index: 7,
          child: PnPanel(
            title: s.pn('Top students', 'Meilleurs élèves'),
            subtitle: s.pn('Highest averages in this sequence', 'Meilleures moyennes de cette séquence'),
            child: Column(children: [for (final p in a.top) _personRow(p, pnGood())]),
          ),
        );
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: risk), const SizedBox(width: 16), Expanded(child: top)]);
        }
        return Column(children: [risk, const SizedBox(height: 16), top]);
      }),
    ]);
  }

  Color _bandColor(String label, double pass) {
    final lo = double.tryParse(label.split('-').first) ?? 0;
    final hi = double.tryParse(label.split('-').last) ?? 20;
    if (hi <= pass) return pnBad().withValues(alpha: 0.85);
    if (lo < pass) return pnWarn().withValues(alpha: 0.9);
    return Theme.of(context).colorScheme.primary;
  }

  /// A ranked list: name, a bar scaled to 20, the average, and optionally
  /// the share of marks that pass.
  Widget _barRows(List<PnAnRow> rows, double pass, {required bool showTeachers, bool passLabel = false}) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (rows.isEmpty) return PnEmpty(icon: Icons.bar_chart_rounded, title: s.pn('Nothing to show yet', 'Rien à afficher pour le moment'));
    return Column(children: [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(rows[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Text(rows[i].average == null ? '–' : rows[i].average!.toStringAsFixed(2), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: _tone(rows[i].average, pass))),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: Text(
                  rows[i].passRate == null ? '' : (passLabel ? s.pn('${rows[i].passRate!.toStringAsFixed(0)}% pass', '${rows[i].passRate!.toStringAsFixed(0)}% réussite') : '${rows[i].passRate!.toStringAsFixed(0)}% ✓'),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            _AnimatedBar(value: ((rows[i].average ?? 0) / 20).clamp(0.0, 1.0).toDouble(), markAt: (pass / 20).clamp(0.0, 1.0).toDouble(), color: _tone(rows[i].average, pass), delay: i),
          ]),
        ),
    ]);
  }

  Widget _genderTile(PnAnGender g, double pass) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = g.gender.toLowerCase().startsWith('f') ? s.pn('Girls', 'Filles') : s.pn('Boys', 'Garçons');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: cs.outline, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(g.average == null ? '–' : '${g.average!.toStringAsFixed(2)} / 20', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: _tone(g.average, pass))),
        const SizedBox(height: 2),
        Text(s.pn('${g.students} students · ${(g.passRate ?? 0).toStringAsFixed(0)}% pass', '${g.students} élèves · ${(g.passRate ?? 0).toStringAsFixed(0)}% réussite'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
      ]),
    );
  }

  Widget _teacherRow(PnAnRow t, double pass) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        PnAvatar(stored: t.photo, bucket: pnStaffPhotos, name: t.name, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(s.pn('${t.count} marks · ${t.extra} class${t.extra == 1 ? '' : 'es'}', '${t.count} notes · ${t.extra} classe${t.extra == 1 ? '' : 's'}'), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(t.average == null ? '–' : t.average!.toStringAsFixed(2), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: _tone(t.average, pass))),
          Text('${(t.passRate ?? 0).toStringAsFixed(0)}% ${s.pn('pass', 'réussite')}', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ]),
      ]),
    );
  }

  Widget _personRow(PnAnPerson p, Color tone) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        PnAvatar(stored: p.photo, name: p.name, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(p.className, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          ]),
        ),
        PnChip(label: p.average.toStringAsFixed(2), color: tone),
      ]),
    );
  }

  // ------------------------------------------------------ AI

  Widget _ai(PnAnalytics a) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final latest = ref.watch(pnAiReportProvider(widget.schoolId));
    final report = latest.valueOrNull;
    final periodId = _period ?? a.periodId;

    final suggestions = [
      s.pn('Which class needs the most help, and why?', 'Quelle classe a le plus besoin d’aide, et pourquoi ?'),
      s.pn('Which subjects have the most failures?', 'Quelles matières ont le plus d’échecs ?'),
      s.pn('How did results change between sequences?', 'Comment les résultats ont-ils évolué entre les séquences ?'),
      s.pn('What should I do first this week?', 'Que dois-je faire en priorité cette semaine ?'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrReveal(
        child: PrCard(
          child: LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 560;
            final info = Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(report == null ? s.pn('No analysis yet', 'Aucune analyse pour le moment') : '${s.pn('Generated', 'Générée le')} ${pDateTime(report.generatedAt)}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    _generating
                        ? s.pn('Reading your marks, fees and classes…', 'Lecture des notes, des frais et des classes…')
                        : s.pn('The AI only uses the figures recorded in your system. Always check important decisions yourself.', 'L’IA n’utilise que les chiffres enregistrés dans votre système. Vérifiez toujours vous-même les décisions importantes.'),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, height: 1.35),
                  ),
                ]),
              ),
            ]);
            final button = FilledButton.icon(
              onPressed: (_generating || !a.hasMarks) ? null : () => _generate(periodId),
              icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bolt_rounded, size: 18),
              label: Text(report == null ? s.pn('Analyse the school', 'Analyser l’établissement') : s.pn('Analyse again', 'Analyser à nouveau')),
            );
            return narrow
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 14), button])
                : Row(children: [Expanded(child: info), const SizedBox(width: 16), button]);
          }),
        ),
      ),
      if (!a.hasMarks) ...[
        const SizedBox(height: 12),
        PnNotice(text: s.pn('Approve some marks first, so the analysis has something to read.', 'Approuvez d’abord quelques notes pour que l’analyse ait de la matière.')),
      ],
      if (_aiError != null) ...[
        const SizedBox(height: 12),
        PnNotice(icon: Icons.error_outline_rounded, color: pnBad(), text: _aiError!),
      ],
      const SizedBox(height: 16),
      if (_generating) const PrSkeleton(height: 220, radius: 22) else if (report != null) _reportView(report),
      const SizedBox(height: 16),
      PrReveal(
        index: 2,
        child: PnPanel(
          title: s.pn('Ask a question', 'Poser une question'),
          subtitle: s.pn('Answers use the figures of the selected sequence.', 'Les réponses utilisent les chiffres de la séquence choisie.'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in suggestions)
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12.5)),
                  onPressed: (_asking || !a.hasMarks) ? null : () => _ask(periodId, q),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _question,
                  enabled: !_asking,
                  maxLength: 600,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ask(periodId),
                  decoration: pnDeco(s.pn('Type your question', 'Saisissez votre question'), icon: Icons.chat_bubble_outline_rounded).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: (_asking || !a.hasMarks) ? null : () => _ask(periodId),
                icon: _asking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded),
                tooltip: s.pn('Ask', 'Demander'),
              ),
            ]),
            if (_asking) ...[const SizedBox(height: 14), const PrSkeleton(height: 70, radius: 14)],
            if (_answer != null && _asked != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withValues(alpha: 0.18))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_asked!, style: theme.textTheme.labelLarge?.copyWith(color: cs.outline, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(_answer!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _reportView(PnAiReport r) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget list(String title, IconData icon, Color color, List<String> items, int index) {
      if (items.isEmpty) return const SizedBox.shrink();
      return PrReveal(
        index: index,
        child: PnPanel(
          title: title,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final t in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
                  const SizedBox(width: 10),
                  Expanded(child: SelectableText(t, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))),
                ]),
              ),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrReveal(
        child: PrCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.pn('Summary', 'Synthèse'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
            const SizedBox(height: 8),
            SelectableText(r.summary, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      list(s.pn('What is going well', 'Ce qui va bien'), Icons.check_circle_rounded, pnGood(), r.strengths, 1),
      const SizedBox(height: 12),
      list(s.pn('Needs attention', 'Points d’attention'), Icons.error_outline_rounded, pnWarn(), r.concerns, 2),
      const SizedBox(height: 12),
      list(s.pn('Suggested next steps', 'Prochaines étapes suggérées'), Icons.arrow_circle_right_rounded, cs.primary, r.recommendations, 3),
    ]);
  }
}

/// Horizontal bar that grows in, with a thin tick at the pass mark.
class _AnimatedBar extends StatelessWidget {
  final double value; // 0..1
  final double markAt; // 0..1
  final Color color;
  final int delay;
  const _AnimatedBar({required this.value, required this.markAt, required this.color, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 8,
        child: Stack(children: [
          Container(decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: Duration(milliseconds: 600 + (delay.clamp(0, 8) as int) * 70),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(width: w * v, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
          ),
          Positioned(left: (w * markAt) - 1, top: 0, bottom: 0, child: Container(width: 2, color: cs.onSurface.withValues(alpha: 0.35))),
        ]),
      );
    });
  }
}

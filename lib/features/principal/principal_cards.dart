import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;
import '../proprietor/proprietor_export.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_card_pdf.dart';
import 'principal_core.dart';
import 'principal_kit.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Rankings and report cards. One screen: pick a scope (sequence, term
/// or the whole year), a period and a class; see every student ranked;
/// generate or recalculate in one call; publish when ready.
class PrincipalCardsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final AppStrings strings;
  const PrincipalCardsPage({super.key, required this.schoolId, required this.landing, required this.strings});

  @override
  ConsumerState<PrincipalCardsPage> createState() => _PrincipalCardsPageState();
}

class _PrincipalCardsPageState extends ConsumerState<PrincipalCardsPage> {
  String _scope = 'sequence';
  String? _yearId;
  String? _termId;
  String? _periodId;
  String? _classId;

  bool _busy = false;
  String _status = '';
  double? _progress;

  OfficialBranding? _branding;
  pw.MemoryImage? _logo;

  AppStrings get _s => widget.strings;

  PnBoardKey? get _key {
    if (_yearId == null || _classId == null) return null;
    if (_scope == 'sequence' && _periodId == null) return null;
    if (_scope == 'term' && _termId == null) return null;
    return (classId: _classId!, scope: _scope, yearId: _yearId!, termId: _scope == 'term' ? _termId : null, periodId: _scope == 'sequence' ? _periodId : null);
  }

  void _toast(String m) {
    if (mounted) prSnack(context, m);
  }

  Future<void> _loadBranding() async {
    if (_branding != null) return;
    OfficialBranding b;
    try {
      final assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
      b = await OfficialBranding.fetch(assets);
    } catch (_) {
      b = const OfficialBranding();
    }
    pw.MemoryImage? logo;
    if (b.letterhead == null && widget.landing.logoUrl.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse(widget.landing.logoUrl));
        if (r.statusCode == 200) logo = pw.MemoryImage(r.bodyBytes);
      } catch (_) {}
    }
    _branding = b;
    _logo = logo;
  }

  Future<void> _buildPdf(PnBoardRow row, PnBoardStats stats, String yearName) async {
    final repo = ref.read(principalHubRepositoryProvider);
    final data = await repo.getCardPdfData(row.cardId!, yearLabelFallback: yearName);
    final bytes = await pnBuildCardPdf(
      data: data,
      branding: _branding ?? const OfficialBranding(),
      school: widget.landing,
      fallbackLogo: _logo,
      french: _s.isFrench,
      passMark: stats.passMark,
      classAverage: stats.average,
      classHighest: stats.highest,
      classLowest: stats.lowest,
    );
    final url = await repo.uploadGeneratedPdf(schoolId: widget.schoolId, bytes: bytes, prefix: 'report_${data.studentName.replaceAll(' ', '_')}');
    await repo.savePdfUrl(row.cardId!, url);
  }

  /// Builds every missing PDF (a few at a time) and reports progress.
  Future<void> _buildPdfs(List<PnBoardRow> rows, PnBoardStats stats, String yearName) async {
    await _loadBranding();
    var done = 0;
    const batch = 5;
    for (var i = 0; i < rows.length; i += batch) {
      final slice = rows.skip(i).take(batch).toList();
      await Future.wait(slice.map((r) async {
        try {
          await _buildPdf(r, stats, yearName);
        } catch (_) {}
      }));
      done += slice.length;
      if (mounted) setState(() => _progress = done / rows.length);
    }
  }

  String _yearName(List<PnYear> years) {
    for (final y in years) {
      if (y.id == _yearId) return y.name;
    }
    return '';
  }

  Future<void> _generate(List<PnYear> years) async {
    final key = _key;
    if (key == null) return;
    final s = _s;
    setState(() {
      _busy = true;
      _progress = null;
      _status = s.pn('Calculating averages and ranks…', 'Calcul des moyennes et des rangs…');
    });
    try {
      final repo = ref.read(principalHubRepositoryProvider);
      await repo.generateCards(classId: key.classId, scope: key.scope, yearId: key.yearId, termId: key.termId, periodId: key.periodId);
      ref.invalidate(pnBoardProvider(key));
      final board = await ref.read(pnBoardProvider(key).future);
      final withCards = board.rows.where((r) => r.hasCard).toList();
      if (mounted) setState(() => _status = s.pn('Preparing the PDF report cards…', 'Préparation des bulletins PDF…'));
      await _buildPdfs(withCards, board.stats, _yearName(years));
      ref.invalidate(pnBoardProvider(key));
      ref.invalidate(pnOverviewProvider);
      _toast(s.pn('${withCards.length} report cards are up to date and ranked.', '${withCards.length} bulletins sont à jour et classés.'));
    } catch (e) {
      _toast(pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateAllClasses(List<PnClass> classes) async {
    if (_yearId == null) return;
    if (_scope == 'sequence' && _periodId == null) return;
    if (_scope == 'term' && _termId == null) return;
    final s = _s;
    final ok = await pnConfirm(
      context,
      s,
      title: s.pn('Calculate for every class?', 'Calculer pour toutes les classes ?'),
      message: s.pn(
        'Averages and ranks are recalculated for all ${classes.length} classes. PDFs are prepared when you open or publish each card.',
        'Les moyennes et les rangs sont recalculés pour les ${classes.length} classes. Les PDF sont préparés à l\'ouverture ou à la publication de chaque bulletin.',
      ),
      confirmLabel: s.pn('Calculate', 'Calculer'),
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _progress = null;
      _status = s.pn('Calculating every class…', 'Calcul de toutes les classes…');
    });
    try {
      final res = await ref.read(principalHubRepositoryProvider).generateCardsBulk(
            classIds: classes.map((c) => c.id).toList(),
            scope: _scope,
            yearId: _yearId!,
            termId: _scope == 'term' ? _termId : null,
            periodId: _scope == 'sequence' ? _periodId : null,
          );
      ref.invalidate(pnBoardProvider);
      ref.invalidate(pnOverviewProvider);
      _toast(s.pn('${pnI(res['generated'])} report cards calculated.', '${pnI(res['generated'])} bulletins calculés.'));
    } catch (e) {
      _toast(pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(PnBoardRow row, PnBoardStats stats, List<PnYear> years) async {
    final s = _s;
    try {
      var url = row.pdfUrl;
      if (url == null) {
        setState(() {
          _busy = true;
          _progress = null;
          _status = s.pn('Preparing the PDF…', 'Préparation du PDF…');
        });
        await _loadBranding();
        await _buildPdf(row, stats, _yearName(years));
        final key = _key;
        if (key != null) {
          ref.invalidate(pnBoardProvider(key));
          final board = await ref.read(pnBoardProvider(key).future);
          url = board.rows.firstWhere((r) => r.studentId == row.studentId, orElse: () => row).pdfUrl;
        }
      }
      if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _toast(pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(List<PnBoardRow> rows, PnBoardStats stats, List<PnYear> years, {required bool publish}) async {
    final key = _key;
    if (key == null || rows.isEmpty) return;
    final s = _s;
    DateTime? at;

    if (publish) {
      final choice = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(s.pn('Publish ${rows.length} report card(s)?', 'Publier ${rows.length} bulletin(s) ?')),
          content: Text(s.pn('Parents will be able to see and download them.', 'Les parents pourront les consulter et les télécharger.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, 'cancel'), child: Text(s.pn('Cancel', 'Annuler'))),
            OutlinedButton(onPressed: () => Navigator.pop(d, 'later'), child: Text(s.pn('Schedule', 'Programmer'))),
            FilledButton(onPressed: () => Navigator.pop(d, 'now'), child: Text(s.pn('Publish now', 'Publier maintenant'))),
          ],
        ),
      );
      if (choice == null || choice == 'cancel' || !mounted) return;
      if (choice == 'later') {
        final now = DateTime.now();
        at = await pnPickDate(context, now.add(const Duration(days: 1)), first: now, last: now.add(const Duration(days: 120)));
        if (at == null) return;
      }
    } else {
      final ok = await pnConfirm(context, s,
          title: s.pn('Hide ${rows.length} report card(s)?', 'Masquer ${rows.length} bulletin(s) ?'),
          message: s.pn('Parents will no longer see them until you publish again.', 'Les parents ne les verront plus jusqu\'à une nouvelle publication.'),
          confirmLabel: s.pn('Hide', 'Masquer'));
      if (!ok || !mounted) return;
    }

    setState(() {
      _busy = true;
      _progress = null;
      _status = s.pn('Preparing…', 'Préparation…');
    });
    try {
      if (publish) {
        final missing = rows.where((r) => r.pdfUrl == null).toList();
        if (missing.isNotEmpty) {
          setState(() => _status = s.pn('Preparing the PDF report cards…', 'Préparation des bulletins PDF…'));
          await _buildPdfs(missing, stats, _yearName(years));
        }
      }
      await ref.read(principalHubRepositoryProvider).publishCards(rows.map((r) => r.cardId!).toList(), publish, at: at);
      ref.invalidate(pnBoardProvider(key));
      ref.invalidate(pnOverviewProvider);
      _toast(publish
          ? (at == null ? s.pn('Published.', 'Publié.') : s.pn('Scheduled for ${pnIso(at)}.', 'Programmé pour le ${pnIso(at)}.'))
          : s.pn('Hidden from parents.', 'Masqué pour les parents.'));
    } catch (e) {
      _toast(pnErr(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remark(PnBoardRow row) async {
    final s = _s;
    final key = _key;
    if (key == null || row.cardId == null) return;
    final ctrl = TextEditingController();
    final saved = await pnSheet<bool>(context, (sheet) {
      return PnSheetBody(
        title: s.pn('Principal\'s remark', 'Observation du Directeur'),
        subtitle: row.fullName,
        children: [TextField(controller: ctrl, minLines: 3, maxLines: 6, maxLength: 300, decoration: pnDeco(s.pn('Remark shown on the report card', 'Observation affichée sur le bulletin')))],
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(s.pn('Cancel', 'Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(sheet, true), child: Text(s.pn('Save', 'Enregistrer'))),
        ],
      );
    });
    final text = ctrl.text;
    ctrl.dispose();
    if (saved != true || !mounted) return;
    try {
      await ref.read(principalHubRepositoryProvider).setCardComment(row.cardId!, text);
      ref.invalidate(pnBoardProvider(key));
      _toast(s.pn('Remark saved. The PDF will be rebuilt when opened.', 'Observation enregistrée. Le PDF sera reconstruit à l\'ouverture.'));
    } catch (e) {
      _toast(pnErr(s, e));
    }
  }

  List<List<String>> _exportRows(PnBoard board) => [
        for (final r in board.rows)
          [
            r.rank?.toString() ?? '-',
            r.fullName,
            r.admissionNumber ?? '',
            pnAvg(r.average),
            r.average == null ? '-' : (r.average! >= board.stats.passMark ? _s.pn('Pass', 'Admis') : _s.pn('Below pass mark', 'Sous la barre')),
          ],
      ];

  void _export(PnBoard board, String className, String label, {required bool pdf}) {
    final headers = [_s.pn('Rank', 'Rang'), _s.pn('Student', 'Élève'), _s.pn('Admission no.', 'Matricule'), _s.pn('Average', 'Moyenne'), _s.pn('Result', 'Résultat')];
    final rows = _exportRows(board);
    final file = 'ranking_${className.replaceAll(' ', '_')}';
    if (pdf) {
      prExportPdf(ref: ref, landing: widget.landing, fileName: file, title: '${_s.pn('Class ranking', 'Classement')} - $className', subtitle: label, headers: headers, rows: rows);
    } else {
      prExportExcel(fileName: file, sheetName: className.length > 28 ? className.substring(0, 28) : className, headers: headers, rows: rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final calendarAsync = ref.watch(pnCalendarProvider);
    final classesAsync = ref.watch(pnClassesProvider(widget.schoolId));

    return calendarAsync.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnCalendarProvider)),
      data: (years) {
        if (years.isEmpty) {
          return PrEmpty(icon: Icons.event_note_outlined, title: s.pn('Create an academic year first', 'Créez d\'abord une année scolaire'), description: s.pn('Report cards belong to an academic year.', 'Les bulletins appartiennent à une année scolaire.'));
        }
        _yearId ??= years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;
        final year = years.firstWhere((y) => y.id == _yearId, orElse: () => years.first);
        final classes = classesAsync.valueOrNull ?? const <PnClass>[];
        final key = _key;
        final board = key == null ? null : ref.watch(pnBoardProvider(key));

        return Stack(children: [
          PrPage(
            onRefresh: () async {
              if (key != null) ref.invalidate(pnBoardProvider(key));
            },
            children: [
              PrHeader(
                title: s.pn('Rankings & report cards', 'Classements et bulletins'),
                subtitle: s.pn('Generate report cards with class ranks, check them, then publish to parents.', 'Générez les bulletins avec les rangs, vérifiez-les, puis publiez-les aux parents.'),
              ),
              _filters(years, year, classes),
              const SizedBox(height: 16),
              if (key == null)
                SizedBox(
                  height: 260,
                  child: PrEmpty(
                    icon: Icons.emoji_events_outlined,
                    title: s.pn('Choose what to rank', 'Choisissez quoi classer'),
                    description: s.pn('Pick the period and the class above to see the ranking.', 'Choisissez la période et la classe ci-dessus pour voir le classement.'),
                  ),
                )
              else
                board!.when(
                  loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => SizedBox(height: 260, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnBoardProvider(key)))),
                  data: (b) => _boardView(b, years, classes, year),
                ),
            ],
          ),
          if (_busy) _BusyOverlay(status: _status, progress: _progress),
        ]);
      },
    );
  }

  Widget _filters(List<PnYear> years, PnYear year, List<PnClass> classes) {
    final s = _s;
    final terms = year.terms;
    final sequences = year.sequences;

    Widget dd<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
      return DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: pnDeco(label),
        items: items,
        onChanged: _busy ? null : onChanged,
      );
    }

    final scopePills = PrPills<String>(
      values: const ['sequence', 'term', 'year'],
      selected: _scope,
      label: (v) => v == 'sequence' ? s.pn('Sequence', 'Séquence') : (v == 'term' ? s.pn('Term', 'Trimestre') : s.pn('Year', 'Année')),
      onChanged: (v) => setState(() {
        _scope = v;
        _termId = null;
        _periodId = null;
      }),
    );

    final yearDd = dd<String>(
      label: s.pn('Academic year', 'Année scolaire'),
      value: _yearId,
      items: [for (final y in years) DropdownMenuItem(value: y.id, child: Text(y.name))],
      onChanged: (v) => setState(() {
        _yearId = v;
        _termId = null;
        _periodId = null;
      }),
    );

    Widget? periodDd;
    if (_scope == 'sequence') {
      periodDd = dd<String>(
        label: s.pn('Sequence', 'Séquence'),
        value: sequences.any((q) => q.id == _periodId) ? _periodId : null,
        items: [for (final q in sequences) DropdownMenuItem(value: q.id, child: Text(q.name))],
        onChanged: (v) => setState(() => _periodId = v),
      );
    } else if (_scope == 'term') {
      periodDd = dd<String>(
        label: s.pn('Term', 'Trimestre'),
        value: terms.any((t) => t.id == _termId) ? _termId : null,
        items: [for (final t in terms) DropdownMenuItem(value: t.id, child: Text(t.name))],
        onChanged: (v) => setState(() => _termId = v),
      );
    }

    final classDd = dd<String>(
      label: s.pn('Class', 'Classe'),
      value: classes.any((c) => c.id == _classId) ? _classId : null,
      items: [for (final c in classes) DropdownMenuItem(value: c.id, child: Text(c.department.isEmpty ? c.name : '${c.name} · ${c.department}', overflow: TextOverflow.ellipsis))],
      onChanged: (v) => setState(() => _classId = v),
    );

    return PrReveal(
      child: PnPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          scopePills,
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final fields = <Widget>[yearDd, if (periodDd != null) periodDd, classDd];
            if (c.maxWidth < 640) {
              return Column(children: [for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: f)]);
            }
            return Row(children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: fields[i]),
              ],
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _boardView(PnBoard b, List<PnYear> years, List<PnClass> classes, PnYear year) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final st = b.stats;
    final className = classes.where((c) => c.id == _classId).map((c) => c.name).firstWhere((_) => true, orElse: () => '');
    final label = _scope == 'year'
        ? year.name
        : (_scope == 'term'
            ? year.terms.where((t) => t.id == _termId).map((t) => t.name).firstWhere((_) => true, orElse: () => '')
            : year.sequences.where((q) => q.id == _periodId).map((q) => q.name).firstWhere((_) => true, orElse: () => ''));
    final withCards = b.rows.where((r) => r.hasCard).toList();
    final unpublished = withCards.where((r) => !r.isPublished).toList();
    final published = withCards.where((r) => r.isPublished).toList();
    final noMarks = b.rows.where((r) => r.marksCount == 0 && !r.hasCard).length;
    final needCards = b.rows.where((r) => r.marksCount > 0 && !r.hasCard).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PrGrid(minTile: 200, children: [
        PrStatTile(icon: Icons.analytics_outlined, label: s.pn('Class average', 'Moyenne de la classe'), value: st.average ?? 0, format: (v) => st.average == null ? '–' : v.toStringAsFixed(2)),
        PrStatTile(icon: Icons.arrow_upward_rounded, label: s.pn('Highest', 'Plus forte'), value: st.highest ?? 0, format: (v) => st.highest == null ? '–' : v.toStringAsFixed(2)),
        PrStatTile(icon: Icons.arrow_downward_rounded, label: s.pn('Lowest', 'Plus faible'), value: st.lowest ?? 0, format: (v) => st.lowest == null ? '–' : v.toStringAsFixed(2)),
        PrStatTile(
          icon: Icons.verified_outlined,
          label: s.pn('Pass rate (≥ ${st.passMark.toStringAsFixed(1)})', 'Taux de réussite (≥ ${st.passMark.toStringAsFixed(1)})'),
          value: st.passRate,
          format: (v) => '${v.round()}%',
          footer: PrProgressBar(value: st.passRate / 100, height: 6),
        ),
      ]),
      const SizedBox(height: 16),
      if (st.stale > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PnNotice(
            icon: Icons.sync_problem_rounded,
            color: pnWarn(),
            text: s.pn('${st.stale} report card(s) are out of date because marks changed after they were generated. Recalculate to refresh averages and ranks.', '${st.stale} bulletin(s) sont obsolètes car des notes ont changé après leur génération. Recalculez pour actualiser moyennes et rangs.'),
          ),
        ),
      if (needCards > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PnNotice(text: s.pn('$needCards student(s) have approved marks but no report card yet.', '$needCards élève(s) ont des notes approuvées mais pas encore de bulletin.')),
        ),
      if (noMarks > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PnNotice(icon: Icons.hourglass_empty_rounded, text: s.pn('$noMarks student(s) have no approved marks for this period, so they cannot be ranked yet.', '$noMarks élève(s) n\'ont aucune note approuvée pour cette période ; ils ne peuvent pas encore être classés.')),
        ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: _busy || b.rows.isEmpty ? null : () => _generate(years), icon: const Icon(Icons.calculate_outlined, size: 18), label: Text(withCards.isEmpty ? s.pn('Generate & rank', 'Générer et classer') : s.pn('Recalculate & rank', 'Recalculer et classer'))),
        OutlinedButton.icon(onPressed: _busy || unpublished.isEmpty ? null : () => _publish(unpublished, st, years, publish: true), icon: const Icon(Icons.publish_rounded, size: 18), label: Text('${s.pn('Publish', 'Publier')} (${unpublished.length})')),
        if (published.isNotEmpty) OutlinedButton.icon(onPressed: _busy ? null : () => _publish(published, st, years, publish: false), icon: const Icon(Icons.visibility_off_outlined, size: 18), label: Text(s.pn('Hide from parents', 'Masquer aux parents'))),
        PopupMenuButton<String>(
          tooltip: s.pn('More', 'Plus'),
          onSelected: (v) {
            if (v == 'xlsx') _export(b, className, label, pdf: false);
            if (v == 'pdf') _export(b, className, label, pdf: true);
            if (v == 'all') _generateAllClasses(classes);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'xlsx', child: Text(s.pn('Export ranking (Excel)', 'Exporter le classement (Excel)'))),
            PopupMenuItem(value: 'pdf', child: Text(s.pn('Export ranking (PDF)', 'Exporter le classement (PDF)'))),
            PopupMenuItem(value: 'all', child: Text(s.pn('Calculate every class', 'Calculer toutes les classes'))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.more_horiz_rounded, size: 18), const SizedBox(width: 6), Text(s.pn('More', 'Plus'))]),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (b.rows.isEmpty)
        SizedBox(height: 220, child: PrEmpty(icon: Icons.groups_2_outlined, title: s.pn('No students enrolled in this class', 'Aucun élève inscrit dans cette classe')))
      else
        PrCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < b.rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
              _Row(row: b.rows[i], strings: s, passMark: st.passMark, busy: _busy, onOpen: () => _open(b.rows[i], st, years), onRemark: () => _remark(b.rows[i]), onPublish: (pub) => _publish([b.rows[i]], st, years, publish: pub)),
            ],
          ]),
        ),
    ]);
  }
}

class _Row extends StatelessWidget {
  final PnBoardRow row;
  final AppStrings strings;
  final double passMark;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRemark;
  final void Function(bool) onPublish;
  const _Row({required this.row, required this.strings, required this.passMark, required this.busy, required this.onOpen, required this.onRemark, required this.onPublish});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final avg = row.average;

    final chips = <Widget>[
      if (!row.hasCard)
        PnChip(label: row.marksCount > 0 ? s.pn('Not generated', 'Non généré') : s.pn('No marks', 'Sans notes'), color: cs.outline)
      else ...[
        if (avg != null) PnChip(label: avg >= passMark ? s.pn('Pass', 'Admis') : s.pn('Below pass mark', 'Sous la barre'), color: avg >= passMark ? pnGood() : pnWarn()),
        if (row.isPublished) PnChip(label: s.pn('Published', 'Publié'), color: pnGood(), icon: Icons.visibility_rounded) else if (row.isScheduled) PnChip(label: s.pn('Scheduled', 'Programmé'), color: cs.primary, icon: Icons.schedule_rounded) else PnChip(label: s.pn('Draft', 'Brouillon'), color: cs.outline),
        if (row.stale) PnChip(label: s.pn('Out of date', 'Obsolète'), color: pnBad(), icon: Icons.sync_problem_rounded),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        SizedBox(width: 62, child: PnRank(rank: row.rank, total: row.total)),
        const SizedBox(width: 8),
        PnAvatar(stored: row.photo, name: row.fullName, radius: 19),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (row.admissionNumber != null) Text(row.admissionNumber!, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(pnAvg(avg), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text('/ 20', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ]),
        PopupMenuButton<String>(
          enabled: row.hasCard && !busy,
          tooltip: s.pn('Actions', 'Actions'),
          onSelected: (v) {
            if (v == 'open') onOpen();
            if (v == 'remark') onRemark();
            if (v == 'publish') onPublish(true);
            if (v == 'hide') onPublish(false);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'open', child: Text(s.pn('Open PDF', 'Ouvrir le PDF'))),
            PopupMenuItem(value: 'remark', child: Text(s.pn('Principal\'s remark', 'Observation du Directeur'))),
            if (row.isPublished) PopupMenuItem(value: 'hide', child: Text(s.pn('Hide from parent', 'Masquer au parent'))) else PopupMenuItem(value: 'publish', child: Text(s.pn('Publish', 'Publier'))),
          ],
        ),
      ]),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  final String status;
  final double? progress;
  const _BusyOverlay({required this.status, this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: PrCard(
          padding: const EdgeInsets.all(24),
          color: theme.colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (progress == null) const CircularProgressIndicator() else PrProgressBar(value: progress!, height: 10),
              const SizedBox(height: 16),
              Text(status, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

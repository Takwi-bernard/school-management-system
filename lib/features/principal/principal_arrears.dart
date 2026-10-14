import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_export.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// Who owes what: a summary by class, then the debtors of a class.
class PrincipalArrearsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalArrearsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalArrearsPage> createState() => _PrincipalArrearsPageState();
}

class _PrincipalArrearsPageState extends ConsumerState<PrincipalArrearsPage> {
  String? _yearId;
  String? _classId;

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
            PrHeader(title: s.pn('Fee arrears', 'Impayés'), subtitle: s.pn('Who still owes school fees.', 'Qui doit encore des frais de scolarité.')),
            SizedBox(height: 300, child: PrEmpty(icon: Icons.event_busy_rounded, title: s.pn('No academic year yet', 'Aucune année scolaire'), description: s.pn('Create an academic year in the calendar first.', 'Créez d\'abord une année scolaire dans le calendrier.'))),
          ]);
        }
        final current = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
        _yearId ??= current.id;
        if (!years.any((y) => y.id == _yearId)) _yearId = current.id;

        final key = (yearId: _yearId!, classId: _classId);
        final async = ref.watch(pnArrearsProvider(key));
        final rows = ref.watch(_arrearsRowsProvider(key));

        return PrPage(
          onRefresh: () async {
            ref.invalidate(pnArrearsProvider);
            ref.invalidate(_arrearsRowsProvider);
          },
          children: [
            PrHeader(
              title: s.pn('Fee arrears', 'Impayés'),
              subtitle: s.pn('Overdue instalments by class and student. Tap a class to see its debtors.', 'Tranches échues par classe et par élève. Touchez une classe pour voir ses débiteurs.'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _yearId,
              isExpanded: true,
              decoration: pnDeco(s.pn('Academic year', 'Année scolaire')),
              items: [for (final y in years) DropdownMenuItem(value: y.id, child: Text(y.name))],
              onChanged: (v) => setState(() {
                _yearId = v;
                _classId = null;
              }),
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SizedBox(height: 260, child: PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnArrearsProvider(key)))),
              data: (data) => _body(data, rows, key),
            ),
          ],
        );
      },
    );
  }

  Widget _body(PnArrears data, AsyncValue<List<PnArrearsRow>> rowsAsync, PnArrearsKey key) {
    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final totalDue = data.byClass.fold<double>(0, (a, c) => a + c.due);
    final totalPaid = data.byClass.fold<double>(0, (a, c) => a + c.paid);
    final totalOverdue = data.byClass.fold<double>(0, (a, c) => a + c.overdue);
    final totalDebtors = data.byClass.fold<int>(0, (a, c) => a + c.debtors);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PrGrid(minTile: 190, max: 4, children: [
        PrStatTile(icon: Icons.warning_amber_rounded, label: s.pn('Overdue', 'En retard'), value: totalOverdue, format: pMoney),
        PrStatTile(icon: Icons.people_outline_rounded, label: s.pn('Debtors', 'Débiteurs'), value: totalDebtors.toDouble(), format: (v) => '${v.round()}'),
        PrStatTile(icon: Icons.account_balance_wallet_outlined, label: s.pn('Fees due', 'Frais dus'), value: totalDue, format: pMoney),
        PrStatTile(icon: Icons.check_circle_outline_rounded, label: s.pn('Collected', 'Encaissé'), value: totalPaid, format: pMoney, footer: Text(totalDue <= 0 ? '' : '${(totalPaid / totalDue * 100).clamp(0, 100).toStringAsFixed(0)}%', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline))),
      ]),
      const SizedBox(height: 16),
      PnPanel(
        title: s.pn('By class', 'Par classe'),
        trailing: _classId == null ? null : TextButton(onPressed: () => setState(() => _classId = null), child: Text(s.pn('Show all', 'Tout voir'))),
        child: data.byClass.isEmpty
            ? Padding(padding: const EdgeInsets.all(12), child: Text(s.pn('No fees set for this year yet.', 'Aucun frais défini pour cette année.'), style: TextStyle(color: cs.outline)))
            : Column(children: [
                for (final c in data.byClass)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _classId = _classId == c.classId ? null : c.classId),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _classId == c.classId ? cs.primary.withValues(alpha: 0.08) : null,
                      ),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: Text(c.className, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
                          if (c.debtors > 0) PnChip(label: '${c.debtors} ${s.pn('debtors', 'débiteurs')}', color: pnBad()),
                          const SizedBox(width: 10),
                          Text(c.overdue > 0 ? pMoney(c.overdue) : s.pn('Up to date', 'À jour'), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: c.overdue > 0 ? pnBad() : pnGood())),
                        ]),
                        const SizedBox(height: 6),
                        PrProgressBar(value: c.collectedRatio, height: 6, color: c.collectedRatio >= 0.999 ? pnGood() : cs.primary),
                      ]),
                    ),
                  ),
              ]),
      ),
      const SizedBox(height: 16),
      PnPanel(
        title: _classId == null ? s.pn('Debtors', 'Débiteurs') : '${s.pn('Debtors', 'Débiteurs')} · ${data.byClass.where((c) => c.classId == _classId).map((c) => c.className).join()}',
        subtitle: s.pn('Largest overdue amount first.', 'Plus gros retard en premier.'),
        trailing: rowsAsync.valueOrNull == null || rowsAsync.valueOrNull!.isEmpty
            ? null
            : IconButton(
                tooltip: s.pn('Export to Excel', 'Exporter en Excel'),
                icon: const Icon(Icons.table_view_rounded),
                onPressed: () => prExportExcel(
                  fileName: 'fee_arrears',
                  sheetName: s.pn('Arrears', 'Impayés'),
                  headers: [s.pn('Student', 'Élève'), s.pn('Admission no.', 'Matricule'), s.pn('Class', 'Classe'), s.pn('Due', 'Dû'), s.pn('Paid', 'Payé'), s.pn('Overdue', 'En retard')],
                  rows: [for (final r in rowsAsync.valueOrNull!) [r.student, r.admissionNumber ?? '', r.className, r.due.toStringAsFixed(0), r.paid.toStringAsFixed(0), r.overdue.toStringAsFixed(0)]],
                ),
              ),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: rowsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(18), child: Text(pnErr(s, e))),
          data: (rows) {
            if (rows.isEmpty) {
              return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(s.pn('Nobody has overdue fees.', 'Aucun élève n\'a de frais en retard.'), style: TextStyle(color: cs.outline))));
            }
            return Column(children: [
              for (final r in rows) ...[
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(children: [
                    PrAvatar(name: r.student, radius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.student, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          [r.className, if (r.admissionNumber != null) r.admissionNumber!, if (r.lastPaid != null) '${s.pn('last paid', 'dernier versement')} ${pDate(r.lastPaid!)}'].join('  ·  '),
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(pMoney(r.overdue), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: pnBad())),
                      Text('${s.pn('of', 'sur')} ${pMoney(r.due)}', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                    ]),
                  ]),
                ),
              ],
              if (data.total > rows.length)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(
                    onPressed: () => ref.read(_arrearsMoreProvider(key).notifier).state += 1,
                    child: Text(s.pn('Show more (${rows.length} of ${data.total})', 'Afficher plus (${rows.length} sur ${data.total})')),
                  ),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}

/// How many extra pages of debtors were requested for a filter.
final _arrearsMoreProvider = StateProvider.autoDispose.family<int, PnArrearsKey>((ref, key) => 0);

/// Debtors list: loads page 1 plus every extra page requested.
final _arrearsRowsProvider = FutureProvider.autoDispose.family<List<PnArrearsRow>, PnArrearsKey>((ref, key) async {
  final repo = ref.watch(principalHubRepositoryProvider);
  final extra = ref.watch(_arrearsMoreProvider(key));
  ref.watch(pnTickProvider);
  const page = 60;
  final res = await repo.getArrears(yearId: key.yearId, classId: key.classId, limit: page * (extra + 1), offset: 0);
  return res.rows;
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../landing/landing_providers.dart';
import 'proprietor_export.dart';
import 'proprietor_format.dart';
import 'proprietor_models.dart';
import 'proprietor_providers.dart';
import 'proprietor_strings.dart';
import 'proprietor_ui.dart';

/// Every successful payment, newest first, grouped by day, with filters,
/// search, paging and a full-ledger export.
class ProprietorIncomePage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const ProprietorIncomePage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<ProprietorIncomePage> createState() => _ProprietorIncomePageState();
}

class _ProprietorIncomePageState extends ConsumerState<ProprietorIncomePage> {
  final _search = TextEditingController();
  final _debounce = PrDebouncer();

  final List<IncomeRecord> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _exporting = false;
  Object? _error;
  int _generation = 0;

  String? _type;
  String? _method;
  String _query = '';

  AppStrings get _s => widget.strings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final page = await ref.read(proprietorRepositoryProvider).getIncomePage(
            schoolId: widget.schoolId,
            offset: 0,
            type: _type,
            method: _method,
            fallbackPurpose: _s.prPaymentFallback,
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(proprietorRepositoryProvider).getIncomePage(
            schoolId: widget.schoolId,
            offset: _items.length,
            type: _type,
            method: _method,
            fallbackPurpose: _s.prPaymentFallback,
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<IncomeRecord> get _visible {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((r) {
      return r.studentName.toLowerCase().contains(q) ||
          r.purpose.toLowerCase().contains(q) ||
          pMethodLabel(_s, r.method).toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _export(bool pdf) async {
    if (_exporting) return;
    final landing = ref.read(landingProvider).valueOrNull;
    if (landing == null) return;
    setState(() => _exporting = true);
    prSnack(context, _s.prExporting);
    try {
      var all = await ref.read(proprietorRepositoryProvider).getIncomeRange(
            schoolId: widget.schoolId,
            from: DateTime(2000, 1, 1),
            to: DateTime.now(),
            fallbackPurpose: _s.prPaymentFallback,
            type: _type,
            method: _method,
          );
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        all = all.where((r) => r.studentName.toLowerCase().contains(q) || r.purpose.toLowerCase().contains(q)).toList();
      }
      if (all.isEmpty) {
        if (mounted) prSnack(context, _s.prNothingToExport);
        return;
      }
      final headers = [_s.prColDate, _s.prColStudent, _s.prColPurpose, _s.prColMethod, '${_s.prColAmount} (FCFA)'];
      final rows = [
        for (final r in all) [pDateTime(r.date), r.studentName, r.purpose, pMethodLabel(_s, r.method), r.amount.round().toString()],
      ];
      final total = all.fold<double>(0, (a, r) => a + r.amount);
      rows.add(['', '', '', _s.prTotalRow, total.round().toString()]);
      final stamp = DateTime.now();
      final fileBase = 'income-${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}';
      if (pdf) {
        await prExportPdf(
          ref: ref,
          landing: landing,
          fileName: '$fileBase.pdf',
          title: _s.prIncomeTitle,
          subtitle: '${all.length} ${_s.prPayments} · ${pMoney(total)} · ${pDate(stamp)}',
          headers: headers,
          rows: rows,
        );
      } else {
        prExportExcel(fileName: '$fileBase.xlsx', sheetName: _s.prIncomeTitle.length > 30 ? 'Income' : _s.prIncomeTitle, headers: headers, rows: rows);
      }
      if (mounted) prSnack(context, _s.prExportDone);
    } catch (_) {
      if (mounted) prSnack(context, _s.prExportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.toLocal().year, d.toLocal().month, d.toLocal().day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return _s.prToday;
    if (diff == 1) return _s.isFrench ? 'Hier' : 'Yesterday';
    return pDate(d);
  }

  @override
  Widget build(BuildContext context) {
    // Live updates: whenever a payment arrives, reload from the top.
    ref.listen<int>(proprietorTickProvider, (_, __) => _reload());

    final s = _s;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final visible = _visible;
    final total = visible.fold<double>(0, (a, r) => a + r.amount);

    // group by calendar day (list is already newest-first)
    final groups = <String, List<IncomeRecord>>{};
    for (final r in visible) {
      final l = r.date.toLocal();
      groups.putIfAbsent('${l.year}-${l.month}-${l.day}', () => []).add(r);
    }

    return PrPage(
      onRefresh: _reload,
      children: [
        PrHeader(
          title: s.prIncomeTitle,
          subtitle: s.prIncomeDesc,
          trailing: Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: _exporting ? null : () => _export(false), icon: const Icon(Icons.table_chart_outlined, size: 18), label: Text(s.prExportExcel)),
            OutlinedButton.icon(onPressed: _exporting ? null : () => _export(true), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: Text(s.prExportPdf)),
          ]),
        ),
        PrReveal(
          child: PrCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _search,
                onChanged: (v) => _debounce.run(() {
                  if (mounted) setState(() => _query = v.trim());
                }),
                decoration: InputDecoration(
                  hintText: s.prIncomeSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: cs.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant)),
                ),
              ),
              const SizedBox(height: 14),
              PrPills<String?>(
                values: const [null, 'registration', 'installment'],
                selected: _type,
                label: (v) => v == null ? s.prAll : (v == 'registration' ? s.prTypeRegistration : s.prTypeInstallment),
                onChanged: (v) {
                  setState(() => _type = v);
                  _reload();
                },
              ),
              const SizedBox(height: 10),
              PrPills<String?>(
                values: const [null, 'cash', 'mtn_momo', 'orange_money', 'bank_transfer'],
                selected: _method,
                label: (v) => v == null ? s.prAll : pMethodLabel(s, v),
                onChanged: (v) {
                  setState(() => _method = v);
                  _reload();
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          Column(children: List.generate(6, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: PrSkeleton(height: 68, radius: 16))))
        else if (_error != null && _items.isEmpty)
          SizedBox(height: 260, child: PrError(error: _error!, strings: s, onRetry: _reload))
        else if (visible.isEmpty)
          SizedBox(height: 280, child: PrEmpty(icon: Icons.receipt_long_outlined, title: _query.isEmpty ? s.prNoIncomeYet : s.prNoResults))
        else ...[
          PrReveal(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Expanded(child: Text('${s.prShowing} ${visible.length} ${s.prPayments}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline))),
                Text('${s.prFilteredTotal}: ', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                Text(pMoney(total), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
          for (final entry in groups.entries) ...[
            _DayHeader(label: _dayLabel(entry.value.first.date), total: entry.value.fold<double>(0, (a, r) => a + r.amount)),
            for (var i = 0; i < entry.value.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: _IncomeRow(record: entry.value[i], strings: s)),
            const SizedBox(height: 6),
          ],
          if (_hasMore && _query.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _loadingMore
                    ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : OutlinedButton.icon(onPressed: _loadMore, icon: const Icon(Icons.expand_more_rounded), label: Text(s.prLoadMore)),
              ),
            ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final double total;
  const _DayHeader({required this.label, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(children: [
        Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 10),
        Expanded(child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
        const SizedBox(width: 10),
        Text(pMoney(total), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _IncomeRow extends StatelessWidget {
  final IncomeRecord record;
  final AppStrings strings;
  const _IncomeRow({required this.record, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = strings;
    final name = record.studentName.isEmpty ? s.prUnknownStudent : record.studentName;
    return PrCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(record.isRegistration ? Icons.how_to_reg_outlined : Icons.payments_outlined, size: 20, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(record.purpose, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('${pMethodLabel(s, record.method)} · ${pDateTime(record.date)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
          ]),
        ),
        const SizedBox(width: 10),
        Text(pMoney(record.amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
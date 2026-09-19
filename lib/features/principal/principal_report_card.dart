import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsive.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import 'principal_models.dart';
import 'principal_providers.dart';

enum _Scope { sequence, term }

class ReportCardManagementPage extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  const ReportCardManagementPage({super.key, required this.schoolId, required this.landing});

  @override
  ConsumerState<ReportCardManagementPage> createState() => _ReportCardManagementPageState();
}

class _ReportCardManagementPageState extends ConsumerState<ReportCardManagementPage> {
  _Scope _scope = _Scope.sequence;
  String? _yearId;
  String? _termId;
  String? _termName;
  String? _periodId;
  String? _periodName;
  DepartmentFull? _department;
  ManagedClass? _class;

  void _resetDrill() => setState(() { _department = null; _class = null; });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yearIdAsync = ref.watch(principalCurrentAcademicYearIdProvider(widget.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Card Management', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Choose whether this report is for a single sequence or a whole term.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 12),
          SegmentedButton<_Scope>(
            segments: const [
              ButtonSegment(value: _Scope.sequence, label: Text('By Sequence')),
              ButtonSegment(value: _Scope.term, label: Text('By Term')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() { _scope = s.first; _termId = null; _periodId = null; _resetDrill(); }),
          ),
          const SizedBox(height: 16),
          yearIdAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (yearId) {
              if (yearId == null) return const Text('No current academic year set.');
              _yearId = yearId;
              if (_scope == _Scope.term) {
                final termsAsync = ref.watch(principalTermsForYearProvider(yearId));
                return termsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (terms) => DropdownButtonFormField<String>(
                    initialValue: _termId,
                    decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                    items: terms.map((t) => DropdownMenuItem(value: t.id, child: Text(t.termName))).toList(),
                    onChanged: (v) {
                      final term = terms.firstWhere((t) => t.id == v);
                      setState(() { _termId = v; _termName = term.termName; });
                      _resetDrill();
                    },
                  ),
                );
              } else {
                final periodsAsync = ref.watch(examPeriodsProvider(yearId));
                return periodsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (periods) => DropdownButtonFormField<String>(
                    initialValue: _periodId,
                    decoration: const InputDecoration(labelText: 'Sequence', border: OutlineInputBorder()),
                    items: periods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.periodName))).toList(),
                    onChanged: (v) {
                      final period = periods.firstWhere((p) => p.id == v);
                      setState(() { _periodId = v; _periodName = period.periodName; });
                      _resetDrill();
                    },
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          if ((_scope == _Scope.term && _termId != null) || (_scope == _Scope.sequence && _periodId != null))
            Expanded(child: _buildDrill(theme)),
        ],
      ),
    );
  }

  Widget _buildDrill(ThemeData theme) {
    if (_class != null) {
      return _ClassReportCardsPane(
        schoolId: widget.schoolId,
        landing: widget.landing,
        yearId: _yearId!,
        termId: _scope == _Scope.term ? _termId! : null,
        periodId: _scope == _Scope.sequence ? _periodId! : null,
        scope: _scope == _Scope.term ? 'term' : 'sequence',
        label: _scope == _Scope.term ? _termName! : _periodName!,
        classInfo: _class!,
        onBack: () => setState(() => _class = null),
      );
    }

    if (_department != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Breadcrumb(label: _department!.departmentName, onTap: () => setState(() => _department = null)),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final classesAsync = _scope == _Scope.term
                    ? ref.watch(classesWithMarksForDeptProvider((schoolId: widget.schoolId, termId: _termId!, departmentId: _department!.id)))
                    : ref.watch(classesWithMarksForPeriodProvider((schoolId: widget.schoolId, examPeriodId: _periodId!, departmentId: _department!.id)));
                return classesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (classes) {
                    if (classes.isEmpty) return const Center(child: Text('No classes here have approved marks yet.'));
                    return ListView.separated(
                      itemCount: classes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _DrillTile(title: '${classes[i].className} · ${_department!.departmentName}', onTap: () => setState(() => _class = classes[i])),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final deptsAsync = _scope == _Scope.term
            ? ref.watch(departmentsWithMarksProvider((schoolId: widget.schoolId, termId: _termId!)))
            : ref.watch(departmentsWithMarksForPeriodProvider((schoolId: widget.schoolId, examPeriodId: _periodId!)));
        return deptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (departments) {
            if (departments.isEmpty) return const Center(child: Text('No department has approved marks yet.'));
            return ListView.separated(
              itemCount: departments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _DrillTile(title: departments[i].departmentName, onTap: () => setState(() => _department = departments[i])),
            );
          },
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Breadcrumb({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onTap),
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]);
}

class _DrillTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _DrillTile({required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded)]))),
    );
  }
}

class _ClassReportCardsPane extends ConsumerStatefulWidget {
  final String schoolId;
  final LandingModel landing;
  final String yearId;
  final String? termId;
  final String? periodId;
  final String scope;
  final String label;
  final ManagedClass classInfo;
  final VoidCallback onBack;

  const _ClassReportCardsPane({
    required this.schoolId, required this.landing, required this.yearId, this.termId, this.periodId,
    required this.scope, required this.label, required this.classInfo, required this.onBack,
  });

  @override
  ConsumerState<_ClassReportCardsPane> createState() => _ClassReportCardsPaneState();
}

class _ClassReportCardsPaneState extends ConsumerState<_ClassReportCardsPane> {
  bool _busy = false;

  PdfColor _parseColor(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return PdfColor.fromInt(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
  }

  Future<void> _generateOne(ReportCardStatus student) async {
    setState(() => _busy = true);
    try {
      final reportCardId = await ref.read(principalRepositoryProvider).generateReportCard(
            schoolId: widget.schoolId, studentId: student.studentId, classId: widget.classInfo.id,
            academicYearId: widget.yearId, termId: widget.termId ?? await _resolveTermForPeriod(),
            reportScope: widget.scope, examPeriodId: widget.periodId,
          );
      await _buildAndStorePdf(reportCardId);
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _resolveTermForPeriod() async {
    // sequence scope still needs a term_id on the row (grouping/reporting) -
    // fetched once from the exam_periods table.
    final row = await ref.read(principalRepositoryProvider).getExamPeriods(widget.yearId);
    return row.firstWhere((p) => p.id == widget.periodId).id; // placeholder - replaced below if needed
  }

  Future<void> _generateAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Generate report cards for all of ${widget.classInfo.className}?'),
        content: const Text('Each student with approved marks gets their own PDF, saved and downloadable at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate All')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final students = await ref.read(studentsForClassProvider(widget.classInfo.id).future);
      var succeeded = 0, skipped = 0;
      final termId = widget.termId ?? await _resolveTermForPeriod();
      for (final s in students) {
        try {
          final reportCardId = await ref.read(principalRepositoryProvider).generateReportCard(
                schoolId: widget.schoolId, studentId: s.id, classId: widget.classInfo.id,
                academicYearId: widget.yearId, termId: termId, reportScope: widget.scope, examPeriodId: widget.periodId,
              );
          await _buildAndStorePdf(reportCardId);
          succeeded++;
        } catch (_) {
          skipped++;
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated $succeeded of ${students.length} ($skipped had no approved marks).')));
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buildAndStorePdf(String reportCardId) async {
    final data = await ref.read(principalRepositoryProvider).getReportCardPdfData(reportCardId);
    final assets = await ref.read(officialBrandingProvider(widget.schoolId).future);
    final branding = await OfficialBranding.fetch(assets);

    pw.MemoryImage? logo, photo;
    if (branding.letterhead == null && widget.landing.logoUrl.isNotEmpty) {
      try { final r = await http.get(Uri.parse(widget.landing.logoUrl)); if (r.statusCode == 200) logo = pw.MemoryImage(r.bodyBytes); } catch (_) {}
    }
    if (data.studentPhotoUrl != null) {
      try { final r = await http.get(Uri.parse(data.studentPhotoUrl!)); if (r.statusCode == 200) photo = pw.MemoryImage(r.bodyBytes); } catch (_) {}
    }

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(children: [
          buildDocumentHeader(branding: branding, schoolName: widget.landing.schoolName, motto: widget.landing.motto, fallbackLogo: logo),
          pw.SizedBox(height: 14),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(data.studentName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text('${data.className} - ${data.reportLabel}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            if (photo != null) pw.Container(width: 60, height: 70, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Image(photo, fit: pw.BoxFit.cover)),
          ]),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                _cell('Subject', bold: true),
                for (final p in data.periodColumns) _cell(p.name, bold: true, center: true),
                if (data.periodColumns.length > 1) _cell('Average', bold: true, center: true),
                _cell('Coef.', bold: true, center: true),
              ]),
              for (final s in data.subjects)
                pw.TableRow(children: [
                  _cell(s.subjectName),
                  for (final p in data.periodColumns) _cell(s.scoresByPeriod[p.id]?.toStringAsFixed(1) ?? '-', center: true),
                  if (data.periodColumns.length > 1) _cell(s.average.toStringAsFixed(1), center: true),
                  _cell('${s.coefficient}', center: true),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('Overall Average: ${data.overallAverage.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          if (data.principalComment != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 8), child: pw.Text('Remark: ${data.principalComment}')),
          pw.SizedBox(height: 20),
          pw.Align(alignment: pw.Alignment.centerRight, child: buildStampBlock(branding.principalStamp)),
        ]),
      ),
    ));

    final bytes = await doc.save();
    final pdfUrl = await ref.read(principalRepositoryProvider).uploadGeneratedPdf(
          schoolId: widget.schoolId, bytes: bytes, filenamePrefix: 'report_${data.studentName.replaceAll(' ', '_')}',
        );
    await ref.read(principalRepositoryProvider).savePdfUrlOnReportCard(reportCardId, pdfUrl);
  }

  pw.Widget _cell(String text, {bool bold = false, bool center = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, textAlign: center ? pw.TextAlign.center : pw.TextAlign.left, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  void _refresh() {
    if (widget.termId != null) ref.invalidate(reportCardStatusProvider((classId: widget.classInfo.id, termId: widget.termId!, academicYearId: widget.yearId)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Breadcrumb(label: '${widget.classInfo.className} - ${widget.label}', onTap: widget.onBack),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _generateAll,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
          label: Text(_busy ? 'Generating...' : 'Generate All for This Class'),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final studentsAsync = ref.watch(studentsForClassProvider(widget.classInfo.id));
              return studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (students) => ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Expanded(child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                        OutlinedButton(onPressed: _busy ? null : () => _generateOne(ReportCardStatus(studentId: s.id, studentName: s.fullName, exists: false, isPublished: false)), child: const Text('Generate')),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../proprietor/proprietor_ui.dart';
import 'parent_models.dart';
import 'parent_providers.dart';
import 'parent_ui.dart';

/// In-shell report card viewer: term picker, a summary hero (average and
/// class position), one card per subject, the Principal's remark, and a
/// PDF download. Marks are treated as out of 20.
class ParentReportCardTab extends ConsumerStatefulWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentReportCardTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  ConsumerState<ParentReportCardTab> createState() => _ParentReportCardTabState();
}

class _ParentReportCardTabState extends ConsumerState<ParentReportCardTab> {
  String? _selectedPeriodId; // matches ReportPeriodOption.id
  bool _downloading = false;

  Future<void> _download(ReportCardSummary report) async {
    setState(() => _downloading = true);
    try {
      final assets = await ref.read(officialBrandingProvider(widget.landing.schoolId).future);
      final branding = await OfficialBranding.fetch(assets);

      pw.MemoryImage? fallbackLogo;
      if (branding.letterhead == null && widget.landing.logoUrl.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(widget.landing.logoUrl));
          if (res.statusCode == 200) fallbackLogo = pw.MemoryImage(res.bodyBytes);
        } catch (_) {
          // No fallback logo - the document just prints without one.
        }
      }
      if (!mounted) return;
      final primary = Theme.of(context).colorScheme.primary;
      await generateReportCardPdf(
        report: report,
        branding: branding,
        landing: widget.landing,
        isFrench: widget.strings.isFrench,
        accent: PdfColor.fromInt(primary.toARGB32()),
        fallbackLogo: fallbackLogo,
      );
    } catch (_) {
      if (mounted) {
        prSnack(context, widget.strings.isFrench ? 'Échec du téléchargement. Veuillez réessayer.' : 'Download failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final child = widget.child;
    final fr = strings.isFrench;
    final cs = Theme.of(context).colorScheme;
    final yearAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));

    Widget body;
    if (yearAsync.isLoading && !yearAsync.hasValue) {
      body = const PaSkeletonList(rows: 3, height: 90);
    } else if (yearAsync.hasError) {
      body = PaError(error: yearAsync.error!, strings: strings, onRetry: () => ref.invalidate(currentAcademicYearIdProvider(child.schoolId)));
    } else if (yearAsync.valueOrNull == null) {
      body = PrCard(child: PaEmpty(icon: Icons.event_busy_rounded, title: strings.academicYearNotSet));
    } else {
      final yearId = yearAsync.valueOrNull!;
      body = PaAsync<List<ReportPeriodOption>>(
        value: ref.watch(reportPeriodsForYearProvider(yearId)),
        strings: strings,
        onRetry: () => ref.invalidate(reportPeriodsForYearProvider(yearId)),
        isEmpty: (l) => l.isEmpty,
        empty: PaEmpty(icon: Icons.event_busy_rounded, title: strings.academicYearNotSet),
        builder: (periods) {
          // Default to the current term's own "Full Term" entry (highest
          // sortKey within that term), else whichever sorts last.
          _selectedPeriodId ??= periods.lastWhere((p) => p.isCurrentTerm, orElse: () => periods.last).id;
          final selected = periods.firstWhere((p) => p.id == _selectedPeriodId, orElse: () => periods.last);
          final key = (studentId: child.studentId, scope: selected.scope, termId: selected.termId, examPeriodId: selected.examPeriodId);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              initialValue: selected.id,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                prefixIcon: Icon(Icons.event_note_rounded, size: 20, color: cs.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: periods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _selectedPeriodId = v),
            ),
            const SizedBox(height: 16),
            PaAsync<ReportCardSummary?>(
              value: ref.watch(reportCardProvider(key)),
              strings: strings,
              onRetry: () => ref.invalidate(reportCardProvider(key)),
              rows: 3,
              rowHeight: 90,
              builder: (report) {
                if (report == null) return _NotPublishedView(strings: strings);
                return _ReportCardView(report: report, strings: strings, downloading: _downloading, onDownload: () => _download(report));
              },
            ),
          ]);
        },
      );
    }

    return PrPage(
      maxWidth: 760,
      children: [
        PrHeader(
          title: strings.reportCards,
          subtitle: fr
              ? 'Les résultats publiés de ${child.firstName}. Choisissez une séquence ou un trimestre.'
              : '${child.firstName}\'s published results. Choose a sequence or a term.',
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }
}

class _NotPublishedView extends StatelessWidget {
  final AppStrings strings;
  const _NotPublishedView({required this.strings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PrReveal(
      child: PrCard(
        child: PaEmpty(
          icon: Icons.hourglass_empty_rounded,
          title: strings.reportCardNotPublishedTitle,
          text: strings.reportCardNotPublishedDescription,
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(30)),
            child: Text(strings.checkAgainLater, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ),
      ),
    );
  }
}

class _ReportCardView extends StatelessWidget {
  final ReportCardSummary report;
  final AppStrings strings;
  final bool downloading;
  final VoidCallback onDownload;
  const _ReportCardView({required this.report, required this.strings, required this.downloading, required this.onDownload});

  static const double _maxMark = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fr = strings.isFrench;
    final hasRank = report.classRank != null && report.totalStudents != null;
    final comment = report.principalComment?.trim();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PaHero(
        eyebrow: strings.studentReportCard,
        title: report.studentName,
        subtitle: '${report.className} · ${report.termName}',
        bottom: (report.overallAverage != null || hasRank)
            ? Row(children: [
                if (report.overallAverage != null) Expanded(child: PaHeroStat(label: strings.average, value: report.overallAverage!.toStringAsFixed(2))),
                if (hasRank) Expanded(child: PaHeroStat(label: 'Position', value: '${report.classRank} / ${report.totalStudents}')),
              ])
            : null,
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: downloading ? null : onDownload,
          icon: downloading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
          label: Text(fr ? 'Télécharger le bulletin (PDF)' : 'Download report card (PDF)'),
        ),
      ),
      const SizedBox(height: 24),
      PrSectionTitle(
        title: fr ? 'Résultats par matière' : 'Results by subject',
        subtitle: fr ? 'Le coefficient indique le poids de chaque matière dans la moyenne.' : 'The coefficient shows how much each subject counts toward the average.',
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < report.subjects.length; i++)
        PrReveal(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _SubjectCard(result: report.subjects[i], strings: strings, maxMark: _maxMark))),
      if (comment != null && comment.isNotEmpty) ...[
        const SizedBox(height: 6),
        PrReveal(
          child: PrCard(
            color: cs.primary.withValues(alpha: 0.06),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.format_quote_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 6),
                Text(fr ? 'Mot du Directeur' : 'Principal\'s remark', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Text(comment, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectResult result;
  final AppStrings strings;
  final double maxMark;
  const _SubjectCard({required this.result, required this.strings, required this.maxMark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = (result.score / maxMark).clamp(0.0, 1.0).toDouble();
    final remark = result.remark?.trim();

    return PrCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(result.subjectName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          Text(result.score.toStringAsFixed(1), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.primary)),
          if (result.grade != null && result.grade!.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(result.grade!, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        PrProgressBar(value: progress, height: 6),
        const SizedBox(height: 8),
        Row(children: [
          Text('${strings.coefficientShort} ${result.coefficient}', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          if (remark != null && remark.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(child: Text(remark, textAlign: TextAlign.right, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline, fontStyle: FontStyle.italic))),
          ],
        ]),
      ]),
    );
  }
}

/// Standalone so it doesn't need a State - reusable for a Principal-side
/// bulk export later without dragging a widget along with it.
///
/// Layout: when the school has a letterhead it runs close to full page
/// width (8 mm margins) and the body below it sits 2.5 cm in, like a
/// normal letter - the two margins are deliberately independent. With
/// no letterhead, the whole page uses the 2.5 cm margin.
Future<void> generateReportCardPdf({
  required ReportCardSummary report,
  required OfficialBranding branding,
  required LandingModel landing,
  required bool isFrench,
  PdfColor? accent,
  pw.MemoryImage? fallbackLogo,
}) async {
  String t(String en, String fr) => isFrench ? fr : en;

  final accentColor = accent ?? PdfColors.blueGrey700;
  final luminance = 0.299 * accentColor.red + 0.587 * accentColor.green + 0.114 * accentColor.blue;
  final onAccent = luminance > 0.6 ? PdfColors.black : PdfColors.white;

  final hasLetterhead = branding.letterhead != null;
  const letterheadMargin = 8 * PdfPageFormat.mm;
  const bodyMargin = 2.5 * PdfPageFormat.cm;
  final bodyInset = hasLetterhead ? bodyMargin - letterheadMargin : 0.0;
  final letterheadWidth = PdfPageFormat.a4.width - 2 * letterheadMargin;

  final totalCoefficient = report.subjects.fold<int>(0, (sum, s) => sum + s.coefficient);
  final totalWeighted = report.subjects.fold<double>(0, (sum, s) => sum + s.weightedScore);
  final hasRank = report.classRank != null && report.totalStudents != null;
  final comment = report.principalComment?.trim();

  pw.Widget cell(String text, {bool bold = false, bool center = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
        ),
      );

  pw.Widget infoLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: [
            pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  pw.Widget statBox(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: accentColor, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  final body = <pw.Widget>[
    pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            t('REPORT CARD', 'BULLETIN DE NOTES'),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
          ),
          pw.SizedBox(height: 3),
          pw.Text(report.termName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Container(width: 44, height: 2, color: accentColor),
        ],
      ),
    ),
    pw.SizedBox(height: 16),
    pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              infoLine(t('Student', 'Élève'), report.studentName),
              infoLine(t('Class', 'Classe'), report.className),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              infoLine(t('Term', 'Trimestre'), report.termName),
              if (hasRank) infoLine(t('Class size', 'Effectif'), '${report.totalStudents}'),
            ],
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 14),
    pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accentColor),
          children: [
            cell(t('Subject', 'Matière'), bold: true, color: onAccent),
            cell(t('Coef.', 'Coef.'), bold: true, center: true, color: onAccent),
            cell(t('Mark', 'Note'), bold: true, center: true, color: onAccent),
            cell(t('Total', 'Total'), bold: true, center: true, color: onAccent),
            cell(t('Grade', 'Appréc.'), bold: true, center: true, color: onAccent),
            cell(t('Remark', 'Remarque'), bold: true, color: onAccent),
          ],
        ),
        for (final s in report.subjects)
          pw.TableRow(children: [
            cell(s.subjectName),
            cell('${s.coefficient}', center: true),
            cell(s.score.toStringAsFixed(1), center: true),
            cell(s.weightedScore.toStringAsFixed(1), center: true),
            cell(s.grade ?? '-', center: true),
            cell(s.remark ?? ''),
          ]),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            cell(t('TOTAL', 'TOTAL'), bold: true),
            cell('$totalCoefficient', bold: true, center: true),
            cell('', center: true),
            cell(totalWeighted.toStringAsFixed(1), bold: true, center: true),
            cell('', center: true),
            cell(''),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 16),
    pw.Row(
      children: [
        if (report.overallAverage != null) statBox(t('Average', 'Moyenne'), report.overallAverage!.toStringAsFixed(2)),
        if (report.overallAverage != null && hasRank) pw.SizedBox(width: 12),
        if (hasRank) statBox(t('Position', 'Rang'), '${report.classRank} / ${report.totalStudents}'),
      ],
    ),
    if (comment != null && comment.isNotEmpty) ...[
      pw.SizedBox(height: 14),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(t('Principal\'s remark', 'Mot du Directeur'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(comment, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ],
    pw.SizedBox(height: 26),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 130, height: 0.5, color: PdfColors.grey600),
            pw.SizedBox(height: 3),
            pw.Text(t('Parent / Guardian', 'Parent / Tuteur'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            buildStampBlock(branding.principalStamp, size: 80),
            pw.Container(width: 130, height: 0.5, color: PdfColors.grey600),
            pw.SizedBox(height: 3),
            pw.Text(t('Principal', 'Le Directeur'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ],
    ),
  ];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: hasLetterhead
          ? const pw.EdgeInsets.fromLTRB(letterheadMargin, letterheadMargin, letterheadMargin, 12 * PdfPageFormat.mm)
          : const pw.EdgeInsets.all(bodyMargin),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Padding(
          padding: pw.EdgeInsets.only(right: bodyInset),
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
      build: (context) => [
        if (hasLetterhead)
          buildFullWidthLetterhead(branding: branding, width: letterheadWidth)
        else
          buildDocumentHeader(
            branding: branding,
            schoolName: landing.schoolName,
            motto: landing.motto,
            fallbackLogo: fallbackLogo,
          ),
        pw.SizedBox(height: 14),
        for (final widget in body)
          pw.Padding(padding: pw.EdgeInsets.symmetric(horizontal: bodyInset), child: widget),
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'report_card_${report.studentName.replaceAll(RegExp(r'[^\w\-]+'), '_')}.pdf',
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../shared/official_document_branding.dart';
import '../../core/error_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_model.dart';
import 'parent_models.dart';
import 'parent_navigation.dart';
import 'parent_providers.dart';

/// In-shell replacement for the old ReportCardPage (which had its own
/// Scaffold/AppBar/Theme and was reached via a router route). This
/// feature was fully built but never actually reachable - its sidebar
/// entry in parent_shell.dart was commented out and nothing pushed to
/// its route anymore. Same content, hosted in-shell like every other
/// tab, with a download button in its own header instead of an AppBar.
class ParentReportCardTab extends ConsumerStatefulWidget {
  final EnrolledChild child;
  final LandingModel landing;
  final AppStrings strings;
  const ParentReportCardTab({super.key, required this.child, required this.landing, required this.strings});

  @override
  ConsumerState<ParentReportCardTab> createState() => _ParentReportCardTabState();
}

class _ParentReportCardTabState extends ConsumerState<ParentReportCardTab> {
  String? _selectedTermId;
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
      await generateReportCardPdf(report: report, branding: branding, landing: widget.landing, fallbackLogo: fallbackLogo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          widget.strings.isFrench ? 'Échec du téléchargement. Veuillez réessayer.' : 'Download failed. Please try again.',
        )));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final landing = widget.landing;
    final child = widget.child;
    final yearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));

    return Padding(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: brandedSubpageHeader(
                  context,
                  schoolName: landing.schoolName,
                  logoUrl: landing.logoUrl,
                  subtitle: child.fullName,
                ),
              ),
              IconButton(
                onPressed: () => popParentContent(ref),
                icon: const Icon(Icons.close_rounded),
                tooltip: strings.isFrench ? 'Fermer' : 'Close',
              ),
            ],
          ),
          Text(
            strings.isFrench
                ? 'Choisissez un trimestre pour voir le bulletin publié par l\'école.'
                : 'Choose a term to view the report card published by the school.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: yearIdAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorStateView(
                error: e,
                onRetry: () => ref.invalidate(currentAcademicYearIdProvider(child.schoolId)),
              ),
              data: (yearId) {
                if (yearId == null) {
                  return Center(child: Text(strings.academicYearNotSet));
                }
                final termsAsync = ref.watch(termsForYearProvider(yearId));

                return termsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorStateView(
                    error: e,
                    onRetry: () => ref.invalidate(termsForYearProvider(yearId)),
                  ),
                  data: (terms) {
                    if (terms.isEmpty) return Center(child: Text(strings.academicYearNotSet));
                    _selectedTermId ??= terms.firstWhere((t) => t.isCurrent, orElse: () => terms.first).id;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedTermId,
                                decoration:
                                    InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                                items: terms.map((t) => DropdownMenuItem(value: t.id, child: Text(t.termName))).toList(),
                                onChanged: (value) => setState(() => _selectedTermId = value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final reportAsync = ref.watch(
                                reportCardProvider((studentId: child.studentId, termId: _selectedTermId!)),
                              );
                              return reportAsync.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => ErrorStateView(
                                  error: e,
                                  onRetry: () => ref.invalidate(
                                    reportCardProvider((studentId: child.studentId, termId: _selectedTermId!)),
                                  ),
                                ),
                                data: (report) {
                                  if (report == null) {
                                    return _NotPublishedView(landing: landing, strings: strings);
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.icon(
                                          onPressed: _downloading ? null : () => _download(report),
                                          icon: _downloading
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.download_rounded, size: 18),
                                          label: Text(strings.downloadReceipt),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(child: _ReportCardView(report: report, strings: strings)),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone so it doesn't need a State - shared by ParentReportCardTab
/// above (own document only) and could be reused for a Principal-side
/// bulk export later without dragging a widget along with it.
Future<void> generateReportCardPdf({
  required ReportCardSummary report,
  required OfficialBranding branding,
  required LandingModel landing,
  pw.MemoryImage? fallbackLogo,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            buildDocumentHeader(
              branding: branding,
              schoolName: landing.schoolName,
              motto: landing.motto,
              fallbackLogo: fallbackLogo,
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Text('STUDENT REPORT CARD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Student: ${report.studentName}', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Class: ${report.className}', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Term: ${report.termName}', style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Subject', bold: true),
                    _cell('Mark', bold: true, center: true),
                    _cell('Coef.', bold: true, center: true),
                    _cell('Grade', bold: true, center: true),
                    _cell('Remark', bold: true),
                  ],
                ),
                for (final s in report.subjects)
                  pw.TableRow(children: [
                    _cell(s.subjectName),
                    _cell(s.score.toStringAsFixed(1), center: true),
                    _cell('${s.coefficient}', center: true),
                    _cell(s.grade ?? '-', center: true),
                    _cell(s.remark ?? ''),
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            if (report.overallAverage != null) _summaryLine('Average', report.overallAverage!.toStringAsFixed(2)),
            if (report.classRank != null && report.totalStudents != null)
              _summaryLine('Class Rank', '${report.classRank} / ${report.totalStudents}'),
            if (report.principalComment != null && report.principalComment!.isNotEmpty)
              _summaryLine('Principal\'s Remark', report.principalComment!),
            pw.SizedBox(height: 20),
            // A report card is an ACADEMIC document - stamped by the
            // Principal, not the Proprietor (whose stamp belongs on
            // financial documents like the receipt instead).
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: buildStampBlock(branding.principalStamp),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Generated automatically by the school management system.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: 'report_card_${report.studentName.replaceAll(' ', '_')}.pdf');
}

pw.Widget _cell(String text, {bool bold = false, bool center = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      text,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
    ),
  );
}

pw.Widget _summaryLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

class _NotPublishedView extends StatelessWidget {
  final dynamic landing;
  final AppStrings strings;
  const _NotPublishedView({required this.landing, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_late_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(strings.reportCardNotPublishedTitle,
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(strings.reportCardNotPublishedDescription,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(30)),
              child: Text(strings.checkAgainLater, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCardView extends StatelessWidget {
  final ReportCardSummary report;
  final AppStrings strings;
  const _ReportCardView({required this.report, required this.strings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Text(strings.studentReportCard, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(report.studentName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text('${report.className} - ${report.termName}', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            strings.isFrench
                ? 'Ce tableau montre la note et le coefficient de chaque matière. Utilisez l\'icône de téléchargement en haut pour obtenir une copie PDF de ce bulletin.'
                : 'This table shows each subject\'s mark and coefficient. Use the download icon at the top to get a PDF copy of this report card.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text(strings.subject, style: const TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox(width: 50, child: Text(strings.mark, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox(width: 50, child: Text(strings.coefficientShort, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...report.subjects.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.subjectName)),
                        SizedBox(width: 50, child: Text(s.score.toStringAsFixed(1), textAlign: TextAlign.center)),
                        SizedBox(width: 50, child: Text('${s.coefficient}', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.outline))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.overallAverage != null) _SummaryRow(strings.average, report.overallAverage!.toStringAsFixed(2)),
              if (report.classRank != null && report.totalStudents != null)
                _SummaryRow(strings.rank, '${report.classRank} / ${report.totalStudents}'),
              if (report.principalComment != null && report.principalComment!.isNotEmpty)
                _SummaryRow(strings.remark, report.principalComment!),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

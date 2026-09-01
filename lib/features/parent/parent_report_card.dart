import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import '../landing/landing_providers.dart';
import 'parent_models.dart';
import 'parent_providers.dart';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
/// Report Card + Review My Child - kept in one file since both are
/// read-only academic views of the same child, following the
/// consolidation convention used across this project.

class ReportCardPage extends ConsumerStatefulWidget {
  final EnrolledChild child;
  const ReportCardPage({super.key, required this.child});

  @override
  ConsumerState<ReportCardPage> createState() => _ReportCardPageState();
}

class _ReportCardPageState extends ConsumerState<ReportCardPage> {
  String? _selectedTermId;
  Future<void> _downloadReportCard(BuildContext context, ReportCardSummary report, dynamic landing) async {
    final doc = pw.Document();

    pw.MemoryImage? logo;
    if (landing.logoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(landing.logoUrl));
        if (res.statusCode == 200) logo = pw.MemoryImage(res.bodyBytes);
      } catch (_) {
        // Missing/unreachable logo should never block the report card itself.
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) pw.Image(logo, width: 64, height: 64),
              pw.SizedBox(height: 10),
              pw.Text(landing.schoolName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              if (landing.motto.isNotEmpty)
                pw.Text(landing.motto, style:  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 18),
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

              // Subjects table
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
              if (report.overallAverage != null)
                _summaryLine('Average', report.overallAverage!.toStringAsFixed(2)),
              if (report.classRank != null && report.totalStudents != null)
                _summaryLine('Class Rank', '${report.classRank} / ${report.totalStudents}'),
              if (report.principalComment != null && report.principalComment!.isNotEmpty)
                _summaryLine('Principal\'s Remark', report.principalComment!),

              pw.SizedBox(height: 24),
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
  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(landingProvider).value;
    if (landing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final yearIdAsync = ref.watch(currentAcademicYearIdProvider(widget.child.schoolId));

    return Theme(
      data: buildSchoolTheme(landing.primaryColor, landing.secondaryColor),
      child: Scaffold(
                appBar: AppBar(
          title: Text(strings.reportCards),
          actions: [
            if (_selectedTermId != null)
              Consumer(
                builder: (context, ref, _) {
                  final reportAsync = ref.watch(
                    reportCardProvider((studentId: widget.child.studentId, termId: _selectedTermId!)),
                  );
                  final report = reportAsync.valueOrNull;
                  if (report == null) return const SizedBox();
                  return IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: strings.downloadReceipt,
                    onPressed: () => _downloadReportCard(context, report, landing),
                  );
                },
              ),
          ],
        ),
        body: yearIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (yearId) {
            if (yearId == null) return Center(child: Text(strings.academicYearNotSet));
            final termsAsync = ref.watch(termsForYearProvider(yearId));

            return termsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (terms) {
                if (terms.isEmpty) return Center(child: Text(strings.academicYearNotSet));
                _selectedTermId ??= terms.firstWhere((t) => t.isCurrent, orElse: () => terms.first).id;

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(Responsive.pagePadding(context)),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTermId,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: terms.map((t) => DropdownMenuItem(value: t.id, child: Text(t.termName))).toList(),
                        onChanged: (value) => setState(() => _selectedTermId = value),
                      ),
                    ),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final reportAsync = ref.watch(
                            reportCardProvider((studentId: widget.child.studentId, termId: _selectedTermId!)),
                          );
                          return reportAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('$e')),
                            data: (report) {
                              if (report == null) {
                                return _NotPublishedView(landing: landing, strings: strings);
                              }
                              return _ReportCardView(report: report, strings: strings);
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
    );
  }
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
            if (landing.logoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(landing.logoUrl, width: 64, height: 64, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: 64, color: theme.colorScheme.primary)),
              )
            else
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
      padding: const EdgeInsets.all(20),
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
        const SizedBox(height: 16),
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

// ============================================================
// REVIEW MY CHILD
// ============================================================

class ReviewChildPage extends ConsumerWidget {
  final EnrolledChild child;
  const ReviewChildPage({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(landingProvider).value;
    if (landing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final strings = AppStrings(ref.watch(activeLocaleProvider));
    final yearIdAsync = ref.watch(currentAcademicYearIdProvider(child.schoolId));
    final commentsAsync = ref.watch(approvedCommentsProvider(child.studentId));

    return Theme(
      data: buildSchoolTheme(landing.primaryColor, landing.secondaryColor),
      child: Scaffold(
        appBar: AppBar(title: Text(strings.reviewMyChild)),
        body: yearIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (yearId) {
            if (yearId == null) return Center(child: Text(strings.academicYearNotSet));
            final attendanceAsync =
                ref.watch(attendanceSummaryProvider((studentId: child.studentId, academicYearId: yearId)));

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(strings.attendanceSummary, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                attendanceAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (summary) => Row(
                    children: [
                      _AttendanceStat(label: strings.present, value: summary.present, color: Colors.green),
                      _AttendanceStat(label: strings.absent, value: summary.absent, color: Colors.red),
                      _AttendanceStat(label: strings.late, value: summary.late, color: Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(strings.schoolComments, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                commentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Text(strings.noCommentYet,
                          style: TextStyle(color: Theme.of(context).colorScheme.outline));
                    }
                    return Column(
                      children: comments
                          .map((c) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(c.teacherName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text(c.examPeriodName, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(c.comment),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _AttendanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import 'principal_hub_models.dart';

/// Builds the printable report card for any scope (sequence, term or
/// year), in the school's language, with rank and class statistics.
Future<Uint8List> pnBuildCardPdf({
  required PnCardPdfData data,
  required OfficialBranding branding,
  required LandingModel school,
  required pw.MemoryImage? fallbackLogo,
  required bool french,
  Uint8List? photoBytes,
  required double passMark,
  double? classAverage,
  double? classHighest,
  double? classLowest,
}) async {
  String t(String en, String fr) => french ? fr : en;

  pw.MemoryImage? photo;
  if (photoBytes != null && photoBytes.isNotEmpty) {
    photo = pw.MemoryImage(photoBytes);
  } else if (data.studentPhotoUrl != null && data.studentPhotoUrl!.startsWith('http')) {
    try {
      final r = await http.get(Uri.parse(data.studentPhotoUrl!));
      if (r.statusCode == 200) photo = pw.MemoryImage(r.bodyBytes);
    } catch (_) {}
  }

  pw.Widget cell(String text, {bool bold = false, bool center = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
        ),
      );

  String fmt(double? v) => v == null ? '-' : v.toStringAsFixed(1);

  final multi = data.columns.length > 1;
  final scopeLabel = data.scope == 'year'
      ? t('Annual report', 'Bulletin annuel')
      : data.scope == 'term'
          ? t('Term report', 'Bulletin trimestriel')
          : t('Sequence report', 'Bulletin de séquence');

  final passed = data.overallAverage >= passMark;
  final headerRow = pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
    children: [
      cell(t('Subject', 'Matière'), bold: true),
      for (final c in data.columns) cell(c, bold: true, center: true),
      if (multi) cell(t('Average', 'Moyenne'), bold: true, center: true),
      cell(t('Coef.', 'Coef.'), bold: true, center: true),
      cell(t('Total', 'Total'), bold: true, center: true),
    ],
  );

  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (context) => [
      buildDocumentHeader(branding: branding, schoolName: school.schoolName, motto: school.motto, fallbackLogo: fallbackLogo),
      pw.SizedBox(height: 12),
      pw.Center(child: pw.Text('$scopeLabel - ${data.reportLabel}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 12),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(data.studentName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text('${t('Class', 'Classe')}: ${data.className}', style: const pw.TextStyle(fontSize: 10)),
          if (data.admissionNumber != null) pw.Text('${t('Admission no.', 'Matricule')}: ${data.admissionNumber}', style: const pw.TextStyle(fontSize: 10)),
        ]),
        if (photo != null) pw.Container(width: 58, height: 68, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Image(photo, fit: pw.BoxFit.cover)),
      ]),
      pw.SizedBox(height: 14),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
        children: [
          headerRow,
          for (final s in data.subjects)
            pw.TableRow(children: [
              cell(s.name),
              for (final v in s.scores) cell(fmt(v), center: true),
              if (multi) cell(s.average.toStringAsFixed(1), center: true),
              cell('${s.coefficient}', center: true),
              cell((s.average * s.coefficient).toStringAsFixed(1), center: true),
            ]),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6, color: PdfColors.grey500), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _stat(t('Overall average', 'Moyenne générale'), '${data.overallAverage.toStringAsFixed(2)} / 20'),
          _stat(t('Rank', 'Rang'), data.rank == null ? '-' : '${data.rank}${data.total == null ? '' : ' / ${data.total}'}'),
          if (classAverage != null) _stat(t('Class average', 'Moyenne de la classe'), classAverage.toStringAsFixed(2)),
          if (classHighest != null) _stat(t('Highest', 'Plus forte'), classHighest.toStringAsFixed(2)),
          if (classLowest != null) _stat(t('Lowest', 'Plus faible'), classLowest.toStringAsFixed(2)),
        ]),
      ),
      if (data.scope == 'year') ...[
        pw.SizedBox(height: 8),
        pw.Text(
          passed
              ? t('Result: average above the pass mark of ${passMark.toStringAsFixed(1)} - eligible for promotion.', 'Résultat : moyenne supérieure à la barre de ${passMark.toStringAsFixed(1)} - admis en classe supérieure.')
              : t('Result: average below the pass mark of ${passMark.toStringAsFixed(1)} - to be reviewed by the council.', 'Résultat : moyenne inférieure à la barre de ${passMark.toStringAsFixed(1)} - à examiner par le conseil.'),
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
      ],
      if (data.principalComment != null && data.principalComment!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text('${t('Principal\'s remark', 'Observation du Directeur')}: ${data.principalComment}', style: const pw.TextStyle(fontSize: 10)),
      ],
      pw.SizedBox(height: 22),
      pw.Align(alignment: pw.Alignment.centerRight, child: buildStampBlock(branding.principalStamp)),
    ],
  ));
  return doc.save();
}

pw.Widget _stat(String label, String value) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    ]);

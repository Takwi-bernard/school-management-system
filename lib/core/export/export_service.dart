import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Shared export utility - not Teacher-specific, so any future module
/// (Parent, Principal, etc.) needing a class-list-style export can
/// reuse this instead of duplicating export logic per feature.
///
/// NOTE: uses dart:html directly since this project is Flutter Web
/// only for V1 (per the architecture decision - native mobile is a
/// later, separate build if a school ever requests it). If mobile
/// support is added later, this file will need a conditional
/// (web vs io) implementation split.
class ExportService {
  /// Generates an .xlsx file from tabular data and triggers a browser
  /// download.
  static void exportExcel({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
    String sheetName = 'Sheet1',
  }) {
    final workbook = Excel.createExcel();
    final sheet = workbook[sheetName];
    // Excel.createExcel() ships with a default 'Sheet1' - rename/reuse
    // rather than leaving a stray empty default sheet behind.
    if (workbook.sheets.keys.first != sheetName) {
      workbook.rename(workbook.sheets.keys.first, sheetName);
    }

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
    }

    final bytes = workbook.encode();
    if (bytes == null) return;
    _downloadBytes(Uint8List.fromList(bytes), fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  /// Generates a simple table PDF (title + header + rows) and triggers
  /// the browser's save dialog via the printing package.
  static Future<void> exportPdf({
    required String fileName,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
  }

  static void _downloadBytes(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
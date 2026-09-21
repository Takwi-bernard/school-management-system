import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/official_document_branding.dart';

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
  ///
  /// [accentColor] should be THIS school's own brand color (e.g.
  /// derived from landing.primaryColor), not a fixed value - every
  /// caller should pass it. It's optional only so the service still
  /// compiles/works for a caller that genuinely has no school context;
  /// the fallback is a neutral gray, not a "default brand."
  ///
  /// [branding]: when it carries a letterhead, the page switches to small
  /// margins (8 mm) and the letterhead is drawn edge to edge across the
  /// top of the first page, with the title and table starting right
  /// beneath it. Without a letterhead the layout is exactly as before.
  static Future<void> exportPdf({
    required String fileName,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    PdfColor? accentColor,
    OfficialBranding? branding,
  }) async {
    final doc = pw.Document();
    final accent = accentColor ?? PdfColors.blueGrey700;
    // Computed from the accent itself, not assumed: a school with a
    // light/pastel brand color needs dark header text, not white-on-
    // white. Same reasoning as Material's onPrimary on the Flutter side.
    final luminance = 0.299 * accent.red + 0.587 * accent.green + 0.114 * accent.blue;
    final onAccent = luminance > 0.6 ? PdfColors.black : PdfColors.white;

    final hasLetterhead = branding != null && branding.letterhead != null;
    // A few millimetres from every page edge, so even a small letterhead
    // image is drawn as large as the page allows.
    const sideMargin = 8 * PdfPageFormat.mm;
    const topMargin = 8 * PdfPageFormat.mm;
    const bottomMargin = 12 * PdfPageFormat.mm;
    final contentWidth = PdfPageFormat.a4.width - 2 * sideMargin;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: hasLetterhead
            ? const pw.EdgeInsets.fromLTRB(sideMargin, topMargin, sideMargin, bottomMargin)
            : null,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          if (hasLetterhead) ...[
            buildFullWidthLetterhead(branding: branding!, width: contentWidth),
            pw.SizedBox(height: 8),
          ],
          pw.Text(title, style: pw.TextStyle(fontSize: hasLetterhead ? 15 : 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle, style: pw.TextStyle(fontSize: hasLetterhead ? 10 : 12, color: PdfColors.grey700)),
          pw.SizedBox(height: hasLetterhead ? 10 : 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: onAccent),
            headerDecoration: pw.BoxDecoration(color: accent),
            cellPadding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: hasLetterhead ? 4 : 6),
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
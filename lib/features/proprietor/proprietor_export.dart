import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../core/export/export_service.dart';
import '../../core/school_color.dart';
import '../../shared/official_document_branding.dart';
import '../landing/landing_model.dart';
import '../parent/parent_providers.dart' show officialBrandingProvider;

/// One place for every Proprietor download, so all statements share the
/// school's letterhead, brand colour and stamp handling.

PdfColor _pdfColor(LandingModel landing) {
  final c = parseSchoolColor(landing.primaryColor, debugLabel: 'proprietor export');
  return PdfColor(c.r, c.g, c.b);
}

Future<void> prExportPdf({
  required WidgetRef ref,
  required LandingModel landing,
  required String fileName,
  required String title,
  required String subtitle,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  OfficialBranding? branding;
  try {
    final assets = await ref.read(officialBrandingProvider(landing.schoolId).future);
    branding = await OfficialBranding.fetch(assets);
  } catch (_) {
    branding = null; // a missing letterhead must never block a statement
  }
  await ExportService.exportPdf(
    fileName: fileName,
    title: title,
    subtitle: subtitle,
    headers: headers,
    rows: rows,
    accentColor: _pdfColor(landing),
    branding: branding,
  );
}

void prExportExcel({
  required String fileName,
  required String sheetName,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  ExportService.exportExcel(fileName: fileName, headers: headers, rows: rows, sheetName: sheetName);
}
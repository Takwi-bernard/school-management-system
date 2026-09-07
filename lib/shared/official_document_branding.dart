import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One shared shape every official PDF in this system uses - built
/// ONCE here so receipts, report cards, and any future document
/// never re-implement header/stamp logic on their own.
class OfficialBranding {
  final pw.MemoryImage? letterhead;
  final pw.MemoryImage? principalStamp;
  final pw.MemoryImage? proprietorStamp;
  final pw.MemoryImage? disciplineMasterStamp;

  const OfficialBranding({
    this.letterhead,
    this.principalStamp,
    this.proprietorStamp,
    this.disciplineMasterStamp,
  });

  /// [assets] is the school_assets map already fetched via
  /// officialBrandingProvider - keyed by asset_type. Any missing key
  /// simply produces a null image; a document is never blocked from
  /// generating just because one stamp hasn't been uploaded yet.
  static Future<OfficialBranding> fetch(Map<String, String> assets) async {
    return OfficialBranding(
      letterhead: await _tryFetch(assets['letterhead']),
      principalStamp: await _tryFetch(assets['principal_stamp']),
      proprietorStamp: await _tryFetch(assets['proprietor_stamp']),
      disciplineMasterStamp: await _tryFetch(assets['discipline_master_stamp']),
    );
  }

  static Future<pw.MemoryImage?> _tryFetch(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
    } catch (_) {
      // Missing/unreachable image never blocks document generation.
    }
    return null;
  }
}

/// The header every official document starts with - full-width
/// letterhead image if one is configured, otherwise falls back to
/// the plain name/logo/motto layout already used before this system
/// existed, so nothing breaks for a school that hasn't uploaded one yet.
pw.Widget buildDocumentHeader({
  required OfficialBranding branding,
  required String schoolName,
  required String motto,
  pw.MemoryImage? fallbackLogo,
}) {
  if (branding.letterhead != null) {
    return pw.Image(branding.letterhead!, fit: pw.BoxFit.fitWidth);
  }
  return pw.Column(
    children: [
      if (fallbackLogo != null) pw.Image(fallbackLogo, width: 56, height: 56),
      pw.SizedBox(height: 8),
      pw.Text(schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      if (motto.isNotEmpty) pw.Text(motto, style:  pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
    ],
  );
}

/// The stamp block a document ends with. Pass null and it simply
/// renders nothing - never leaves a broken-image gap.
pw.Widget buildStampBlock(pw.MemoryImage? stamp, {double size = 90}) {
  if (stamp == null) return pw.SizedBox();
  return pw.Container(
    width: size,
    height: size,
    child: pw.Opacity(opacity: 0.85, child: pw.Image(stamp)),
  );
}
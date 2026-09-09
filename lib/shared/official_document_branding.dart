import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
  ///
  /// Stamps go through _fetchStamp (background removed) - the
  /// letterhead does NOT, since it's a full rectangular header
  /// image, not a seal meant to sit transparently over content.
  static Future<OfficialBranding> fetch(Map<String, String> assets) async {
    return OfficialBranding(
      letterhead: await _fetchImage(assets['letterhead']),
      principalStamp: await _fetchStamp(assets['principal_stamp']),
      proprietorStamp: await _fetchStamp(assets['proprietor_stamp']),
      disciplineMasterStamp: await _fetchStamp(assets['discipline_master_stamp']),
    );
  }

  static Future<Uint8List?> _fetchBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {
      // Missing/unreachable image never blocks document generation.
    }
    return null;
  }

  static Future<pw.MemoryImage?> _fetchImage(String? url) async {
    final bytes = await _fetchBytes(url);
    return bytes == null ? null : pw.MemoryImage(bytes);
  }

  /// A photographed/scanned stamp almost always sits on a white (or
  /// near-white) square background - which then prints as an ugly
  /// white box on the page instead of a clean seal. This strips any
  /// near-white pixel to fully transparent before embedding, so only
  /// the actual ink marks show. Falls back to the untouched image if
  /// decoding fails for any reason - a slightly-wrong-looking stamp
  /// is far better than a document that fails to generate.
  static Future<pw.MemoryImage?> _fetchStamp(String? url) async {
    final bytes = await _fetchBytes(url);
    if (bytes == null) return null;
    try {
      return pw.MemoryImage(await _stripNearWhiteBackground(bytes));
    } catch (_) {
      return pw.MemoryImage(bytes);
    }
  }

  static Future<Uint8List> _stripNearWhiteBackground(Uint8List bytes, {int threshold = 235}) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final rgba = decoded.numChannels == 4 ? decoded : decoded.convert(numChannels: 4);
    for (final pixel in rgba) {
      if (pixel.r >= threshold && pixel.g >= threshold && pixel.b >= threshold) {
        pixel.setRgba(pixel.r, pixel.g, pixel.b, 0);
      }
    }
    return Uint8List.fromList(img.encodePng(rgba));
  }
}

/// The header every official document starts with - full-width
/// letterhead image if one is configured, otherwise falls back to
/// the plain name/logo/motto layout already used before this system
/// existed, so nothing breaks for a school that hasn't uploaded one yet.
///
/// FIX: previously this Container had no explicit width, so inside a
/// centered Column it shrank to the image's own intrinsic size at
/// height:90 and then sat centered - reading as a small, oddly-
/// margined header instead of a proper full-width letterhead band.
/// width: double.infinity makes it span the full page width; no
/// border/decoration is applied, so there's nothing framing its top
/// corners or bottom edge.
pw.Widget buildDocumentHeader({
  required OfficialBranding branding,
  required String schoolName,
  required String motto,
  pw.MemoryImage? fallbackLogo,
}) {
  if (branding.letterhead != null) {
    return pw.Container(
      width: double.infinity,
      height: 100,
      alignment: pw.Alignment.center,
      child: pw.Image(branding.letterhead!, fit: pw.BoxFit.contain),
    );
  }
  return pw.Column(
    children: [
      if (fallbackLogo != null) pw.Image(fallbackLogo, width: 56, height: 56),
      pw.SizedBox(height: 8),
      pw.Text(schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      if (motto.isNotEmpty) pw.Text(motto, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
    ],
  );
}

pw.Widget buildStampBlock(pw.MemoryImage? stamp, {double size = 90}) {
  if (stamp == null) return pw.SizedBox();
  // No forced opacity - that only looks right on a transparent PNG.
  // Background is now actually stripped (see _fetchStamp above)
  // rather than just hoped-for, so full strength is correct here.
  return pw.Container(
    width: size,
    height: size,
    child: pw.Image(stamp, fit: pw.BoxFit.contain),
  );
}
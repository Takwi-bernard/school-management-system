import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// One place that knows how to open a child's photo, whoever uploaded it.
///
/// The `student-photos` bucket is private. A stored value can be either a
/// bare storage path ("schoolId/uploaderId/123.jpg") or an old public-style
/// link that contains "/student-photos/". Both are handled here.
class StudentPhoto {
  StudentPhoto._();

  static const bucket = 'student-photos';

  /// The bare storage path inside the bucket, or null if [stored] points
  /// somewhere else (a link on another site, for example).
  static String? pathOf(String stored) {
    if (!stored.startsWith('http')) return stored;
    const marker = '/$bucket/';
    final index = stored.indexOf(marker);
    if (index == -1) return null;
    return Uri.decodeComponent(stored.substring(index + marker.length).split('?').first);
  }

  /// A link a NetworkImage can open, or null when there is no photo.
  /// Tries a signed link first; if the database refuses to sign it, falls
  /// back to the stored link itself instead of showing nothing.
  static Future<String?> displayUrl(SupabaseClient client, String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    final path = pathOf(stored);
    if (path == null) return stored.startsWith('http') ? stored : null;
    try {
      return await client.storage.from(bucket).createSignedUrl(path, 6 * 60 * 60);
    } catch (_) {
      return stored.startsWith('http') ? stored : client.storage.from(bucket).getPublicUrl(path);
    }
  }

  /// The photo's bytes for putting into a PDF. Tries, in order: a direct
  /// authenticated download, a signed link, then the stored link as is.
  static Future<Uint8List?> bytes(SupabaseClient client, String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    final path = pathOf(stored);
    if (path != null) {
      try {
        final data = await client.storage.from(bucket).download(path);
        if (data.isNotEmpty) return data;
      } catch (_) {}
      try {
        final signed = await client.storage.from(bucket).createSignedUrl(path, 600);
        final res = await http.get(Uri.parse(signed));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res.bodyBytes;
      } catch (_) {}
    }
    if (stored.startsWith('http')) {
      try {
        final res = await http.get(Uri.parse(stored));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res.bodyBytes;
      } catch (_) {}
    }
    return null;
  }
}

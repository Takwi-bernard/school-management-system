import 'package:supabase_flutter/supabase_flutter.dart';
import 'landing_model.dart';

/// Resolves the current school from the request domain (Uri.base.host
/// on Flutter Web). Mobile builds will need a different resolution
/// strategy later (pre-configured school at build time, or a manual
/// domain entry screen) - not needed for the web-first V1 launch.
class TenantResolver {
  final SupabaseClient client;
  const TenantResolver(this.client);

  Future<Map<String, dynamic>> resolve() async {
    var host = Uri.base.host;

    // Dev convenience: localhost has no schools.domain row. Point this
    // at a real seeded school's domain while developing locally.
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      host = const String.fromEnvironment(
        'DEV_SCHOOL_DOMAIN',
        defaultValue: '',
      );
    }

    if (host.isEmpty) {
      throw Exception('Unable to determine school domain.');
    }

    final school = await client
        .from('schools')
        .select()
        .eq('domain', host)
        .eq('status', 'active')
        .maybeSingle();

    if (school == null) {
      throw Exception('No school is configured for domain: $host');
    }
    return school;
  }
}

class LandingRepository {
  final SupabaseClient client;
  final TenantResolver tenantResolver;
  const LandingRepository(this.client, this.tenantResolver);

  Future<LandingModel> load({required String language}) async {
    final school = await tenantResolver.resolve();
    final schoolId = school['id'] as String;

    // PERFORMANCE FIX: these were previously awaited one after another
    // (7 sequential round trips). On a slow/high-latency connection -
    // exactly the Cameroon mobile-network case - that multiplies total
    // load time by roughly 7x. Running them concurrently means total
    // load time is close to the SLOWEST single request, not the sum
    // of all of them.
    final results = await Future.wait([
      _loadBrandingAssets(schoolId),
      _loadContent(schoolId: schoolId, language: language),
      _loadStatistics(schoolId: schoolId, language: language),
      _loadAchievements(schoolId: schoolId, language: language),
      _loadGallery(schoolId),
      _loadAnnouncements(schoolId),
      _loadEvents(schoolId),
      _loadCurrentAcademicYear(schoolId),
    ]);

    final branding = results[0] as Map<String, String>;
    final content = results[1] as Map<String, String>;
    final statistics = results[2] as List<LandingStatistic>;
    final achievements = results[3] as List<LandingAchievement>;
    final gallery = results[4] as List<LandingGalleryItem>;
    final announcements = results[5] as List<LandingAnnouncement>;
    final events = results[6] as List<LandingEvent>;
    final currentAcademicYear = results[7] as String?;

    return LandingModel(
      schoolId: schoolId,
      schoolName: school['school_name'] as String? ?? '',
      motto: school['motto'] as String? ?? '',
      primaryColor: school['primary_color'] as String? ?? '#1A73E8',
      secondaryColor: school['secondary_color'] as String? ?? '#34A853',
      logoUrl: branding['logo'] ?? '',
      heroImageUrl: branding['hero_banner'] ?? '',
      languageMode: school['language_mode'] as String? ?? 'english',
      email: school['email'] as String? ?? '',
      phone: school['phone'] as String? ?? '',
      address: school['address'] as String? ?? '',
      website: school['website'] as String? ?? '',
      currentAcademicYear: currentAcademicYear,
      history: content['history'] ?? '',
      vision: content['vision'] ?? '',
      mission: content['mission'] ?? '',
      principalMessage: content['principal_message'] ?? '',
      statistics: statistics,
      achievements: achievements,
      gallery: gallery,
      announcements: announcements,
      events: events,
    );
  }

  Future<String?> _loadCurrentAcademicYear(String schoolId) async {
    final row = await client
        .from('academic_years')
        .select('year_name')
        .eq('school_id', schoolId)
        .eq('is_current', true)
        .maybeSingle();
    return row?['year_name'] as String?;
  }

  // logo/hero_banner live in school_assets (asset_type), NOT on the
  // schools row - those columns don't exist there.
  Future<Map<String, String>> _loadBrandingAssets(String schoolId) async {
    final rows = await client
        .from('school_assets')
        .select()
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .inFilter('asset_type', ['logo', 'hero_banner']);

    final result = <String, String>{};
    for (final row in rows) {
      final type = row['asset_type'] as String?;
      final url = row['file_url'] as String?;
      if (type != null && url != null) result[type] = url;
    }
    return result;
  }

  // The column on school_content is `language`, not `language_code`.
  Future<Map<String, String>> _loadContent({
    required String schoolId,
    required String language,
  }) async {
    final rows = await client
        .from('school_content')
        .select()
        .eq('school_id', schoolId)
        .eq('language', language)
        .eq('is_active', true);

    final result = <String, String>{};
    for (final row in rows) {
      final type = row['content_type'] as String?;
      final content = row['content'] as String?;
      if (type != null && content != null) result[type] = content;
    }
    return result;
  }

  // school_statistics (Migration 012) - school-configured, NOT a live
  // RPC computing counts from private tables. See conversation notes:
  // this was a deliberate rejection of the RPC-based approach.
  Future<List<LandingStatistic>> _loadStatistics({
    required String schoolId,
    required String language,
  }) async {
    final rows = await client
        .from('school_statistics')
        .select()
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final fr = language == 'fr';
    return rows
        .map<LandingStatistic>((r) => LandingStatistic(
              label: ((fr ? r['label_fr'] : r['label_en']) as String?) ??
                  (r['label_en'] as String? ?? ''),
              value: r['value'] as String? ?? '',
            ))
        .toList();
  }

  // school_achievements (Migration 012) - a repeatable list. NOT
  // school_content, which can only hold one row per content_type/language.
  Future<List<LandingAchievement>> _loadAchievements({
    required String schoolId,
    required String language,
  }) async {
    final rows = await client
        .from('school_achievements')
        .select()
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final fr = language == 'fr';
    return rows
        .map<LandingAchievement>((r) => LandingAchievement(
              id: r['id'] as String,
              title: ((fr ? r['title_fr'] : r['title_en']) as String?) ??
                  (r['title_en'] as String? ?? ''),
              description:
                  ((fr ? r['description_fr'] : r['description_en']) as String?) ??
                      (r['description_en'] as String? ?? ''),
              imageUrl: r['image_url'] as String?,
            ))
        .toList();
  }

  Future<List<LandingGalleryItem>> _loadGallery(String schoolId) async {
    final rows = await client
        .from('school_gallery')
        .select()
        .eq('school_id', schoolId)
        .order('display_order', ascending: true);

    return rows
        .map<LandingGalleryItem>((r) => LandingGalleryItem(
              id: r['id'] as String,
              imageUrl: r['image_url'] as String? ?? '',
              caption: r['caption'] as String?,
            ))
        .toList();
  }

  Future<List<LandingAnnouncement>> _loadAnnouncements(String schoolId) async {
    final rows = await client
        .from('announcements')
        .select()
        .eq('school_id', schoolId)
        .eq('status', 'published')
        .order('published_at', ascending: false)
        .limit(3);

    return rows
        .map<LandingAnnouncement>((r) => LandingAnnouncement(
              id: r['id'] as String,
              title: r['title'] as String? ?? '',
              content: r['content'] as String? ?? '',
              publishedAt: r['published_at'] != null
                  ? DateTime.tryParse(r['published_at'] as String)
                  : null,
            ))
        .toList();
  }

  Future<List<LandingEvent>> _loadEvents(String schoolId) async {
    final rows = await client
        .from('school_events')
        .select()
        .eq('school_id', schoolId)
        .eq('status', 'published')
        .order('event_date', ascending: true)
        .limit(3);

    return rows
        .map<LandingEvent>((r) => LandingEvent(
              id: r['id'] as String,
              title: r['title'] as String? ?? '',
              description: r['description'] as String? ?? '',
              eventDate: r['event_date'] != null
                  ? DateTime.tryParse(r['event_date'] as String)
                  : null,
              location: r['location'] as String?,
            ))
        .toList();
  }
}
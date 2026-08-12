class LandingModel {
  final String schoolId;
  final String schoolName;
  final String motto;

  final String primaryColor;
  final String secondaryColor;
  final String logoUrl;
  final String heroImageUrl;

  /// 'english' | 'french' | 'bilingual' - matches schools.language_mode
  final String languageMode;

  // Contact fields - already on the schools row (Migration 002).
  final String email;
  final String phone;
  final String address;
  final String website;

  // Current academic year (e.g. "2026/2027") - null if the school
  // hasn't set one as current yet. Managed by the Principal, not editable here.
  final String? currentAcademicYear;

  // Localized content (school_content, filtered by current language).
  final String history;
  final String vision;
  final String mission;
  final String principalMessage;

  final List<LandingStatistic> statistics;
  final List<LandingAchievement> achievements;
  final List<LandingGalleryItem> gallery;
  final List<LandingAnnouncement> announcements;
  final List<LandingEvent> events;

  const LandingModel({
    required this.schoolId,
    required this.schoolName,
    required this.motto,
    required this.primaryColor,
    required this.secondaryColor,
    required this.logoUrl,
    required this.heroImageUrl,
    required this.languageMode,
    required this.email,
    required this.phone,
    required this.address,
    required this.website,
    required this.currentAcademicYear,
    required this.history,
    required this.vision,
    required this.mission,
    required this.principalMessage,
    required this.statistics,
    required this.achievements,
    required this.gallery,
    required this.announcements,
    required this.events,
  });
}

/// From school_statistics (Migration 012) - school-configured counters.
/// Label is already resolved to the current language by the repository.
class LandingStatistic {
  final String label;
  final String value;
  const LandingStatistic({required this.label, required this.value});
}

/// From school_achievements (Migration 012) - a repeatable list, unlike
/// school_content which can only hold one blob per content_type/language.
class LandingAchievement {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  const LandingAchievement({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
  });
}

/// From school_gallery (Migration 007).
class LandingGalleryItem {
  final String id;
  final String imageUrl;
  final String? caption;
  const LandingGalleryItem({
    required this.id,
    required this.imageUrl,
    this.caption,
  });
}

/// From announcements (Migration 007), status = 'published' only.
class LandingAnnouncement {
  final String id;
  final String title;
  final String content;
  final DateTime? publishedAt;
  const LandingAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    this.publishedAt,
  });
}

/// From school_events (Migration 007), status = 'published' only.
class LandingEvent {
  final String id;
  final String title;
  final String description;
  final DateTime? eventDate;
  final String? location;
  const LandingEvent({
    required this.id,
    required this.title,
    required this.description,
    this.eventDate,
    this.location,
  });
}
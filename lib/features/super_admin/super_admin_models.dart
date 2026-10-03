class SuperAdminProfile {
  final String id;
  final String fullName;
  const SuperAdminProfile({required this.id, required this.fullName});
}

class SchoolSummary {
  final String id;
  final String schoolName;
  final String schoolCode;
  final String domain;
  final String status;
  final String languageMode;
  final String? motto;
  final String? website;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? country;
  final String primaryColor;
  final String secondaryColor;
  final DateTime createdAt;

  const SchoolSummary({
    required this.id,
    required this.schoolName,
    required this.schoolCode,
    required this.domain,
    required this.status,
    required this.languageMode,
    this.motto,
    this.website,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.country,
    required this.primaryColor,
    required this.secondaryColor,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory SchoolSummary.fromMap(Map<String, dynamic> m) => SchoolSummary(
        id: m['id'] as String,
        schoolName: m['school_name'] as String? ?? '',
        schoolCode: m['school_code'] as String? ?? '',
        domain: m['domain'] as String? ?? '',
        status: m['status'] as String? ?? 'active',
        languageMode: m['language_mode'] as String? ?? 'bilingual',
        motto: m['motto'] as String?,
        website: m['website'] as String?,
        email: m['email'] as String?,
        phone: m['phone'] as String?,
        address: m['address'] as String?,
        city: m['city'] as String?,
        country: m['country'] as String?,
        primaryColor: m['primary_color'] as String? ?? '#1A73E8',
        secondaryColor: m['secondary_color'] as String? ?? '#0D47A1',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class SchoolAdminAccount {
  final String role;
  final String fullName;
  final String? phone;
  final String? email;
  final bool isActive;

  const SchoolAdminAccount({required this.role, required this.fullName, this.phone, this.email, required this.isActive});

  factory SchoolAdminAccount.fromMap(Map<String, dynamic> m) => SchoolAdminAccount(
        role: m['role'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        isActive: m['is_active'] as bool? ?? true,
      );
}

class NewAdminCredentials {
  final String role;
  final String fullName;
  final String email;
  final String phone;
  final String temporaryPassword;

  const NewAdminCredentials({required this.role, required this.fullName, required this.email, required this.phone, required this.temporaryPassword});

  factory NewAdminCredentials.fromMap(Map<String, dynamic> m) => NewAdminCredentials(
        role: m['role'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        temporaryPassword: m['temporary_password'] as String? ?? '',
      );
}

// ---------------------------------------------------------------- BRANDING

class SchoolContentItem {
  final String id;
  final String contentType;
  final String language;
  final String? title;
  final String? content;
  final bool isActive;

  const SchoolContentItem({required this.id, required this.contentType, required this.language, this.title, this.content, required this.isActive});

  factory SchoolContentItem.fromMap(Map<String, dynamic> m) => SchoolContentItem(
        id: m['id'] as String,
        contentType: m['content_type'] as String? ?? '',
        language: m['language'] as String? ?? '',
        title: m['title'] as String?,
        content: m['content'] as String?,
        isActive: m['is_active'] as bool? ?? true,
      );
}

class GalleryItem {
  final String id;
  final String imageUrl;
  final String? caption;
  final int displayOrder;
  final bool isFeatured;

  const GalleryItem({required this.id, required this.imageUrl, this.caption, required this.displayOrder, required this.isFeatured});

  factory GalleryItem.fromMap(Map<String, dynamic> m) => GalleryItem(
        id: m['id'] as String,
        imageUrl: m['image_url'] as String? ?? '',
        caption: m['caption'] as String?,
        displayOrder: m['display_order'] as int? ?? 0,
        isFeatured: m['is_featured'] as bool? ?? false,
      );
}

class AchievementItem {
  final String id;
  final String? titleEn;
  final String? titleFr;
  final String? descriptionEn;
  final String? descriptionFr;
  final String? imageUrl;
  final DateTime? achievedOn;
  final int displayOrder;
  final bool isActive;

  const AchievementItem({
    required this.id,
    this.titleEn,
    this.titleFr,
    this.descriptionEn,
    this.descriptionFr,
    this.imageUrl,
    this.achievedOn,
    required this.displayOrder,
    required this.isActive,
  });

  factory AchievementItem.fromMap(Map<String, dynamic> m) => AchievementItem(
        id: m['id'] as String,
        titleEn: m['title_en'] as String?,
        titleFr: m['title_fr'] as String?,
        descriptionEn: m['description_en'] as String?,
        descriptionFr: m['description_fr'] as String?,
        imageUrl: m['image_url'] as String?,
        achievedOn: DateTime.tryParse(m['achieved_on'] as String? ?? ''),
        displayOrder: m['display_order'] as int? ?? 0,
        isActive: m['is_active'] as bool? ?? true,
      );
}

class EventItem {
  final String id;
  final String? title;
  final String? description;
  final DateTime? eventDate;
  final String? eventTime;
  final String? location;
  final String? status;

  const EventItem({required this.id, this.title, this.description, this.eventDate, this.eventTime, this.location, this.status});

  factory EventItem.fromMap(Map<String, dynamic> m) => EventItem(
        id: m['id'] as String,
        title: m['title'] as String?,
        description: m['description'] as String?,
        eventDate: DateTime.tryParse(m['event_date'] as String? ?? ''),
        eventTime: m['event_time'] as String?,
        location: m['location'] as String?,
        status: m['status'] as String?,
      );
}

class SchoolAssetItem {
  final String id;
  final String assetType;
  final String? fileName;
  final String fileUrl;
  final bool isActive;
  final DateTime uploadedAt;

  const SchoolAssetItem({required this.id, required this.assetType, this.fileName, required this.fileUrl, required this.isActive, required this.uploadedAt});

  factory SchoolAssetItem.fromMap(Map<String, dynamic> m) => SchoolAssetItem(
        id: m['id'] as String,
        assetType: m['asset_type'] as String? ?? '',
        fileName: m['file_name'] as String?,
        fileUrl: m['file_url'] as String? ?? '',
        isActive: m['is_active'] as bool? ?? true,
        uploadedAt: DateTime.tryParse(m['uploaded_at'] as String? ?? '') ?? DateTime.now(),
      );
}
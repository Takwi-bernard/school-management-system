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

// ---------------------------------------------------------------- ACADEMIC STRUCTURE

class AcademicStructure {
  final List<AsDepartment> departments;
  final List<AsClass> classes;
  final List<AsSubject> subjects;
  final List<AsSubjectDepartment> subjectDepartments;
  final List<AsSubjectOffering> subjectOfferings;
  final List<AsAcademicYear> academicYears;
  final List<AsAcademicTerm> academicTerms;
  final List<AsExamPeriod> examPeriods;
  final List<AsFee> fees;
  final List<AsInstallment> installments;

  const AcademicStructure({
    required this.departments,
    required this.classes,
    required this.subjects,
    required this.subjectDepartments,
    required this.subjectOfferings,
    required this.academicYears,
    required this.academicTerms,
    required this.examPeriods,
    required this.fees,
    required this.installments,
  });

  factory AcademicStructure.fromMap(Map<String, dynamic> m) => AcademicStructure(
        departments: ((m['departments'] as List?) ?? []).map((d) => AsDepartment.fromMap(Map<String, dynamic>.from(d as Map))).toList(),
        classes: ((m['classes'] as List?) ?? []).map((c) => AsClass.fromMap(Map<String, dynamic>.from(c as Map))).toList(),
        subjects: ((m['subjects'] as List?) ?? []).map((s) => AsSubject.fromMap(Map<String, dynamic>.from(s as Map))).toList(),
        subjectDepartments: ((m['subject_departments'] as List?) ?? []).map((s) => AsSubjectDepartment.fromMap(Map<String, dynamic>.from(s as Map))).toList(),
        subjectOfferings: ((m['subject_offerings'] as List?) ?? []).map((s) => AsSubjectOffering.fromMap(Map<String, dynamic>.from(s as Map))).toList(),
        academicYears: ((m['academic_years'] as List?) ?? []).map((y) => AsAcademicYear.fromMap(Map<String, dynamic>.from(y as Map))).toList(),
        academicTerms: ((m['academic_terms'] as List?) ?? []).map((t) => AsAcademicTerm.fromMap(Map<String, dynamic>.from(t as Map))).toList(),
        examPeriods: ((m['exam_periods'] as List?) ?? []).map((p) => AsExamPeriod.fromMap(Map<String, dynamic>.from(p as Map))).toList(),
        fees: ((m['fees'] as List?) ?? []).map((f) => AsFee.fromMap(Map<String, dynamic>.from(f as Map))).toList(),
        installments: ((m['installments'] as List?) ?? []).map((i) => AsInstallment.fromMap(Map<String, dynamic>.from(i as Map))).toList(),
      );
}

class AsDepartment {
  final String id;
  final String departmentName;
  final String? departmentType;
  const AsDepartment({required this.id, required this.departmentName, this.departmentType});
  factory AsDepartment.fromMap(Map<String, dynamic> m) => AsDepartment(
        id: m['id'] as String,
        departmentName: m['department_name'] as String? ?? '',
        departmentType: m['department_type'] as String?,
      );
}

class AsClass {
  final String id;
  final String className;
  final String? classCode;
  final String departmentId;
  final int levelOrder;
  final int maxStudents;
  final bool isActive;
  const AsClass({
    required this.id,
    required this.className,
    this.classCode,
    required this.departmentId,
    required this.levelOrder,
    required this.maxStudents,
    required this.isActive,
  });
  factory AsClass.fromMap(Map<String, dynamic> m) => AsClass(
        id: m['id'] as String,
        className: m['class_name'] as String? ?? '',
        classCode: m['class_code'] as String?,
        departmentId: m['department_id'] as String? ?? '',
        levelOrder: m['level_order'] as int? ?? 0,
        maxStudents: m['max_students'] as int? ?? 50,
        isActive: m['is_active'] as bool? ?? true,
      );
}

class AsSubject {
  final String id;
  final String subjectCode;
  final String subjectName;
  const AsSubject({required this.id, required this.subjectCode, required this.subjectName});
  factory AsSubject.fromMap(Map<String, dynamic> m) => AsSubject(
        id: m['id'] as String,
        subjectCode: m['subject_code'] as String? ?? '',
        subjectName: m['subject_name'] as String? ?? '',
      );
}

class AsSubjectDepartment {
  final String subjectId;
  final String departmentId;
  final int coefficient;
  const AsSubjectDepartment({required this.subjectId, required this.departmentId, required this.coefficient});
  factory AsSubjectDepartment.fromMap(Map<String, dynamic> m) => AsSubjectDepartment(
        subjectId: m['subject_id'] as String? ?? '',
        departmentId: m['department_id'] as String? ?? '',
        coefficient: m['coefficient'] as int? ?? 1,
      );
}

class AsSubjectOffering {
  final String classId;
  final String subjectId;
  final bool isCompulsory;
  const AsSubjectOffering({required this.classId, required this.subjectId, required this.isCompulsory});
  factory AsSubjectOffering.fromMap(Map<String, dynamic> m) => AsSubjectOffering(
        classId: m['class_id'] as String? ?? '',
        subjectId: m['subject_id'] as String? ?? '',
        isCompulsory: m['is_compulsory'] as bool? ?? false,
      );
}

class AsAcademicYear {
  final String id;
  final String yearName;
  final bool isCurrent;
  const AsAcademicYear({required this.id, required this.yearName, required this.isCurrent});
  factory AsAcademicYear.fromMap(Map<String, dynamic> m) => AsAcademicYear(
        id: m['id'] as String,
        yearName: m['year_name'] as String? ?? '',
        isCurrent: m['is_current'] as bool? ?? false,
      );
}

class AsAcademicTerm {
  final String id;
  final String academicYearId;
  final String termName;
  final int termOrder;
  final bool isCurrent;
  const AsAcademicTerm({required this.id, required this.academicYearId, required this.termName, required this.termOrder, required this.isCurrent});
  factory AsAcademicTerm.fromMap(Map<String, dynamic> m) => AsAcademicTerm(
        id: m['id'] as String,
        academicYearId: m['academic_year_id'] as String? ?? '',
        termName: m['term_name'] as String? ?? '',
        termOrder: m['term_order'] as int? ?? 1,
        isCurrent: m['is_current'] as bool? ?? false,
      );
}

class AsExamPeriod {
  final String id;
  final String academicTermId;
  final String periodName;
  final int sequenceOrder;
  final bool isOpen;
  const AsExamPeriod({required this.id, required this.academicTermId, required this.periodName, required this.sequenceOrder, required this.isOpen});
  factory AsExamPeriod.fromMap(Map<String, dynamic> m) => AsExamPeriod(
        id: m['id'] as String,
        academicTermId: m['academic_term_id'] as String? ?? '',
        periodName: m['period_name'] as String? ?? '',
        sequenceOrder: m['sequence_order'] as int? ?? 1,
        isOpen: m['is_open'] as bool? ?? false,
      );
}

class AsFee {
  final String id;
  final String classId;
  final String academicYearId;
  final double registrationFee;
  final double totalSchoolFee;
  const AsFee({required this.id, required this.classId, required this.academicYearId, required this.registrationFee, required this.totalSchoolFee});
  factory AsFee.fromMap(Map<String, dynamic> m) => AsFee(
        id: m['id'] as String,
        classId: m['class_id'] as String? ?? '',
        academicYearId: m['academic_year_id'] as String? ?? '',
        registrationFee: (m['registration_fee'] as num?)?.toDouble() ?? 0,
        totalSchoolFee: (m['total_school_fee'] as num?)?.toDouble() ?? 0,
      );
}

class AsInstallment {
  final String id;
  final String feeId;
  final String installmentName;
  final double amount;
  final DateTime? dueDate;
  final int displayOrder;
  const AsInstallment({required this.id, required this.feeId, required this.installmentName, required this.amount, this.dueDate, required this.displayOrder});
  factory AsInstallment.fromMap(Map<String, dynamic> m) => AsInstallment(
        id: m['id'] as String,
        feeId: m['fee_id'] as String? ?? '',
        installmentName: m['installment_name'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        dueDate: DateTime.tryParse(m['due_date'] as String? ?? ''),
        displayOrder: m['display_order'] as int? ?? 0,
      );
}
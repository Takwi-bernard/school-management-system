import 'package:flutter/material.dart';



/// A consistent small branding strip (logo + school name) for every
/// parent sub-page - reused instead of rebuilding it per page, so
/// the parent always sees which school they're dealing with, not
/// just a generic AppBar title.
Widget brandedSubpageHeader(BuildContext context, {required String schoolName, required String logoUrl, String? subtitle}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        if (logoUrl.isNotEmpty)
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Image.network(logoUrl, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 20)),
          )
        else
          Icon(Icons.school_rounded, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(schoolName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ],
    ),
  );
}
/// All Parent module data models in one file (matches the
/// consolidation pattern already used for Landing/Auth/Teacher).


class ParentProfile {
  final String parentId; // parents.id
  final String userId;
  final String schoolId;
  final String fullName;
  final String? phone;
  final String? email;

  const ParentProfile({
    required this.parentId,
    required this.userId,
    required this.schoolId,
    required this.fullName,
    this.phone,
    this.email,
  });

  factory ParentProfile.fromMap(Map<String, dynamic> map) {
    final user = map['users'] as Map<String, dynamic>?;
    return ParentProfile(
      parentId: map['id'] as String,
      userId: map['user_id'] as String,
      schoolId: map['school_id'] as String,
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: user?['email'] as String?,
    );
  }
}

/// A child who is a REAL enrolled student (post-approval).
class EnrolledChild {
  final String studentId;
  final String schoolId;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String? classId;
  final String? className;
  final String currentStatus;

  const EnrolledChild({
    required this.studentId,
    required this.schoolId,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.classId,
    this.className,
    required this.currentStatus,
  });

  String get fullName => '$firstName $lastName';

  factory EnrolledChild.fromMap(Map<String, dynamic> map) {
    final enrollments = map['class_enrollments'] as List?;
    final currentEnrollment = enrollments?.isNotEmpty == true ? enrollments!.first as Map : null;
    final classData = currentEnrollment?['classes'] as Map?;
    return EnrolledChild(
      studentId: map['id'] as String,
      schoolId: map['school_id'] as String,
      admissionNumber: map['admission_number'] as String? ?? '',
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      photoUrl: map['student_photo_url'] as String?,
      classId: classData?['id'] as String?,
      className: classData?['class_name'] as String?,
      currentStatus: map['current_status'] as String? ?? 'active',
    );
  }
}

/// A child submission still going through admission - not a real
/// student yet. Separate model because it genuinely represents a
/// different thing (a REQUEST, not an enrolled child).
class PendingAdmission {
  final String id;
  final String schoolId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String requestedClassId;
  final String requestedClassName;
  final String academicYearId;
  final String status; // submitted | awaiting_payment | approved | rejected
  final String? rejectionReason;

  const PendingAdmission({
    required this.id,
    required this.schoolId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.requestedClassId,
    required this.requestedClassName,
    required this.academicYearId,
    required this.status,
    this.rejectionReason,
  });

  String get fullName => '$firstName $lastName';
  bool get needsPayment => status == 'awaiting_payment';
  bool get isRejected => status == 'rejected';

  factory PendingAdmission.fromMap(Map<String, dynamic> map) {
    final classData = map['classes'] as Map?;
    return PendingAdmission(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      photoUrl: map['photo_url'] as String?,
      requestedClassId: map['requested_class_id'] as String,
      requestedClassName: classData?['class_name'] as String? ?? '',
      academicYearId: map['academic_year_id'] as String,
      status: map['status'] as String? ?? 'submitted',
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}

/// A class a parent can pick during enrollment - dynamic, from the
/// school's own `classes` table. Never a hardcoded dropdown.
class ClassOption {
  final String id;
  final String className;
  final String? departmentId;

  const ClassOption({required this.id, required this.className, this.departmentId});

  factory ClassOption.fromMap(Map<String, dynamic> map) => ClassOption(
        id: map['id'] as String,
        className: map['class_name'] as String? ?? '',
        departmentId: map['department_id'] as String?,
      );
}

/// One subject offered for a specific class/department - drives the
/// dynamic subject-selection step of enrollment entirely from what
/// the Principal configured (subject_offerings). A class/department
/// with zero offerings means "no selectable subjects for this class"
/// - the form simply skips that step, never assumes a default.
class SubjectOfferingOption {
  final String subjectId;
  final String subjectName;
  final bool isCompulsory;

  const SubjectOfferingOption({
    required this.subjectId,
    required this.subjectName,
    required this.isCompulsory,
  });

  factory SubjectOfferingOption.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map?;
    return SubjectOfferingOption(
      subjectId: map['subject_id'] as String,
      subjectName: subject?['subject_name'] as String? ?? '',
      isCompulsory: map['is_compulsory'] as bool? ?? false,
    );
  }
}

class FeeSummary {
  final String feeId;
  final String feeName;
  final double totalAmount;
  final double amountPaid;
  final List<InstallmentSummary> installments;

  const FeeSummary({
    required this.feeId,
    required this.feeName,
    required this.totalAmount,
    required this.amountPaid,
    required this.installments,
  });

  double get balance => (totalAmount - amountPaid).clamp(0, double.infinity);
  bool get fullyPaid => balance <= 0;
}

class InstallmentSummary {
  final String installmentId;
  final String name;
  final double amount;
  final bool isPaid;
  final DateTime? dueDate;

  const InstallmentSummary({
    required this.installmentId,
    required this.name,
    required this.amount,
    required this.isPaid,
    this.dueDate,
  });
}

class PaymentTransaction {
  final String id;
  final String status; // pending | success | failed
  final double amount;
  final String paymentPurpose;
  final String? transactionReference;
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    required this.status,
    required this.amount,
    required this.paymentPurpose,
    this.transactionReference,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isSuccessful => status == 'success';
  bool get isFailed => status == 'failed';

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) => PaymentTransaction(
        id: map['id'] as String,
        status: map['status'] as String? ?? 'pending',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        paymentPurpose: (map['metadata'] as Map?)?['payment_purpose'] as String? ?? 'Payment',
        transactionReference: map['transaction_reference'] as String?,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class AcademicTermOption {
  final String id;
  final String termName;
  final bool isCurrent;
  const AcademicTermOption({required this.id, required this.termName, required this.isCurrent});

  factory AcademicTermOption.fromMap(Map<String, dynamic> map) => AcademicTermOption(
        id: map['id'] as String,
        termName: map['term_name'] as String? ?? '',
        isCurrent: map['is_current'] as bool? ?? false,
      );
}

class SubjectResult {
  final String subjectName;
  final double score;
  final int coefficient;
  final double weightedScore;
  final String? grade;
  final String? remark;

  const SubjectResult({
    required this.subjectName,
    required this.score,
    required this.coefficient,
    required this.weightedScore,
    this.grade,
    this.remark,
  });

  factory SubjectResult.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map?;
    return SubjectResult(
      subjectName: subject?['subject_name'] as String? ?? '',
      score: (map['score'] as num).toDouble(),
      coefficient: map['coefficient'] as int,
      weightedScore: (map['weighted_score'] as num).toDouble(),
      grade: map['grade'] as String?,
      remark: map['remark'] as String?,
    );
  }
}

class ReportCardSummary {
  final String studentName;
  final String className;
  final String termName;
  final double? overallAverage;
  final int? classRank;
  final int? totalStudents;
  final String? principalComment;
  final List<SubjectResult> subjects;

  const ReportCardSummary({
    required this.studentName,
    required this.className,
    required this.termName,
    this.overallAverage,
    this.classRank,
    this.totalStudents,
    this.principalComment,
    required this.subjects,
  });

  factory ReportCardSummary.fromMap(Map<String, dynamic> report, List<dynamic> subjectRows) {
    final student = report['students'] as Map?;
    final classData = report['classes'] as Map?;
    final term = report['academic_terms'] as Map?;
    return ReportCardSummary(
      studentName: '${student?['first_name'] ?? ''} ${student?['last_name'] ?? ''}'.trim(),
      className: classData?['class_name'] as String? ?? '',
      termName: term?['term_name'] as String? ?? '',
      overallAverage: (report['overall_average'] as num?)?.toDouble(),
      classRank: report['class_rank'] as int?,
      totalStudents: report['total_students'] as int?,
      principalComment: report['principal_comment'] as String?,
      subjects: subjectRows.map((r) => SubjectResult.fromMap(Map<String, dynamic>.from(r))).toList(),
    );
  }
}

class AttendanceSummary {
  final int present;
  final int absent;
  final int late;
  final int excused;
  const AttendanceSummary({required this.present, required this.absent, required this.late, required this.excused});

  int get total => present + absent + late + excused;
}

class TeacherComment {
  final String teacherName;
  final String examPeriodName;
  final String comment;
  final DateTime createdAt;

  const TeacherComment({
    required this.teacherName,
    required this.examPeriodName,
    required this.comment,
    required this.createdAt,
  });

  factory TeacherComment.fromMap(Map<String, dynamic> map) {
    final teacher = map['teachers'] as Map?;
    final period = map['exam_periods'] as Map?;
    return TeacherComment(
      teacherName: teacher?['full_name'] as String? ?? '',
      examPeriodName: period?['period_name'] as String? ?? '',
      comment: map['comment'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Rebuilds the school's branded theme from its stored colors.
/// Used on every parent page (not just the dashboard) because a page
/// reached via Navigator.push attaches to the app's ROOT navigator -
/// above the dashboard's own Theme wrapper - so it does NOT inherit
/// branding through Theme.of(context) alone. Cheap to recompute.
ThemeData buildSchoolTheme(String primaryColorHex, String secondaryColorHex) {
  final primary = _parseColor(primaryColorHex);
  final secondary = _parseColor(secondaryColorHex);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
  );
}

Color _parseColor(String hex) {
  var v = hex.replaceAll('#', '');
  if (v.length == 6) v = 'FF$v';
  return Color(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
}
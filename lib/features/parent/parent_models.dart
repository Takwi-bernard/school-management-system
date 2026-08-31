/// All Parent module data models in one file (matches the
/// consolidation pattern already used for Landing/Auth/Teacher).


import 'package:flutter/material.dart';

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
  final String? className;
  final String currentStatus;

  const EnrolledChild({
    required this.studentId,
    required this.schoolId,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
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
      className: classData?['class_name'] as String?,
      currentStatus: map['current_status'] as String? ?? 'active',
    );
  }
}

/// A child submission still going through admission - not a real
/// student yet. Separate model because it genuinely represents a
/// different thing (a REQUEST, not an enrolled child) with a
/// different, smaller set of guaranteed fields.
class PendingAdmission {
  final String id;
  final String schoolId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String requestedClassId;
  final String requestedClassName;
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
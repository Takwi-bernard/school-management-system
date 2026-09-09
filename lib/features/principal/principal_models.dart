import 'package:flutter/material.dart';

class PrincipalProfile {
  final String principalId;
  final String userId;
  final String schoolId;
  final String fullName;

  const PrincipalProfile({
    required this.principalId,
    required this.userId,
    required this.schoolId,
    required this.fullName,
  });

  factory PrincipalProfile.fromMap(Map<String, dynamic> map) => PrincipalProfile(
        principalId: map['id'] as String,
        userId: map['user_id'] as String,
        schoolId: map['school_id'] as String,
        fullName: map['full_name'] as String? ?? '',
      );
}

class DepartmentOption {
  final String id;
  final String departmentName;
  const DepartmentOption({required this.id, required this.departmentName});

  factory DepartmentOption.fromMap(Map<String, dynamic> map) => DepartmentOption(
        id: map['id'] as String,
        departmentName: map['department_name'] as String? ?? '',
      );
}

class ManagedClass {
  final String id;
  final String className;
  final String? classCode;
  final String departmentId;
  final String? departmentName;
  final int levelOrder;
  final int maxStudents;
  final bool isActive;

  const ManagedClass({
    required this.id,
    required this.className,
    this.classCode,
    required this.departmentId,
    this.departmentName,
    required this.levelOrder,
    required this.maxStudents,
    required this.isActive,
  });

  factory ManagedClass.fromMap(Map<String, dynamic> map) {
    final dept = map['departments'] as Map?;
    return ManagedClass(
      id: map['id'] as String,
      className: map['class_name'] as String? ?? '',
      classCode: map['class_code'] as String?,
      departmentId: map['department_id'] as String,
      departmentName: dept?['department_name'] as String?,
      levelOrder: map['level_order'] as int? ?? 0,
      maxStudents: map['max_students'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class PendingTeacher {
  final String teacherId;
  final String userId;
  final String fullName;
  final String? phone;
  final String? email;
  final DateTime? createdAt;

  const PendingTeacher({
    required this.teacherId,
    required this.userId,
    required this.fullName,
    this.phone,
    this.email,
    this.createdAt,
  });

  factory PendingTeacher.fromMap(Map<String, dynamic> map) {
    final user = map['users'] as Map?;
    return PendingTeacher(
      teacherId: map['id'] as String,
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: user?['email'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }
}

class ApprovedTeacher {
  final String teacherId;
  final String fullName;
  final String? phone;
  final int assignmentCount;

  const ApprovedTeacher({
    required this.teacherId,
    required this.fullName,
    this.phone,
    required this.assignmentCount,
  });
}

class ExamPeriodOption {
  final String id;
  final String periodName;
  final bool isOpen;
  final DateTime? marksDueDate;

  const ExamPeriodOption({required this.id, required this.periodName, required this.isOpen, this.marksDueDate});

  factory ExamPeriodOption.fromMap(Map<String, dynamic> map) => ExamPeriodOption(
        id: map['id'] as String,
        periodName: map['period_name'] as String? ?? '',
        isOpen: map['is_open'] as bool? ?? false,
        marksDueDate: DateTime.tryParse(map['marks_due_date'] as String? ?? ''),
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
// Represents the status of a report card for a student, including whether it exists, whether it's published, and when it was published (if applicable).  
class ReportCardStatus {
  final String studentId;
  final String studentName;
  final String? reportCardId;
  final bool exists;
  final bool isPublished;
  final DateTime? publishAt;

  const ReportCardStatus({
    required this.studentId,
    required this.studentName,
    this.reportCardId,
    required this.exists,
    required this.isPublished,
    this.publishAt,
  });
}
// Represents a single mark that has been submitted by a teacher for a student, along with the subject, class, and teacher details.
class SubmittedMark {
  final String id;
  final String studentName;
  final String subjectName;
  final String className;
  final String teacherName;
  final double score;
  final int coefficient;
  final String status;
  final String? remarks;
  final String? principalFeedback;

  const SubmittedMark({
    required this.id,
    required this.studentName,
    required this.subjectName,
    required this.className,
    required this.teacherName,
    required this.score,
    required this.coefficient,
    required this.status,
    this.remarks,
    this.principalFeedback,
  });

  factory SubmittedMark.fromMap(Map<String, dynamic> map) {
    final student = map['students'] as Map?;
    final subject = map['subjects'] as Map?;
    final cls = map['classes'] as Map?;
    final teacher = map['teachers'] as Map?;
    return SubmittedMark(
      id: map['id'] as String,
      studentName: '${student?['first_name'] ?? ''} ${student?['last_name'] ?? ''}'.trim(),
      subjectName: subject?['subject_name'] as String? ?? '',
      className: cls?['class_name'] as String? ?? '',
      teacherName: teacher?['full_name'] as String? ?? '',
      score: (map['score'] as num).toDouble(),
      coefficient: map['coefficient'] as int? ?? 1,
      status: map['status'] as String? ?? 'submitted',
      remarks: map['remarks'] as String?,
      principalFeedback: map['principal_feedback'] as String?,
    );
  }
}
/// Represents a single subject that a teacher is assigned to teach, along with the class it's for and how many periods per week.
class TeacherAssignmentInfo {
  final String id;
  final String className;
  final String subjectName;
  final int periodsPerWeek;

  const TeacherAssignmentInfo({
    required this.id,
    required this.className,
    required this.subjectName,
    required this.periodsPerWeek,
  });

  factory TeacherAssignmentInfo.fromMap(Map<String, dynamic> map) {
    final cls = map['classes'] as Map?;
    final subj = map['subjects'] as Map?;
    return TeacherAssignmentInfo(
      id: map['id'] as String,
      className: cls?['class_name'] as String? ?? '',
      subjectName: subj?['subject_name'] as String? ?? '',
      periodsPerWeek: map['periods_per_week'] as int? ?? 0,
    );
  }
}

class ManagedSubject {
  final String id;
  final String subjectCode;
  final String subjectName;
  const ManagedSubject({required this.id, required this.subjectCode, required this.subjectName});

  factory ManagedSubject.fromMap(Map<String, dynamic> map) => ManagedSubject(
        id: map['id'] as String,
        subjectCode: map['subject_code'] as String? ?? '',
        subjectName: map['subject_name'] as String? ?? '',
      );
}

/// Every subject at the school, annotated with whether it's currently
/// offered on THIS class - lets the Principal toggle any subject on
/// or off, not just ones already offered.
class SubjectOfferingRow {
  final String subjectId;
  final String subjectName;
  final bool isOffered;
  final bool isCompulsory;

  const SubjectOfferingRow({
    required this.subjectId,
    required this.subjectName,
    required this.isOffered,
    required this.isCompulsory,
  });
}

class ManagedInstallment {
  final String? id; // null = not yet saved
  String name;
  double amount;
  DateTime? dueDate;
  int displayOrder;

  ManagedInstallment({this.id, required this.name, required this.amount, this.dueDate, required this.displayOrder});
}

class ManagedFeeConfig {
  final String? feeId;
  double registrationFee;
  List<ManagedInstallment> installments;

  ManagedFeeConfig({this.feeId, required this.registrationFee, required this.installments});

  double get totalSchoolFee => installments.fold(0.0, (sum, i) => sum + i.amount);

  factory ManagedFeeConfig.empty() => ManagedFeeConfig(registrationFee: 0, installments: []);

  factory ManagedFeeConfig.fromMap(Map<String, dynamic> map, List<dynamic> installmentRows) {
    final installments = installmentRows
        .map((i) => ManagedInstallment(
              id: i['id'] as String,
              name: i['installment_name'] as String? ?? '',
              amount: (i['amount'] as num).toDouble(),
              dueDate: DateTime.tryParse(i['due_date'] as String? ?? ''),
              displayOrder: i['display_order'] as int? ?? 0,
            ))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return ManagedFeeConfig(
      feeId: map['id'] as String,
      registrationFee: (map['registration_fee'] as num).toDouble(),
      installments: installments,
    );
  }
}

ThemeData buildSchoolTheme(String primaryColorHex, String secondaryColorHex) {
  Color parse(String hex) {
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return Color(int.tryParse(v, radix: 16) ?? 0xFF1A73E8);
  }
  final primary = parse(primaryColorHex);
  final secondary = parse(secondaryColorHex);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary),
  );
}

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
              if (subtitle != null) Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ],
    ),
  );
}
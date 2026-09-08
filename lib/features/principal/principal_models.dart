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
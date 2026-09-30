class SecretaryProfile {
  final String fullName;
  const SecretaryProfile({required this.fullName});
}

class ParentMatch {
  final String parentId;
  final String fullName;
  final String? phone;
  final String? email;
  const ParentMatch({required this.parentId, required this.fullName, this.phone, this.email});

  factory ParentMatch.fromMap(Map<String, dynamic> m) => ParentMatch(
        parentId: m['parent_id'] as String,
        fullName: m['full_name'] as String? ?? '',
        phone: m['phone'] as String?,
        email: m['email'] as String?,
      );
}

class NewParentCredentials {
  final String parentId;
  final String fullName;
  final String email;
  final String phone;
  final String temporaryPassword;
  const NewParentCredentials({
    required this.parentId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.temporaryPassword,
  });

  factory NewParentCredentials.fromMap(Map<String, dynamic> m) => NewParentCredentials(
        parentId: m['parent_id'] as String,
        fullName: m['full_name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        temporaryPassword: m['temporary_password'] as String? ?? '',
      );
}

class EnrollClass {
  final String id;
  final String className;
  final String departmentId;
  final String departmentName;
  const EnrollClass({required this.id, required this.className, required this.departmentId, required this.departmentName});

  factory EnrollClass.fromMap(Map<String, dynamic> m) {
    final dept = m['departments'] as Map?;
    return EnrollClass(
      id: m['id'] as String,
      className: m['class_name'] as String? ?? '',
      departmentId: m['department_id'] as String? ?? '',
      departmentName: dept?['department_name'] as String? ?? '',
    );
  }
}

class EnrollSubject {
  final String subjectId;
  final String name;
  final bool isCompulsory;
  const EnrollSubject({required this.subjectId, required this.name, required this.isCompulsory});

  factory EnrollSubject.fromMap(Map<String, dynamic> m) {
    final subject = m['subjects'] as Map?;
    return EnrollSubject(
      subjectId: m['subject_id'] as String,
      name: subject?['subject_name'] as String? ?? '',
      isCompulsory: m['is_compulsory'] as bool? ?? false,
    );
  }
}

class EnrollmentResult {
  final String admissionRequestId;
  final double? registrationFee;
  const EnrollmentResult({required this.admissionRequestId, this.registrationFee});
}

class AwaitingRegistration {
  final String id;
  final String childName;
  final String className;
  final String departmentName;
  final String parentName;
  final String? parentPhone;
  final double? fee;
  final DateTime createdAt;
  const AwaitingRegistration({
    required this.id,
    required this.childName,
    required this.className,
    required this.departmentName,
    required this.parentName,
    this.parentPhone,
    this.fee,
    required this.createdAt,
  });

  factory AwaitingRegistration.fromMap(Map<String, dynamic> m) => AwaitingRegistration(
        id: m['id'] as String,
        childName: m['child_name'] as String? ?? '',
        className: m['class_name'] as String? ?? '',
        departmentName: m['department_name'] as String? ?? '',
        parentName: m['parent_name'] as String? ?? '',
        parentPhone: m['parent_phone'] as String?,
        fee: (m['registration_fee'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class InstallmentLookup {
  final String id;
  final String name;
  final double amount;
  final DateTime? dueDate;
  final bool isPaid;
  const InstallmentLookup({required this.id, required this.name, required this.amount, this.dueDate, required this.isPaid});

  factory InstallmentLookup.fromMap(Map<String, dynamic> m) => InstallmentLookup(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        amount: (m['amount'] as num).toDouble(),
        dueDate: DateTime.tryParse(m['due_date'] as String? ?? ''),
        isPaid: m['is_paid'] as bool? ?? false,
      );
}

class StudentFeeLookup {
  final String studentId;
  final String admissionNumber;
  final String fullName;
  final String className;
  final String departmentName;
  final double totalFee;
  final double amountPaid;
  final List<InstallmentLookup> installments;
  const StudentFeeLookup({
    required this.studentId,
    required this.admissionNumber,
    required this.fullName,
    required this.className,
    required this.departmentName,
    required this.totalFee,
    required this.amountPaid,
    required this.installments,
  });

  factory StudentFeeLookup.fromMap(Map<String, dynamic> m) => StudentFeeLookup(
        studentId: m['student_id'] as String,
        admissionNumber: m['admission_number'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        className: m['class_name'] as String? ?? '',
        departmentName: m['department_name'] as String? ?? '',
        totalFee: (m['total_fee'] as num?)?.toDouble() ?? 0,
        amountPaid: (m['amount_paid'] as num?)?.toDouble() ?? 0,
        installments: ((m['installments'] as List?) ?? [])
            .map((i) => InstallmentLookup.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
      );
}

class RecordedPayment {
  final String id;
  final String reference;
  final double amount;
  final String purpose;
  final String childName;
  final DateTime createdAt;
  const RecordedPayment({
    required this.id,
    required this.reference,
    required this.amount,
    required this.purpose,
    required this.childName,
    required this.createdAt,
  });

  factory RecordedPayment.fromMap(Map<String, dynamic> m) => RecordedPayment(
        id: m['id'] as String,
        reference: m['reference'] as String? ?? '-',
        amount: (m['amount'] as num).toDouble(),
        purpose: m['purpose'] as String? ?? '',
        childName: m['child_name'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class OnlinePaymentTicket {
  final String id;
  final String status;
  final String? reference;
  const OnlinePaymentTicket({required this.id, required this.status, this.reference});

  factory OnlinePaymentTicket.fromMap(Map<String, dynamic> m) => OnlinePaymentTicket(
        id: m['id'] as String,
        status: m['status'] as String? ?? 'pending',
        reference: m['reference'] as String?,
      );
}
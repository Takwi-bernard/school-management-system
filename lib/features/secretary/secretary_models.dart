class SecretaryProfile {
  final String secretaryId;
  final String userId;
  final String schoolId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? photoUrl;

  const SecretaryProfile({
    required this.secretaryId,
    required this.userId,
    required this.schoolId,
    required this.fullName,
    this.phone,
    this.email,
    this.photoUrl,
  });
}

class ParentChild {
  final String studentId;
  final String fullName;
  final String? className;
  const ParentChild({required this.studentId, required this.fullName, this.className});

  factory ParentChild.fromMap(Map<String, dynamic> m) => ParentChild(
        studentId: m['student_id'] as String,
        fullName: m['full_name'] as String? ?? '',
        className: m['class_name'] as String?,
      );
}

class ParentMatch {
  final String parentId;
  final String fullName;
  final String? phone;
  final String? email;
  final List<ParentChild> children;
  const ParentMatch({required this.parentId, required this.fullName, this.phone, this.email, this.children = const []});

  factory ParentMatch.fromMap(Map<String, dynamic> m) => ParentMatch(
        parentId: m['parent_id'] as String,
        fullName: m['full_name'] as String? ?? '',
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        children: ((m['children'] as List?) ?? []).map((c) => ParentChild.fromMap(Map<String, dynamic>.from(c as Map))).toList(),
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
  final String firstName;
  final String lastName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final String? guardianName;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? address;
  final String classId;
  final String? departmentId;
  final String className;
  final String departmentName;
  final String parentName;
  final String? parentPhone;
  final double? fee;
  final List<String> subjectIds;
  final DateTime createdAt;

  const AwaitingRegistration({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.dateOfBirth,
    this.photoUrl,
    this.guardianName,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.address,
    required this.classId,
    this.departmentId,
    required this.className,
    required this.departmentName,
    required this.parentName,
    this.parentPhone,
    this.fee,
    this.subjectIds = const [],
    required this.createdAt,
  });

  String get childName => '$firstName $lastName'.trim();

  factory AwaitingRegistration.fromMap(Map<String, dynamic> m) => AwaitingRegistration(
        id: m['id'] as String,
        firstName: m['first_name'] as String? ?? '',
        lastName: m['last_name'] as String? ?? '',
        gender: m['gender'] as String?,
        dateOfBirth: DateTime.tryParse(m['date_of_birth'] as String? ?? ''),
        photoUrl: m['photo_url'] as String?,
        guardianName: m['guardian_name'] as String?,
        emergencyContactName: m['emergency_contact_name'] as String?,
        emergencyContactPhone: m['emergency_contact_phone'] as String?,
        address: m['address'] as String?,
        classId: m['class_id'] as String? ?? '',
        departmentId: m['department_id'] as String?,
        className: m['class_name'] as String? ?? '',
        departmentName: m['department_name'] as String? ?? '',
        parentName: m['parent_name'] as String? ?? '',
        parentPhone: m['parent_phone'] as String?,
        fee: (m['registration_fee'] as num?)?.toDouble(),
        subjectIds: ((m['subject_ids'] as List?) ?? []).map((s) => s.toString()).toList(),
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

class DirectoryStudent {
  final String studentId;
  final String admissionNumber;
  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? className;
  final String? departmentName;
  final String? guardianName;
  final String? guardianPhone;

  const DirectoryStudent({
    required this.studentId,
    required this.admissionNumber,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    this.className,
    this.departmentName,
    this.guardianName,
    this.guardianPhone,
  });

  factory DirectoryStudent.fromMap(Map<String, dynamic> m) => DirectoryStudent(
        studentId: m['student_id'] as String,
        admissionNumber: m['admission_number'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        gender: m['gender'] as String?,
        dateOfBirth: DateTime.tryParse(m['date_of_birth'] as String? ?? ''),
        className: m['class_name'] as String?,
        departmentName: m['department_name'] as String?,
        guardianName: m['guardian_name'] as String?,
        guardianPhone: m['guardian_phone'] as String?,
      );
}

class SecretaryDashboard {
  final int awaitingRegistrationCount;
  final int collectedTodayCount;
  final double collectedTodayTotal;
  final bool mobileMoneyConfigured;

  const SecretaryDashboard({
    required this.awaitingRegistrationCount,
    required this.collectedTodayCount,
    required this.collectedTodayTotal,
    required this.mobileMoneyConfigured,
  });

  factory SecretaryDashboard.fromMap(Map<String, dynamic> m) => SecretaryDashboard(
        awaitingRegistrationCount: m['awaiting_registration_count'] as int? ?? 0,
        collectedTodayCount: m['collected_today_count'] as int? ?? 0,
        collectedTodayTotal: (m['collected_today_total'] as num?)?.toDouble() ?? 0,
        mobileMoneyConfigured: m['mobile_money_configured'] as bool? ?? false,
      );
}

class MyPayment {
  final String id;
  final String childName;
  final double amount;
  final String purpose;
  final String method;
  final DateTime createdAt;
  final bool correctionRequested;

  const MyPayment({
    required this.id,
    required this.childName,
    required this.amount,
    required this.purpose,
    required this.method,
    required this.createdAt,
    required this.correctionRequested,
  });

  factory MyPayment.fromMap(Map<String, dynamic> m) => MyPayment(
        id: m['id'] as String,
        childName: m['child_name'] as String? ?? '',
        amount: (m['amount'] as num).toDouble(),
        purpose: m['purpose'] as String? ?? '',
        method: m['method'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
        correctionRequested: m['correction_requested'] as bool? ?? false,
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
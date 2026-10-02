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
  final DateTime createdAt;

  const SchoolSummary({
    required this.id,
    required this.schoolName,
    required this.schoolCode,
    required this.domain,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory SchoolSummary.fromMap(Map<String, dynamic> m) => SchoolSummary(
        id: m['id'] as String,
        schoolName: m['school_name'] as String? ?? '',
        schoolCode: m['school_code'] as String? ?? '',
        domain: m['domain'] as String? ?? '',
        status: m['status'] as String? ?? 'active',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class SchoolAdminAccount {
  final String role;
  final String fullName;
  final String? phone;
  final String? email;
  final bool isActive;

  const SchoolAdminAccount({
    required this.role,
    required this.fullName,
    this.phone,
    this.email,
    required this.isActive,
  });

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

  const NewAdminCredentials({
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.temporaryPassword,
  });

  factory NewAdminCredentials.fromMap(Map<String, dynamic> m) => NewAdminCredentials(
        role: m['role'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        temporaryPassword: m['temporary_password'] as String? ?? '',
      );
}
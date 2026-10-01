class ProprietorProfile {
  final String fullName;
  const ProprietorProfile({required this.fullName});
}

class SchoolOverview {
  final int totalStudents;
  final int totalTeachersApproved;
  final int totalTeachersPending;
  final int totalClasses;
  final int totalDepartments;
  final int admissionsAwaitingPayment;
  final int admissionsUnderReview;
  final double revenueThisMonth;
  final double revenueAllTime;
  final double registrationRevenue;
  final double installmentRevenue;
  final int paymentsThisMonth;

  const SchoolOverview({
    required this.totalStudents,
    required this.totalTeachersApproved,
    required this.totalTeachersPending,
    required this.totalClasses,
    required this.totalDepartments,
    required this.admissionsAwaitingPayment,
    required this.admissionsUnderReview,
    required this.revenueThisMonth,
    required this.revenueAllTime,
    required this.registrationRevenue,
    required this.installmentRevenue,
    required this.paymentsThisMonth,
  });
}

class ClassEnrollmentCount {
  final String className;
  final String departmentName;
  final int studentCount;
  final int capacity;
  const ClassEnrollmentCount({
    required this.className,
    required this.departmentName,
    required this.studentCount,
    required this.capacity,
  });
}

class RecentPayment {
  final String childName;
  final double amount;
  final String purpose;
  final String method;
  final DateTime date;
  const RecentPayment({
    required this.childName,
    required this.amount,
    required this.purpose,
    required this.method,
    required this.date,
  });
}
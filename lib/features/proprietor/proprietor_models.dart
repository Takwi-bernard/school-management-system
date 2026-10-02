class ProprietorProfile {
  final String fullName;
  const ProprietorProfile({required this.fullName});
}

class MonthPoint {
  final DateTime month;
  final double value;
  const MonthPoint({required this.month, required this.value});
}

class FinancialOverview {
  final double totalIncome;
  final double totalExpenditure;
  final double netPosition;
  final double incomeThisMonth;
  final double expenditureThisMonth;
  final List<MonthPoint> incomeTrend;
  final List<MonthPoint> expenditureTrend;
  final double registrationIncome;
  final double installmentIncome;

  const FinancialOverview({
    required this.totalIncome,
    required this.totalExpenditure,
    required this.netPosition,
    required this.incomeThisMonth,
    required this.expenditureThisMonth,
    required this.incomeTrend,
    required this.expenditureTrend,
    required this.registrationIncome,
    required this.installmentIncome,
  });
}

class IncomeRecord {
  final String childName;
  final double amount;
  final String purpose;
  final String method;
  final DateTime date;
  const IncomeRecord({
    required this.childName,
    required this.amount,
    required this.purpose,
    required this.method,
    required this.date,
  });
}

class ExpenseRecord {
  final String id;
  final String category;
  final String? description;
  final double amount;
  final DateTime date;
  final String method;
  final String? paidTo;
  final String? receiptUrl;
  final String recordedByName;

  const ExpenseRecord({
    required this.id,
    required this.category,
    this.description,
    required this.amount,
    required this.date,
    required this.method,
    this.paidTo,
    this.receiptUrl,
    required this.recordedByName,
  });

  factory ExpenseRecord.fromMap(Map<String, dynamic> m) {
    final recorder = m['users'] as Map?;
    return ExpenseRecord(
      id: m['id'] as String,
      category: m['category'] as String? ?? '',
      description: m['description'] as String?,
      amount: (m['amount'] as num).toDouble(),
      date: DateTime.tryParse(m['expense_date'] as String? ?? '') ?? DateTime.now(),
      method: m['payment_method'] as String? ?? '',
      paidTo: m['paid_to'] as String?,
      receiptUrl: m['receipt_url'] as String?,
      recordedByName: recorder?['email'] as String? ?? 'Staff',
    );
  }
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

class YearGrowthPoint {
  final String yearName;
  final int studentCount;
  final bool isCurrent;
  const YearGrowthPoint({required this.yearName, required this.studentCount, required this.isCurrent});
}

class ActiveActors {
  final int principals;
  final int secretaries;
  final int proprietors;
  final int teachersApproved;
  final int teachersPending;
  final int parents;

  const ActiveActors({
    required this.principals,
    required this.secretaries,
    required this.proprietors,
    required this.teachersApproved,
    required this.teachersPending,
    required this.parents,
  });
}

class SchoolSnapshot {
  final int totalStudents;
  final int totalClasses;
  final int totalDepartments;
  final int admissionsAwaitingPayment;
  final int admissionsUnderReview;

  const SchoolSnapshot({
    required this.totalStudents,
    required this.totalClasses,
    required this.totalDepartments,
    required this.admissionsAwaitingPayment,
    required this.admissionsUnderReview,
  });

  
}
class AiSchoolReport {
  final String id;
  final String summary;
  final List<String> strengths;
  final List<String> concerns;
  final List<String> recommendations;
  final DateTime generatedAt;

  const AiSchoolReport({
    required this.id,
    required this.summary,
    required this.strengths,
    required this.concerns,
    required this.recommendations,
    required this.generatedAt,
  });

  factory AiSchoolReport.fromMap(Map<String, dynamic> m) => AiSchoolReport(
        id: m['id'] as String,
        summary: m['summary'] as String? ?? '',
        strengths: List<String>.from(m['strengths'] as List? ?? []),
        concerns: List<String>.from(m['concerns'] as List? ?? []),
        recommendations: List<String>.from(m['recommendations'] as List? ?? []),
        generatedAt: DateTime.tryParse(m['generated_at'] as String? ?? '') ?? DateTime.now(),
      );
}


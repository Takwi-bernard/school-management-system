double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);
List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

// ============================================================ profile

class ProprietorProfile {
  final String proprietorId;
  final String userId;
  final String schoolId;
  final String fullName;
  final String? phone;
  final String? photoUrl;
  final String? email;

  const ProprietorProfile({
    required this.proprietorId,
    required this.userId,
    required this.schoolId,
    required this.fullName,
    this.phone,
    this.photoUrl,
    this.email,
  });
}

// ============================================================ finance

class FinanceMonth {
  final DateTime month;
  final double income;
  final double registration;
  final double installment;
  final double expense;
  const FinanceMonth({
    required this.month,
    required this.income,
    required this.registration,
    required this.installment,
    required this.expense,
  });

  double get net => income - expense;

  factory FinanceMonth.fromJson(Map<String, dynamic> j) => FinanceMonth(
        month: DateTime.tryParse('${j['m']}') ?? DateTime.now(),
        income: _d(j['income']),
        registration: _d(j['registration']),
        installment: _d(j['installment']),
        expense: _d(j['expense']),
      );
}

class FinanceDay {
  final DateTime day;
  final double income;
  final double expense;
  const FinanceDay({required this.day, required this.income, required this.expense});

  factory FinanceDay.fromJson(Map<String, dynamic> j) => FinanceDay(
        day: DateTime.tryParse('${j['d']}') ?? DateTime.now(),
        income: _d(j['income']),
        expense: _d(j['expense']),
      );
}

class MethodSlice {
  final String method;
  final double total;
  final int count;
  const MethodSlice({required this.method, required this.total, required this.count});

  factory MethodSlice.fromJson(Map<String, dynamic> j) =>
      MethodSlice(method: '${j['method'] ?? ''}', total: _d(j['total']), count: _i(j['count']));
}

class CategorySlice {
  final String category;
  final double total;
  final int count;
  const CategorySlice({required this.category, required this.total, required this.count});

  factory CategorySlice.fromJson(Map<String, dynamic> j) =>
      CategorySlice(category: '${j['category'] ?? ''}', total: _d(j['total']), count: _i(j['count']));
}

class FinanceSummary {
  final double totalIncome;
  final double totalExpense;
  final double incomeThisMonth;
  final double incomePrevMonth;
  final double expenseThisMonth;
  final double expensePrevMonth;
  final double incomeToday;
  final int paymentsCount;
  final double registrationTotal;
  final double installmentTotal;
  final List<FinanceMonth> months;
  final List<FinanceDay> days;
  final List<MethodSlice> byMethod;
  final List<CategorySlice> byCategory;
  final List<CategorySlice> byCategoryThisMonth;

  const FinanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.incomeThisMonth,
    required this.incomePrevMonth,
    required this.expenseThisMonth,
    required this.expensePrevMonth,
    required this.incomeToday,
    required this.paymentsCount,
    required this.registrationTotal,
    required this.installmentTotal,
    required this.months,
    required this.days,
    required this.byMethod,
    required this.byCategory,
    required this.byCategoryThisMonth,
  });

  double get net => totalIncome - totalExpense;
  double get netThisMonth => incomeThisMonth - expenseThisMonth;

  /// Income and spending summed over the months in this payload.
  double get periodIncome => months.fold(0.0, (a, m) => a + m.income);
  double get periodExpense => months.fold(0.0, (a, m) => a + m.expense);

  /// Share of income kept after spending, over the payload's period.
  double? get retention {
    final inc = periodIncome;
    if (inc <= 0) return null;
    return (inc - periodExpense) / inc * 100;
  }

  FinanceMonth? get bestMonth {
    FinanceMonth? best;
    for (final m in months) {
      if (m.income > 0 && (best == null || m.income > best.income)) best = m;
    }
    return best;
  }

  bool get hasAnyMoney => totalIncome > 0 || totalExpense > 0;

  factory FinanceSummary.fromJson(Map<String, dynamic> j) => FinanceSummary(
        totalIncome: _d(j['total_income']),
        totalExpense: _d(j['total_expense']),
        incomeThisMonth: _d(j['income_this_month']),
        incomePrevMonth: _d(j['income_prev_month']),
        expenseThisMonth: _d(j['expense_this_month']),
        expensePrevMonth: _d(j['expense_prev_month']),
        incomeToday: _d(j['income_today']),
        paymentsCount: _i(j['payments_count']),
        registrationTotal: _d(j['registration_total']),
        installmentTotal: _d(j['installment_total']),
        months: _list(j['months']).map(FinanceMonth.fromJson).toList(),
        days: _list(j['days']).map(FinanceDay.fromJson).toList(),
        byMethod: _list(j['by_method']).map(MethodSlice.fromJson).toList(),
        byCategory: _list(j['by_category']).map(CategorySlice.fromJson).toList(),
        byCategoryThisMonth: _list(j['by_category_this_month']).map(CategorySlice.fromJson).toList(),
      );
}

// ============================================================ school stats

class ClassFill {
  final String className;
  final String department;
  final int count;
  final int capacity;
  const ClassFill({required this.className, required this.department, required this.count, required this.capacity});

  double get fillRate => capacity <= 0 ? 0 : count / capacity;
  bool get isFull => capacity > 0 && count >= capacity;
  int get seatsLeft => capacity <= 0 ? 0 : (capacity - count).clamp(0, capacity);

  factory ClassFill.fromJson(Map<String, dynamic> j) => ClassFill(
        className: '${j['class_name'] ?? ''}',
        department: '${j['department'] ?? ''}',
        count: _i(j['count']),
        capacity: _i(j['capacity']),
      );
}

class DeptCount {
  final String department;
  final int count;
  final int capacity;
  const DeptCount({required this.department, required this.count, required this.capacity});

  factory DeptCount.fromJson(Map<String, dynamic> j) =>
      DeptCount(department: '${j['department'] ?? ''}', count: _i(j['count']), capacity: _i(j['capacity']));
}

class YearCount {
  final String yearName;
  final bool isCurrent;
  final int count;
  const YearCount({required this.yearName, required this.isCurrent, required this.count});

  factory YearCount.fromJson(Map<String, dynamic> j) => YearCount(
        yearName: '${j['year_name'] ?? ''}',
        isCurrent: j['is_current'] == true,
        count: _i(j['count']),
      );
}

class GenderCount {
  final String gender;
  final int count;
  const GenderCount({required this.gender, required this.count});

  factory GenderCount.fromJson(Map<String, dynamic> j) => GenderCount(gender: '${j['gender'] ?? 'unknown'}', count: _i(j['count']));
}

class SchoolStats {
  final int students;
  final int classes;
  final int departments;
  final int capacity;
  final int awaitingPayment;
  final int underReview;
  final int principals;
  final int secretaries;
  final int proprietors;
  final int teachersApproved;
  final int teachersPending;
  final int parents;
  final List<ClassFill> byClass;
  final List<DeptCount> byDepartment;
  final List<YearCount> byYear;
  final List<GenderCount> byGender;

  const SchoolStats({
    required this.students,
    required this.classes,
    required this.departments,
    required this.capacity,
    required this.awaitingPayment,
    required this.underReview,
    required this.principals,
    required this.secretaries,
    required this.proprietors,
    required this.teachersApproved,
    required this.teachersPending,
    required this.parents,
    required this.byClass,
    required this.byDepartment,
    required this.byYear,
    required this.byGender,
  });

  double get capacityUsed => capacity <= 0 ? 0 : (students / capacity * 100).clamp(0, 100).toDouble();

  factory SchoolStats.fromJson(Map<String, dynamic> j) => SchoolStats(
        students: _i(j['students']),
        classes: _i(j['classes']),
        departments: _i(j['departments']),
        capacity: _i(j['capacity']),
        awaitingPayment: _i(j['awaiting_payment']),
        underReview: _i(j['under_review']),
        principals: _i(j['principals']),
        secretaries: _i(j['secretaries']),
        proprietors: _i(j['proprietors']),
        teachersApproved: _i(j['teachers_approved']),
        teachersPending: _i(j['teachers_pending']),
        parents: _i(j['parents']),
        byClass: _list(j['by_class']).map(ClassFill.fromJson).toList(),
        byDepartment: _list(j['by_department']).map(DeptCount.fromJson).toList(),
        byYear: _list(j['by_year']).map(YearCount.fromJson).toList(),
        byGender: _list(j['by_gender']).map(GenderCount.fromJson).toList(),
      );
}

// ============================================================ ledgers

class IncomeRecord {
  final String id;
  final String studentName;
  final double amount;
  final String purpose;
  final String method;
  final String type;
  final DateTime date;
  const IncomeRecord({
    required this.id,
    required this.studentName,
    required this.amount,
    required this.purpose,
    required this.method,
    required this.type,
    required this.date,
  });

  bool get isRegistration => type == 'registration';
}

class ExpenseRecord {
  final String id;
  final String category;
  final String? description;
  final double amount;
  final DateTime date;
  final String method;
  final String? paidTo;
  final String? receiptRef;
  final String recordedBy;
  final String source; // 'proprietor' | 'principal' | 'teacher_payment' ...
  final String? place;
  final bool needsReview; // flagged by the principal's approval threshold

  const ExpenseRecord({
    required this.id,
    required this.category,
    this.description,
    required this.amount,
    required this.date,
    required this.method,
    this.paidTo,
    this.receiptRef,
    required this.recordedBy,
    this.source = '',
    this.place,
    this.needsReview = false,
  });

  factory ExpenseRecord.fromMap(Map<String, dynamic> m) {
    final recorder = m['users'] as Map?;
    return ExpenseRecord(
      id: m['id'] as String,
      category: m['category'] as String? ?? '',
      description: m['description'] as String?,
      amount: _d(m['amount']),
      date: DateTime.tryParse(m['expense_date'] as String? ?? '') ?? DateTime.now(),
      method: m['payment_method'] as String? ?? '',
      paidTo: m['paid_to'] as String?,
      receiptRef: m['receipt_url'] as String?,
      recordedBy: (recorder?['email'] as String?) ?? '',
      source: m['source'] as String? ?? '',
      place: m['place'] as String?,
      needsReview: m['needs_review'] == true,
    );
  }
}

class ExpenseBudget {
  final String id;
  final String category;
  final double monthlyLimit;
  const ExpenseBudget({required this.id, required this.category, required this.monthlyLimit});

  factory ExpenseBudget.fromMap(Map<String, dynamic> m) =>
      ExpenseBudget(id: m['id'] as String, category: m['category'] as String? ?? '', monthlyLimit: _d(m['monthly_limit']));
}

// ============================================================ AI

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
        id: '${m['id'] ?? ''}',
        summary: m['summary'] as String? ?? '',
        strengths: List<String>.from((m['strengths'] as List? ?? []).map((e) => '$e')),
        concerns: List<String>.from((m['concerns'] as List? ?? []).map((e) => '$e')),
        recommendations: List<String>.from((m['recommendations'] as List? ?? []).map((e) => '$e')),
        generatedAt: DateTime.tryParse(m['generated_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// One page of a server-paginated list.
class PageResult<T> {
  final List<T> items;
  final bool hasMore;
  const PageResult({required this.items, required this.hasMore});
}

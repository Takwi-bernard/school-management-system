import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'proprietor_models.dart';

class ProprietorRepository {
  ProprietorRepository(this._client);
  final SupabaseClient _client;

  Future<ProprietorProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client.from('proprietors').select('full_name').eq('user_id', userId).maybeSingle();
      if (row == null) return null;
      return ProprietorProfile(fullName: row['full_name'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- SNAPSHOT

  Future<SchoolSnapshot> getSnapshot(String schoolId) async {
    final students = await _client.from('students').select('id').eq('school_id', schoolId).eq('current_status', 'active').count();
    final classes = await _client.from('classes').select('id').eq('school_id', schoolId).eq('is_active', true).count();
    final departments = await _client.from('departments').select('id').eq('school_id', schoolId).count();
    final awaiting = await _client.from('admission_requests').select('id').eq('school_id', schoolId).eq('status', 'awaiting_payment').count();
    final review = await _client.from('admission_requests').select('id').eq('school_id', schoolId).eq('status', 'under_review').count();

    return SchoolSnapshot(
      totalStudents: students.count,
      totalClasses: classes.count,
      totalDepartments: departments.count,
      admissionsAwaitingPayment: awaiting.count,
      admissionsUnderReview: review.count,
    );
  }

  // ---------------------------------------------------------------- FINANCIAL

  Future<FinancialOverview> getFinancialOverview(String schoolId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final twelveMonthsAgo = DateTime(now.year, now.month - 11, 1);

    final payments = await _client
        .from('payments')
        .select('amount, payment_type, created_at')
        .eq('school_id', schoolId)
        .eq('status', 'success')
        .gte('created_at', twelveMonthsAgo.toIso8601String());

    final allTimePayments = await _client.from('payments').select('amount').eq('school_id', schoolId).eq('status', 'success');
    final allTimeExpenses = await _client.from('expenses').select('amount').eq('school_id', schoolId);

    final expenses = await _client
        .from('expenses')
        .select('amount, expense_date')
        .eq('school_id', schoolId)
        .gte('expense_date', twelveMonthsAgo.toIso8601String().split('T').first);

    double totalIncome = 0, totalExpenditure = 0, thisMonthIncome = 0, thisMonthExpenditure = 0;
    double registration = 0, installment = 0;

    for (final p in allTimePayments) {
      totalIncome += (p['amount'] as num).toDouble();
    }
    for (final e in allTimeExpenses) {
      totalExpenditure += (e['amount'] as num).toDouble();
    }

    final incomeByMonth = <String, double>{};
    for (final p in payments) {
      final date = DateTime.tryParse(p['created_at'] as String? ?? '') ?? now;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final amount = (p['amount'] as num).toDouble();
      incomeByMonth[key] = (incomeByMonth[key] ?? 0) + amount;
      if (p['payment_type'] == 'registration') {
        registration += amount;
      } else {
        installment += amount;
      }
      if (!date.isBefore(startOfMonth)) thisMonthIncome += amount;
    }

    final expenditureByMonth = <String, double>{};
    for (final e in expenses) {
      final date = DateTime.tryParse(e['expense_date'] as String? ?? '') ?? now;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final amount = (e['amount'] as num).toDouble();
      expenditureByMonth[key] = (expenditureByMonth[key] ?? 0) + amount;
      if (!date.isBefore(startOfMonth)) thisMonthExpenditure += amount;
    }

    final months = List.generate(12, (i) => DateTime(now.year, now.month - 11 + i, 1));
    final incomeTrend = months.map((m) {
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      return MonthPoint(month: m, value: incomeByMonth[key] ?? 0);
    }).toList();
    final expenditureTrend = months.map((m) {
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      return MonthPoint(month: m, value: expenditureByMonth[key] ?? 0);
    }).toList();

    return FinancialOverview(
      totalIncome: totalIncome,
      totalExpenditure: totalExpenditure,
      netPosition: totalIncome - totalExpenditure,
      incomeThisMonth: thisMonthIncome,
      expenditureThisMonth: thisMonthExpenditure,
      incomeTrend: incomeTrend,
      expenditureTrend: expenditureTrend,
      registrationIncome: registration,
      installmentIncome: installment,
    );
  }

  Future<List<IncomeRecord>> getIncomeHistory(String schoolId, {int limit = 30}) async {
    final rows = await _client
        .from('payments')
        .select('amount, payment_method, created_at, metadata, students(first_name, last_name), admission_requests!payments_admission_request_id_fkey(first_name, last_name)')
        .eq('school_id', schoolId)
        .eq('status', 'success')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map((r) {
      final student = r['students'] as Map?;
      final admission = r['admission_requests'] as Map?;
      final name = student != null
          ? '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
          : '${admission?['first_name'] ?? ''} ${admission?['last_name'] ?? ''}';
      final purpose = (r['metadata'] as Map?)?['payment_purpose'] as String? ?? 'Payment';
      return IncomeRecord(
        childName: name.trim(),
        amount: (r['amount'] as num).toDouble(),
        purpose: purpose,
        method: r['payment_method'] as String? ?? '',
        date: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  // ---------------------------------------------------------------- EXPENDITURE

  Future<List<ExpenseRecord>> getExpenses(String schoolId, {int limit = 50}) async {
    final rows = await _client
        .from('expenses')
        .select('*, users(email)')
        .eq('school_id', schoolId)
        .order('expense_date', ascending: false)
        .limit(limit);
    return rows.map((r) => ExpenseRecord.fromMap(r)).toList();
  }

  Future<String> uploadReceipt({required String schoolId, required Uint8List bytes, required String extension}) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$schoolId/$uid/expense_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('document-templates').uploadBinary(path, bytes);
    return _client.storage.from('document-templates').getPublicUrl(path);
  }

  Future<void> recordExpense({
    required String schoolId,
    required String category,
    String? description,
    required double amount,
    required DateTime date,
    required String paymentMethod,
    String? paidTo,
    String? receiptUrl,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('expenses').insert({
      'school_id': schoolId,
      'category': category,
      'description': description,
      'amount': amount,
      'expense_date': date.toIso8601String().split('T').first,
      'payment_method': paymentMethod,
      'paid_to': paidTo,
      'receipt_url': receiptUrl,
      'recorded_by': userId,
    });
  }

  // ---------------------------------------------------------------- GROWTH & STATS

  Future<List<ClassEnrollmentCount>> getEnrollmentByClass(String schoolId) async {
    final classes = await _client
        .from('classes')
        .select('id, class_name, max_students, departments(department_name)')
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('level_order');

    final counts = await _client
        .from('class_enrollments')
        .select('class_id')
        .eq('school_id', schoolId)
        .eq('enrollment_status', 'active');

    final byClass = <String, int>{};
    for (final c in counts) {
      final id = c['class_id'] as String;
      byClass[id] = (byClass[id] ?? 0) + 1;
    }

    return classes.map((c) {
      final dept = c['departments'] as Map?;
      return ClassEnrollmentCount(
        className: c['class_name'] as String? ?? '',
        departmentName: dept?['department_name'] as String? ?? '',
        studentCount: byClass[c['id']] ?? 0,
        capacity: c['max_students'] as int? ?? 0,
      );
    }).toList();
  }

  Future<List<YearGrowthPoint>> getGrowthByYear(String schoolId) async {
    final years = await _client
        .from('academic_years')
        .select('id, year_name, is_current')
        .eq('school_id', schoolId)
        .order('start_date');

    if (years.isEmpty) return [];

    final enrollments = await _client
        .from('class_enrollments')
        .select('academic_year_id, student_id')
        .eq('school_id', schoolId);

    final countedByYear = <String, Set<String>>{};
    for (final e in enrollments) {
      final yearId = e['academic_year_id'] as String;
      countedByYear.putIfAbsent(yearId, () => {}).add(e['student_id'] as String);
    }

    return years.map((y) {
      final id = y['id'] as String;
      return YearGrowthPoint(
        yearName: y['year_name'] as String? ?? '',
        studentCount: countedByYear[id]?.length ?? 0,
        isCurrent: y['is_current'] as bool? ?? false,
      );
    }).toList();
  }

  // ---------------------------------------------------------------- ACTORS

  Future<ActiveActors> getActiveActors(String schoolId) async {
    final principals = await _client.from('principals').select('id').eq('school_id', schoolId).eq('is_active', true).count();
    final secretaries = await _client.from('secretaries').select('id').eq('school_id', schoolId).eq('is_active', true).count();
    final proprietors = await _client.from('proprietors').select('id').eq('school_id', schoolId).eq('is_active', true).count();
    final teachersApproved = await _client.from('teachers').select('id').eq('school_id', schoolId).eq('is_approved', true).count();
    final teachersPending = await _client.from('teachers').select('id').eq('school_id', schoolId).eq('is_approved', false).count();
    final parents = await _client.from('parents').select('id').eq('school_id', schoolId).count();

    return ActiveActors(
      principals: principals.count,
      secretaries: secretaries.count,
      proprietors: proprietors.count,
      teachersApproved: teachersApproved.count,
      teachersPending: teachersPending.count,
      parents: parents.count,
    );
  }

    Future<AiSchoolReport?> getLatestReport(String schoolId) async {
    final row = await _client.from('ai_school_reports').select().eq('school_id', schoolId).order('generated_at', ascending: false).limit(1).maybeSingle();
    if (row == null) return null;
    return AiSchoolReport.fromMap(row);
  }

  Future<AiSchoolReport> generateReport(String schoolId) async {
    final res = await _client.functions.invoke('analyze-school-performance', body: {'school_id': schoolId});
    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['success'] != true) throw Exception(data['message'] ?? 'Could not generate the analysis.');
    return AiSchoolReport.fromMap(Map<String, dynamic>.from(data['report'] as Map));
  }
}
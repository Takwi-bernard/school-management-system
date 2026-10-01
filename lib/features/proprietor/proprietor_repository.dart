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

  Future<SchoolOverview> getOverview(String schoolId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final studentsCount = await _client.from('students').select('id').eq('school_id', schoolId).eq('current_status', 'active').count();
    final classesCount = await _client.from('classes').select('id').eq('school_id', schoolId).eq('is_active', true).count();
    final departmentsCount = await _client.from('departments').select('id').eq('school_id', schoolId).count();
    final approvedTeachers = await _client.from('teachers').select('id').eq('school_id', schoolId).eq('is_approved', true).count();
    final pendingTeachers = await _client.from('teachers').select('id').eq('school_id', schoolId).eq('is_approved', false).count();
    final awaitingPayment = await _client.from('admission_requests').select('id').eq('school_id', schoolId).eq('status', 'awaiting_payment').count();
    final underReview = await _client.from('admission_requests').select('id').eq('school_id', schoolId).eq('status', 'under_review').count();

    final successfulPayments = await _client
        .from('payments')
        .select('amount, payment_type, created_at')
        .eq('school_id', schoolId)
        .eq('status', 'success');

    double allTime = 0, thisMonth = 0, registration = 0, installment = 0;
    var monthCount = 0;
    for (final p in successfulPayments) {
      final amount = (p['amount'] as num).toDouble();
      allTime += amount;
      if (p['payment_type'] == 'registration') {
        registration += amount;
      } else {
        installment += amount;
      }
      final createdAt = p['created_at'] as String? ?? '';
      if (createdAt.compareTo(startOfMonth) >= 0) {
        thisMonth += amount;
        monthCount++;
      }
    }

    return SchoolOverview(
      totalStudents: studentsCount.count,
      totalTeachersApproved: approvedTeachers.count,
      totalTeachersPending: pendingTeachers.count,
      totalClasses: classesCount.count,
      totalDepartments: departmentsCount.count,
      admissionsAwaitingPayment: awaitingPayment.count,
      admissionsUnderReview: underReview.count,
      revenueThisMonth: thisMonth,
      revenueAllTime: allTime,
      registrationRevenue: registration,
      installmentRevenue: installment,
      paymentsThisMonth: monthCount,
    );
  }

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

  Future<List<RecentPayment>> getRecentPayments(String schoolId, {int limit = 15}) async {
    final rows = await _client
        .from('payments')
        .select('amount, payment_method, created_at, metadata, students(first_name, last_name), admission_requests(first_name, last_name)')
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
      return RecentPayment(
        childName: name.trim(),
        amount: (r['amount'] as num).toDouble(),
        purpose: purpose,
        method: r['payment_method'] as String? ?? '',
        date: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }
}
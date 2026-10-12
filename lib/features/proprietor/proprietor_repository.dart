import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'proprietor_models.dart';

/// All Proprietor data access. Heavy numbers (totals, trends, class
/// counts) come from two SQL functions so a school with thousands of
/// payments is exact and costs one round-trip; ledgers are paginated.
class ProprietorRepository {
  ProprietorRepository(this._client, {this.lang = 'en'});
  final SupabaseClient _client;
  final String lang;

  static const int pageSize = 40;
  static const int _exportChunk = 1000;
  static const int _exportMax = 20000;

  // ------------------------------------------------------------ profile

  Future<ProprietorProfile?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('proprietors')
          .select('id, user_id, school_id, full_name, phone, photo_url')
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (_) {
      // The phone/photo columns arrive with the final migration; stay
      // usable if it has not been run yet.
      row = await _client.from('proprietors').select('id, user_id, school_id, full_name').eq('user_id', user.id).maybeSingle();
    }
    if (row == null) return null;
    return ProprietorProfile(
      proprietorId: row['id'] as String,
      userId: row['user_id'] as String,
      schoolId: row['school_id'] as String,
      fullName: row['full_name'] as String? ?? '',
      phone: row['phone'] as String?,
      photoUrl: row['photo_url'] as String?,
      email: user.email,
    );
  }

  Future<void> updateProfile({required String proprietorId, required String fullName, String? phone}) async {
    await _client.from('proprietors').update({'full_name': fullName, 'phone': phone}).eq('id', proprietorId);
  }

  Future<String> uploadProfilePhoto({
    required String schoolId,
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path = '$schoolId/$userId/avatar.$extension';
    await _client.storage.from('staff-photos').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    final url = _client.storage.from('staff-photos').getPublicUrl(path);
    final busted = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('proprietors').update({'photo_url': busted}).eq('user_id', userId);
    return busted;
  }

  // ------------------------------------------------------------ aggregates

  Future<FinanceSummary> getFinance({int months = 12}) async {
    final res = await _client.rpc('proprietor_finance', params: {'p_months': months});
    return FinanceSummary.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<SchoolStats> getSchoolStats() async {
    final res = await _client.rpc('proprietor_school_stats');
    return SchoolStats.fromJson(Map<String, dynamic>.from(res as Map));
  }

  // ------------------------------------------------------------ income

  static const _incomeSelect =
      'id, amount, payment_type, payment_method, created_at, metadata, students(first_name, last_name), admission_requests!payments_admission_request_id_fkey(first_name, last_name)';

  IncomeRecord _incomeFromRow(Map<String, dynamic> r, String fallbackPurpose) {
    final student = r['students'] as Map?;
    final admission = r['admission_requests'] as Map?;
    final name = student != null
        ? '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
        : '${admission?['first_name'] ?? ''} ${admission?['last_name'] ?? ''}';
    final purpose = (r['metadata'] as Map?)?['payment_purpose'] as String? ?? fallbackPurpose;
    return IncomeRecord(
      id: '${r['id']}',
      studentName: name.trim(),
      amount: (r['amount'] as num).toDouble(),
      purpose: purpose,
      method: r['payment_method'] as String? ?? '',
      type: r['payment_type'] as String? ?? '',
      date: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Future<PageResult<IncomeRecord>> getIncomePage({
    required String schoolId,
    required int offset,
    String? type,
    String? method,
    required String fallbackPurpose,
  }) async {
    var q = _client.from('payments').select(_incomeSelect).eq('school_id', schoolId).eq('status', 'success');
    if (type != null) q = q.eq('payment_type', type);
    if (method != null) q = q.eq('payment_method', method);
    final rows = await q.order('created_at', ascending: false).range(offset, offset + pageSize - 1);
    final items = rows.map((r) => _incomeFromRow(Map<String, dynamic>.from(r), fallbackPurpose)).toList();
    return PageResult(items: items, hasMore: rows.length == pageSize);
  }

  /// Every successful payment in [from, to] (inclusive, Douala days) for
  /// statements, fetched in chunks so the 1000-row API cap never
  /// silently truncates a report.
  Future<List<IncomeRecord>> getIncomeRange({
    required String schoolId,
    required DateTime from,
    required DateTime to,
    required String fallbackPurpose,
    String? type,
    String? method,
  }) async {
    final startUtc = DateTime.utc(from.year, from.month, from.day).subtract(const Duration(hours: 1));
    final endUtc = DateTime.utc(to.year, to.month, to.day).add(const Duration(days: 1)).subtract(const Duration(hours: 1));
    final out = <IncomeRecord>[];
    var offset = 0;
    while (offset < _exportMax) {
      var q = _client
          .from('payments')
          .select(_incomeSelect)
          .eq('school_id', schoolId)
          .eq('status', 'success')
          .gte('created_at', startUtc.toIso8601String())
          .lt('created_at', endUtc.toIso8601String());
      if (type != null) q = q.eq('payment_type', type);
      if (method != null) q = q.eq('payment_method', method);
      final rows = await q.order('created_at', ascending: false).range(offset, offset + _exportChunk - 1);
      out.addAll(rows.map((r) => _incomeFromRow(Map<String, dynamic>.from(r), fallbackPurpose)));
      if (rows.length < _exportChunk) break;
      offset += _exportChunk;
    }
    return out;
  }

  // ------------------------------------------------------------ expenses

  String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<PageResult<ExpenseRecord>> getExpensesPage({
    required String schoolId,
    required int offset,
    String? category,
  }) async {
    var q = _client.from('expenses').select('*, users(email)').eq('school_id', schoolId);
    if (category != null) q = q.eq('category', category);
    final rows = await q.order('expense_date', ascending: false).order('created_at', ascending: false).range(offset, offset + pageSize - 1);
    return PageResult(
      items: rows.map((r) => ExpenseRecord.fromMap(Map<String, dynamic>.from(r))).toList(),
      hasMore: rows.length == pageSize,
    );
  }

  Future<List<ExpenseRecord>> getExpensesRange({required String schoolId, required DateTime from, required DateTime to}) async {
    final out = <ExpenseRecord>[];
    var offset = 0;
    while (offset < _exportMax) {
      final rows = await _client
          .from('expenses')
          .select('*, users(email)')
          .eq('school_id', schoolId)
          .gte('expense_date', _day(from))
          .lte('expense_date', _day(to))
          .order('expense_date', ascending: false)
          .range(offset, offset + _exportChunk - 1);
      out.addAll(rows.map((r) => ExpenseRecord.fromMap(Map<String, dynamic>.from(r))));
      if (rows.length < _exportChunk) break;
      offset += _exportChunk;
    }
    return out;
  }

  /// Receipts live in a PRIVATE bucket; we store the object path and
  /// hand out short-lived signed links on demand.
  Future<String> uploadReceipt({required String schoolId, required Uint8List bytes, required String extension}) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$schoolId/$uid/expense_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('expense-receipts').uploadBinary(path, bytes);
    return path;
  }

  Future<String> receiptUrl(String ref) async {
    // Older rows hold a full public URL from the previous version.
    if (ref.startsWith('http')) return ref;
    return _client.storage.from('expense-receipts').createSignedUrl(ref, 600);
  }

  Future<void> recordExpense({
    required String schoolId,
    required String category,
    String? description,
    required double amount,
    required DateTime date,
    required String paymentMethod,
    String? paidTo,
    String? receiptRef,
  }) async {
    await _client.from('expenses').insert({
      'school_id': schoolId,
      'category': category,
      'description': (description == null || description.isEmpty) ? null : description,
      'amount': amount,
      'expense_date': _day(date),
      'payment_method': paymentMethod,
      'paid_to': (paidTo == null || paidTo.isEmpty) ? null : paidTo,
      'receipt_url': receiptRef,
      'recorded_by': _client.auth.currentUser!.id,
    });
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  // ------------------------------------------------------------ budgets

  Future<List<ExpenseBudget>> getBudgets(String schoolId) async {
    final rows = await _client.from('expense_budgets').select().eq('school_id', schoolId).order('category');
    return rows.map((r) => ExpenseBudget.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> saveBudget({required String schoolId, required String category, required double limit}) async {
    await _client.from('expense_budgets').upsert(
      {
        'school_id': schoolId,
        'category': category,
        'monthly_limit': limit,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'school_id,category',
    );
  }

  Future<void> deleteBudget(String id) async {
    await _client.from('expense_budgets').delete().eq('id', id);
  }

  // ------------------------------------------------------------ AI

  Future<AiSchoolReport?> getLatestReport(String schoolId) async {
    final row = await _client
        .from('ai_school_reports')
        .select()
        .eq('school_id', schoolId)
        .order('generated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : AiSchoolReport.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<AiSchoolReport>> getReportHistory(String schoolId, {int limit = 6}) async {
    final rows = await _client
        .from('ai_school_reports')
        .select()
        .eq('school_id', schoolId)
        .order('generated_at', ascending: false)
        .limit(limit);
    return rows.map((r) => AiSchoolReport.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<Map<String, dynamic>> _invokeAi(Map<String, dynamic> body) async {
    final res = await _client.functions.invoke('analyze-school-performance', body: {...body, 'lang': lang});
    final data = res.data;
    if (data is! Map) throw Exception('Bad response');
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) throw Exception(map['message'] ?? 'Request failed');
    return map;
  }

  Future<AiSchoolReport> generateReport(String schoolId) async {
    final map = await _invokeAi({'mode': 'report', 'school_id': schoolId});
    return AiSchoolReport.fromMap(Map<String, dynamic>.from(map['report'] as Map));
  }

  Future<String> askQuestion(String schoolId, String question) async {
    final map = await _invokeAi({'mode': 'ask', 'school_id': schoolId, 'question': question});
    return '${map['answer'] ?? ''}';
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import 'proprietor_models.dart';
import 'proprietor_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One realtime channel per school, watching every table this dashboard
/// reads. On ANY insert/update/delete, it invalidates every Proprietor
/// provider so the next frame refetches fresh data - no manual refresh,
/// no browser reload needed.
final proprietorRealtimeProvider = Provider.family<void, String>((ref, schoolId) {
  final client = ref.watch(supabaseClientProvider);

  void invalidateAll() {
    ref.invalidate(schoolSnapshotProvider(schoolId));
    ref.invalidate(financialOverviewProvider(schoolId));
    ref.invalidate(incomeHistoryProvider(schoolId));
    ref.invalidate(expensesProvider(schoolId));
    ref.invalidate(enrollmentByClassProvider(schoolId));
    ref.invalidate(growthByYearProvider(schoolId));
    ref.invalidate(activeActorsProvider(schoolId));
  }

  final channel = client
      .channel('proprietor-dashboard-$schoolId')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'payments', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId), callback: (_) => invalidateAll())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'expenses', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId), callback: (_) => invalidateAll())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'students', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId), callback: (_) => invalidateAll())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'class_enrollments', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId), callback: (_) => invalidateAll())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'admission_requests', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId), callback: (_) => invalidateAll())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'teachers', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'school_id', value: schoolId), callback: (_) => invalidateAll())
      .subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});
final proprietorRepositoryProvider = Provider<ProprietorRepository>((ref) {
  return ProprietorRepository(ref.watch(supabaseClientProvider));
});

final proprietorProfileProvider = FutureProvider<ProprietorProfile?>((ref) {
  return ref.watch(proprietorRepositoryProvider).getProfile();
});

final schoolSnapshotProvider = FutureProvider.family<SchoolSnapshot, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getSnapshot(schoolId);
});

final financialOverviewProvider = FutureProvider.family<FinancialOverview, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getFinancialOverview(schoolId);
});

final incomeHistoryProvider = FutureProvider.family<List<IncomeRecord>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getIncomeHistory(schoolId);
});

final expensesProvider = FutureProvider.family<List<ExpenseRecord>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getExpenses(schoolId);
});

final enrollmentByClassProvider = FutureProvider.family<List<ClassEnrollmentCount>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getEnrollmentByClass(schoolId);
});

final growthByYearProvider = FutureProvider.family<List<YearGrowthPoint>, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getGrowthByYear(schoolId);
});

final activeActorsProvider = FutureProvider.family<ActiveActors, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getActiveActors(schoolId);
});
final latestAiReportProvider = FutureProvider.family<AiSchoolReport?, String>((ref, schoolId) {
  return ref.watch(proprietorRepositoryProvider).getLatestReport(schoolId);
});